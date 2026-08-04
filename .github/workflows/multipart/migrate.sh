#!/bin/bash

set -x

## change working directory
cd .github/workflows/multipart/

function cleanup() {
	docker compose -f docker-compose-site1.yaml rm -s -f || true
	docker compose -f docker-compose-site2.yaml rm -s -f || true
	for volume in $(docker volume ls -q | grep minio); do
		docker volume rm ${volume} || true
	done

	docker system prune -f || true
	docker volume prune -f || true
	docker volume rm $(docker volume ls -q -f dangling=true) || true
}

cleanup

if [ ! -f ./mc ]; then
	wget --quiet -O mc https://dl.minio.io/client/mc/release/linux-amd64/mc &&
		chmod +x mc
fi

if ! go build -o s3-check-md5 ../../../docs/debugging/s3-check-md5; then
	echo "Unable to build the multipart integrity checker"
	exit 1
fi

export RELEASE=RELEASE.2023-08-29T23-07-35Z

docker compose -f docker-compose-site1.yaml up -d
docker compose -f docker-compose-site2.yaml up -d

sleep 30s

./mc alias set site1 http://127.0.0.1:9001 minioadmin minioadmin --api s3v4
./mc alias set site2 http://127.0.0.1:9002 minioadmin minioadmin --api s3v4

./mc ready site1/
./mc ready site2/

# The host aliases above exercise the published loopback ports. Site replication
# persists its endpoints, so configure it from the shared Compose network where
# both endpoint names remain reachable by every MinIO container.
site1_container=$(docker compose -f docker-compose-site1.yaml ps -q site1-nginx)
compose_network=$(docker inspect --format '{{range $network, $_ := .NetworkSettings.Networks}}{{$network}}{{end}}' "${site1_container}")
if [ -z "${compose_network}" ]; then
	echo "Unable to determine the shared multipart Compose network"
	exit 1
fi

if ! docker run --rm \
	--network "${compose_network}" \
	--volume "${PWD}/mc:/usr/local/bin/mc:ro" \
	--entrypoint /usr/local/bin/mc \
	--env MC_HOST_site1=http://minioadmin:minioadmin@site1-nginx:9001 \
	--env MC_HOST_site2=http://minioadmin:minioadmin@site2-nginx:9002 \
	alpine:3.23@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40 \
	admin replicate add site1 site2; then
	echo "Unable to establish site replication over the shared Compose network"
	exit 1
fi
./mc mb site1/testbucket/
./mc cp -r --quiet /usr/bin site1/testbucket/

sleep 5

./s3-check-md5 -h

failed_count_site1=$(./s3-check-md5 -versions -access-key minioadmin -secret-key minioadmin -endpoint http://127.0.0.1:9001 -bucket testbucket 2>&1 | grep FAILED | wc -l)
failed_count_site2=$(./s3-check-md5 -versions -access-key minioadmin -secret-key minioadmin -endpoint http://127.0.0.1:9002 -bucket testbucket 2>&1 | grep FAILED | wc -l)

if [ $failed_count_site1 -ne 0 ]; then
	echo "failed with multipart on site1 uploads"
	exit 1
fi

if [ $failed_count_site2 -ne 0 ]; then
	echo "failed with multipart on site2 uploads"
	exit 1
fi

./mc cp -r --quiet /usr/bin site1/testbucket/

sleep 5

failed_count_site1=$(./s3-check-md5 -versions -access-key minioadmin -secret-key minioadmin -endpoint http://127.0.0.1:9001 -bucket testbucket 2>&1 | grep FAILED | wc -l)
failed_count_site2=$(./s3-check-md5 -versions -access-key minioadmin -secret-key minioadmin -endpoint http://127.0.0.1:9002 -bucket testbucket 2>&1 | grep FAILED | wc -l)

## we do not need to fail here, since we are going to test
## upgrading to master, healing and being able to recover
## the last version.
if [ $failed_count_site1 -ne 0 ]; then
	echo "failed with multipart on site1 uploads ${failed_count_site1}"
fi

if [ $failed_count_site2 -ne 0 ]; then
	echo "failed with multipart on site2 uploads ${failed_count_site2}"
fi

export RELEASE=${1}

docker compose -f docker-compose-site1.yaml up -d
docker compose -f docker-compose-site2.yaml up -d

./mc ready site1/
./mc ready site2/

for i in $(seq 1 10); do
	# mc admin heal -r --remove when used against a LB endpoint
	# behaves flaky, let this run 10 times before giving up
	./mc admin heal -r --remove --json site1/ 2>&1 >/dev/null
	./mc admin heal -r --remove --json site2/ 2>&1 >/dev/null
done

failed_count_site1=$(./s3-check-md5 -versions -access-key minioadmin -secret-key minioadmin -endpoint http://127.0.0.1:9001 -bucket testbucket 2>&1 | grep FAILED | wc -l)
failed_count_site2=$(./s3-check-md5 -versions -access-key minioadmin -secret-key minioadmin -endpoint http://127.0.0.1:9002 -bucket testbucket 2>&1 | grep FAILED | wc -l)

if [ $failed_count_site1 -ne 0 ]; then
	echo "failed with multipart on site1 uploads"
	exit 1
fi

if [ $failed_count_site2 -ne 0 ]; then
	echo "failed with multipart on site2 uploads"
	exit 1
fi

# Add user group test
./mc admin user add site1 site-replication-issue-user site-replication-issue-password
./mc admin group add site1 site-replication-issue-group site-replication-issue-user

max_wait_attempts=30
wait_interval=5

attempt=1
while true; do
	diff <(./mc admin group info site1 site-replication-issue-group) <(./mc admin group info site2 site-replication-issue-group)

	if [[ $? -eq 0 ]]; then
		echo "Outputs are consistent."
		break
	fi

	remaining_attempts=$((max_wait_attempts - attempt))
	if ((attempt >= max_wait_attempts)); then
		echo "Outputs remain inconsistent after $max_wait_attempts attempts. Exiting with error."
		exit 1
	else
		echo "Outputs are inconsistent. Waiting for $wait_interval seconds (attempt $attempt/$max_wait_attempts)."
		sleep $wait_interval
	fi

	((attempt++))
done

status=$(./mc admin group info site1 site-replication-issue-group --json | jq .groupStatus | tr -d '"')

if [[ $status == "enabled" ]]; then
	echo "Success"
else
	echo "Expected status: enabled, actual status: $status"
	exit 1
fi

cleanup

## change working directory
cd ../../../
