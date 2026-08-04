# syntax=docker/dockerfile:1.7

FROM ubuntu:22.04@sha256:3b06811b2afd352be909dd088a004166d665dc76d38b13eada33522a9d915c6f

ARG MINT_SOURCE_COMMIT

LABEL org.opencontainers.image.source="https://github.com/minio/mint" \
      org.opencontainers.image.revision="${MINT_SOURCE_COMMIT}" \
      org.opencontainers.image.vendor="Creator Signal"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    GOROOT=/usr/local/go \
    GOPATH=/usr/local/gopath \
    PATH=/usr/local/gopath/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    MINT_ROOT_DIR=/mint

RUN apt-get --yes update && \
    apt-get --yes upgrade && \
    apt-get --yes --quiet install wget jq curl git dnsmasq

COPY --from=mint-source . /mint

# Preserve the dependency versions used when this Mint revision was current.
# The archived harness otherwise resolves moving "latest" clients, and its Go
# archive URL has since moved.
RUN sed -i \
    's#https://storage.googleapis.com/golang/#https://go.dev/dl/#' \
    /mint/preinstall.sh && \
    sed -i \
    's#--install-dir="$test_run_dir"#--version=2.8.8 --install-dir="$test_run_dir"#' \
    /mint/build/aws-sdk-php/install.sh && \
    sed -i \
    's#^MC_VERSION=.*#MC_VERSION="RELEASE.2025-04-16T18-13-26Z"#' \
    /mint/build/mc/install.sh && \
    sed -i \
    's#^MINIO_GO_VERSION=.*#MINIO_GO_VERSION="v7.0.91"#' \
    /mint/build/minio-go/install.sh && \
    sed -i \
    's#^MINIO_JAVA_VERSION=.*#MINIO_JAVA_VERSION="8.5.17"#' \
    /mint/build/minio-java/install.sh && \
    sed -i \
    's#^LATEST=.*#LATEST="8.0.5"#' \
    /mint/build/minio-js/install.sh && \
    sed -i \
    's#^MINIO_PY_VERSION=.*#MINIO_PY_VERSION="7.2.15"#' \
    /mint/build/minio-py/install.sh && \
    sed -i \
    's#python -m pip install minio$#python -m pip install minio==7.2.15#' \
    /mint/build/s3select/install.sh

WORKDIR /mint

RUN /mint/create-data-files.sh
RUN /mint/preinstall.sh

# The legacy MinIO download host no longer retains this release. Fetch the
# matching official GitHub release asset while keeping Mint's tag unchanged.
RUN sed -i \
    's#https://dl.minio.io/client/mc/release/linux-amd64/mc.${MC_VERSION}#https://github.com/minio/mc/releases/download/${MC_VERSION}/mc.linux-amd64.${MC_VERSION}#' \
    /mint/build/mc/install.sh

# Keep each archived client installer in its own cacheable layer. That makes a
# failed ecosystem mirror or retired upstream URL independently diagnosable.
RUN bash -c 'source /mint/source.sh && /mint/build/aws-sdk-go/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/aws-sdk-java/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/aws-sdk-java-v2/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/aws-sdk-php/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/aws-sdk-ruby/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/awscli/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/healthcheck/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/mc/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/minio-go/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/minio-java/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/minio-js/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/minio-py/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/s3cmd/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/s3select/install.sh'
RUN bash -c 'source /mint/source.sh && /mint/build/versioning/install.sh'
RUN /mint/postinstall.sh

ENTRYPOINT ["/mint/entrypoint.sh"]
