#!/bin/sh

set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

output=${1:-minio}
version=${CREATOR_SIGNAL_VERSION:-DEVELOPMENT.creatorsignal}
commit=${CREATOR_SIGNAL_COMMIT:-$(git rev-parse HEAD)}
copyright_year=${CREATOR_SIGNAL_COPYRIGHT_YEAR:-$(date -u +%Y)}
target_os=${GOOS:-$(go env GOOS)}
target_arch=${GOARCH:-$(go env GOARCH)}

case "$version" in
*[!A-Za-z0-9._-]*)
	echo "CREATOR_SIGNAL_VERSION contains unsupported characters: $version" >&2
	exit 2
	;;
esac

case "$commit" in
'' | *[!0-9a-fA-F]*)
	echo "CREATOR_SIGNAL_COMMIT must be a hexadecimal Git commit: $commit" >&2
	exit 2
	;;
esac

short_commit=$(printf '%s' "$commit" | cut -c1-12)
ldflags="-s -w"
ldflags="$ldflags -X github.com/minio/minio/cmd.Version=$version"
ldflags="$ldflags -X github.com/minio/minio/cmd.CopyrightYear=$copyright_year"
ldflags="$ldflags -X github.com/minio/minio/cmd.ReleaseTag=$version"
ldflags="$ldflags -X github.com/minio/minio/cmd.CommitID=$commit"
ldflags="$ldflags -X github.com/minio/minio/cmd.ShortCommitID=$short_commit"

mkdir -p "$(dirname -- "$output")"
CGO_ENABLED=0 GOOS="$target_os" GOARCH="$target_arch" \
	go build -buildvcs=false -tags kqueue -trimpath -ldflags "$ldflags" -o "$output" .
