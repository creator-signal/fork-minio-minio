# Creator Signal MinIO distribution

This directory is the isolation boundary for Creator Signal's maintained MinIO distribution. The MinIO server outside this directory remains at archived upstream commit `7aac2a2c5b7c882e68c1ce017d8256be2feea27f`. Root `go.mod` contains the single integration point that replaces the reduced console dependency with `./creatorsignal/console`.

The service-admission decision is **Extend**: this remains the existing MinIO object-storage service. The compatibility source restores interfaces removed from the Community console; it does not introduce another server, database, identity provider, bucket, or operator dashboard.

## Source boundary

| Path | Purpose | Provenance |
| --- | --- | --- |
| `console/` | Complete MinIO console, including OIDC and administrative handlers/UI | `github.com/minio/console@v1.7.6`, commit `f4a08fc0af8f776aa667677fb943aad137808f7c` |
| `mds/` | Rebuildable MinIO design-system dependency used by the console UI | original `minio/mds` tag `v1.0.4`, commit `027fb7f9834e2bd6daba7f62a9d04d9a3606fbe1` |
| `build.sh` | Reproducible Creator Signal version metadata and binary build | Creator Signal |
| `Dockerfile` | Fork-owned multi-architecture runtime image | Creator Signal |
| `scripts/` | Fork-specific security and compatibility gates | Creator Signal |

The original console and MDS AGPL licenses, copyright notices, source, generated clients and built assets are retained in their respective directories. Creator Signal modifications remain under the same AGPL-3.0-or-later terms.

The deleted `minio/mds` repository was recovered from `Sunspirytus/minio-mds` at the exact `v1.0.4` commit and cross-checked against the identical commit retained by `focusnetcloud/minio-mds`. The console now uses `file:../../mds`; a build never fetches the deleted upstream repository.

## Restored surface

The compatibility contract asserts the complete 89-path console API. It restores:

- OIDC discovery, redirect, callback, STS credential exchange, console sessions and IdP logout;
- users, groups, policies, service accounts and identity-provider configuration;
- server configuration, notification endpoints, nodes, restart controls and release information;
- bucket versioning, quota, events, encryption, retention, legal hold, tags and object locking;
- bucket and site replication, remote buckets and rewind controls;
- KMS status, metrics, APIs, version and key management;
- logs, diagnostic inspection, trace/profiling-backed UI and dashboard widgets;
- the full object browser and object-management surface.

These are console HTTP handlers and panels backed by MinIO's retained S3/admin APIs, not newly introduced background services. Anything absent from console `v1.7.6` remains absent. Repository tests establish source compatibility only; every privileged panel remains **not live accepted** until a separately approved deployment completes ZITADEL login, authorization and browser checks.

## Security maintenance

- `console/api/creator_signal_compat_test.go` fails if the route surface shrinks or the OIDC redirect/callback no longer produces a console session.
- The UI is rebuilt from committed source and lockfile. High and critical production dependency advisories fail CI.
- `GHSA-qwww-vcr4-c8h2` is the sole documented high-severity reachability exception: it affects React Router RSC action handling, while this console uses `BrowserRouter` declarative mode and no React Server Components. The audit script invalidates the exception if RSC markers appear.
- The image pipeline scans the built runtime for fixed high/critical vulnerabilities and emits an OCI SBOM plus provenance attestations.
- Release UI builds omit platform-dependent source maps, keeping generated assets reproducible without publishing bundled source content.
- The distribution builds with Go `1.25.12` and an Alpine `3.23` runtime. Root-module security pins refresh the archived server's vulnerable standard library, cryptography, networking, telemetry, gRPC and Prometheus dependency graph without changing MinIO feature code.
- The fork is frozen by default. Dependency or base-image refreshes require a reviewed issue, regenerated UI assets, the full compatibility gate and a new immutable release tag.

See [RELEASE.md](RELEASE.md) for release and rollback instructions.
