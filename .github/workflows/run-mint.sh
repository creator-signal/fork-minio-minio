#!/bin/bash

set -ex

export MODE="$1"
export ACCESS_KEY="$2"
export SECRET_KEY="$3"
export JOB_NAME="$4"
export MINT_MODE="full"
export MINT_IMAGE="docker.io/minio/mint@sha256:f80ec8f981a5b54d98c1bbbbe7a191e5a2c696c5f45f4d18f712c418cec6e61d"

docker system prune -f || true
docker volume prune -f || true
docker volume ls -q -f dangling=true | xargs -r docker volume rm || true

## change working directory
cd .github/workflows/mint

# The upstream server is archived, so use the last stable Mint release rather
# than the moving edge tag, whose future S3 assertions can outpace this server.
docker pull "${MINT_IMAGE}"

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
