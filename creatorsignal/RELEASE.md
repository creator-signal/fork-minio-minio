# Build, release and rollback

## Local validation

From the repository root:

```sh
go test ./cmd -run '^$'
(cd creatorsignal/console && go test ./api -run TestCreatorSignal -v)
(cd creatorsignal/console/web-app && yarn install --frozen-lockfile --ignore-scripts && CI=true yarn build)
node creatorsignal/scripts/check-console-audit.mjs
CREATOR_SIGNAL_COMMIT=$(git rev-parse HEAD) sh creatorsignal/build.sh dist/minio
docker build -f creatorsignal/Dockerfile -t creator-signal-minio:test \
  --build-arg CREATOR_SIGNAL_COMMIT=$(git rev-parse HEAD) .
docker run --rm creator-signal-minio:test --version
```

The committed `web-app/build` directory is the Go-embedded console. A UI source or dependency change must rebuild it and commit the exact generated asset changes.

## Release contract

Pull requests and `master` pushes validate but never publish. Publishing requires an explicit tag matching:

```text
RELEASE.YYYY-MM-DDTHH-MM-SSZ.creatorsignal.N
```

For example:

```sh
git tag RELEASE.2026-08-04T12-00-00Z.creatorsignal.1
git push origin RELEASE.2026-08-04T12-00-00Z.creatorsignal.1
```

The tag pipeline publishes:

- `ghcr.io/creator-signal/fork-minio-minio:<tag>` and `:latest` for `linux/amd64` and `linux/arm64`;
- GitHub Release binaries and SHA-256 files for both architectures;
- GitHub build-provenance attestations for binaries and the image;
- an OCI SBOM and provenance attestation attached to the image manifest.

The embedded MinIO compatibility release remains `RELEASE.2025-10-15T17-29-55Z`; the Creator Signal version and exact fork commit are separate binary/image metadata. Consumers must deploy the immutable GHCR digest, never the mutable `latest` tag.

## Adoption and rollback

This repository release does not authorize a Sales Pulse or production deployment. Adoption is a separate change that replaces only the object-storage image reference and reviewed digest, preserves all volumes/configuration, then exercises health, S3, admin API and ZITADEL browser acceptance.

Rollback means restoring the previously accepted image digest and redeploying only object storage. Do not reset or recreate MinIO data/config volumes. Before adoption, capture a verified backup and confirm that the previous binary can read the existing on-disk format. If a new release writes an incompatible format, stop and follow the MinIO upgrade/rollback constraints instead of forcing the old image.
