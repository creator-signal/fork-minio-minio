# syntax=docker/dockerfile:1.7

FROM --platform=$BUILDPLATFORM golang:1.25.12-alpine3.23@sha256:cc985ef6f9c3bf9ece7488129c9abe0a150388ccdfa428d886fc709dca0b230a AS build

ARG TARGETOS=linux
ARG TARGETARCH
ARG CREATOR_SIGNAL_VERSION=DEVELOPMENT.creatorsignal
ARG CREATOR_SIGNAL_COMMIT=0000000000000000000000000000000000000000
ARG CREATOR_SIGNAL_COPYRIGHT_YEAR=2026

WORKDIR /src

COPY go.mod go.sum ./
COPY creatorsignal/console/go.mod creatorsignal/console/go.sum ./creatorsignal/console/
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .
RUN chmod 0755 creatorsignal/build.sh && \
    GOOS="$TARGETOS" GOARCH="$TARGETARCH" \
    CREATOR_SIGNAL_VERSION="$CREATOR_SIGNAL_VERSION" \
    CREATOR_SIGNAL_COMMIT="$CREATOR_SIGNAL_COMMIT" \
    CREATOR_SIGNAL_COPYRIGHT_YEAR="$CREATOR_SIGNAL_COPYRIGHT_YEAR" \
    ./creatorsignal/build.sh /out/minio

FROM alpine:3.23@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40

ARG CREATOR_SIGNAL_VERSION=DEVELOPMENT.creatorsignal
ARG CREATOR_SIGNAL_COMMIT=0000000000000000000000000000000000000000
ARG MINIO_BASE_RELEASE=RELEASE.2025-10-15T17-29-55Z

LABEL org.opencontainers.image.title="Creator Signal MinIO" \
      org.opencontainers.image.description="Archived MinIO Community server with the Creator Signal maintained full console" \
      org.opencontainers.image.source="https://github.com/creator-signal/fork-minio-minio" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later" \
      org.opencontainers.image.version="$CREATOR_SIGNAL_VERSION" \
      org.opencontainers.image.revision="$CREATOR_SIGNAL_COMMIT" \
      io.creatorsignal.minio.base-release="$MINIO_BASE_RELEASE" \
      io.creatorsignal.minio.console="github.com/minio/console@v1.7.6"

RUN apk upgrade --no-cache && \
    apk add --no-cache ca-certificates coreutils curl

ENV MINIO_ACCESS_KEY_FILE=access_key \
    MINIO_SECRET_KEY_FILE=secret_key \
    MINIO_ROOT_USER_FILE=access_key \
    MINIO_ROOT_PASSWORD_FILE=secret_key \
    MINIO_KMS_SECRET_KEY_FILE=kms_master_key \
    MINIO_CONFIG_ENV_FILE=config.env \
    MC_CONFIG_DIR=/tmp/.mc

COPY --from=build /out/minio /usr/bin/minio
COPY dockerscripts/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh
COPY LICENSE CREDITS /licenses/

RUN chmod 0755 /usr/bin/minio /usr/bin/docker-entrypoint.sh

EXPOSE 9000 9001
VOLUME ["/data"]
STOPSIGNAL SIGTERM

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio"]
