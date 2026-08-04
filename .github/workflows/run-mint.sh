#!/bin/bash

set -ex

export MODE="$1"
export ACCESS_KEY="$2"
export SECRET_KEY="$3"
export JOB_NAME="$4"
export MINT_MODE="full"
export MINT_SOURCE_COMMIT="befedef1f35389666df0885fe2157118c6f425c3"
export MINT_IMAGE="creator-signal/minio-mint:${MINT_SOURCE_COMMIT}"

docker system prune -f || true
docker volume prune -f || true
docker volume ls -q -f dangling=true | xargs -r docker volume rm || true

## change working directory
cd .github/workflows/mint

# The upstream server and Mint repositories are archived. Build the immutable
# Mint source revision used immediately before MinIO's last successful upstream
# Mint workflow instead of relying on stale `latest` or moving `edge` tags.
if ! docker image inspect "${MINT_IMAGE}" >/dev/null 2>&1; then
	docker build \
		--tag "${MINT_IMAGE}" \
		"https://github.com/minio/mint.git#${MINT_SOURCE_COMMIT}"
fi

docker compose -f minio-${MODE}.yaml up -d
sleep 1m

docker system prune -f || true
docker volume prune -f || true
docker volume rm $(docker volume ls -q -f dangling=true) || true

# Stop two nodes, one of each pool, to check that all S3 calls work while quorum is still there
[ "${MODE}" == "pools" ] && docker compose -f minio-${MODE}.yaml stop minio2
[ "${MODE}" == "pools" ] && docker compose -f minio-${MODE}.yaml stop minio6

# Pause one node, to check that all S3 calls work while one node goes wrong
[ "${MODE}" == "resiliency" ] && docker compose -f minio-${MODE}.yaml pause minio4

docker run --rm --net=mint_default \
	--name="mint-${MODE}-${JOB_NAME}" \
	-e SERVER_ENDPOINT="nginx:9000" \
	-e ACCESS_KEY="${ACCESS_KEY}" \
	-e SECRET_KEY="${SECRET_KEY}" \
	-e ENABLE_HTTPS=0 \
	-e MINT_MODE="${MINT_MODE}" \
	"${MINT_IMAGE}"

# FIXME: enable this after fixing aws-sdk-java-v2 tests
# # unpause the node, to check that all S3 calls work while one node goes wrong
# [ "${MODE}" == "resiliency" ] && docker compose -f minio-${MODE}.yaml unpause minio4
# [ "${MODE}" == "resiliency" ] && docker run --rm --net=mint_default \
# 	--name="mint-${MODE}-${JOB_NAME}" \
# 	-e SERVER_ENDPOINT="nginx:9000" \
# 	-e ACCESS_KEY="${ACCESS_KEY}" \
# 	-e SECRET_KEY="${SECRET_KEY}" \
# 	-e ENABLE_HTTPS=0 \
# 	-e MINT_MODE="${MINT_MODE}" \
# 	"${MINT_IMAGE}"

docker compose -f minio-${MODE}.yaml down || true
sleep 10s

docker system prune -f || true
docker volume prune -f || true
docker volume rm $(docker volume ls -q -f dangling=true) || true

## change working directory
cd ../../../
