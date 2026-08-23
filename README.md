# Homepage Image

Builds an opinionated wrapper around the upstream [Homepage](https://gethomepage.dev/) container image for homelab deployment.

This image intentionally uses `ghcr.io/gethomepage/homepage` as its base instead of rebuilding the application from source. The upstream image already carries the maintained Next.js build, healthcheck, entrypoint, and runtime dependencies. This repo pins that upstream image and applies the local homelab contract around non-root execution, versioning, named volumes, and Makefile operations.

## Runtime Contract

| Requirement | Value |
| --- | --- |
| Base image | `ghcr.io/gethomepage/homepage:v2.0.0` |
| Runtime UID/GID | `10004:10004` via `PUID` / `PGID` |
| Config directory | `/app/config` |
| HTTP port | `3000` |
| Default host bind | `127.0.0.1:3000` |
| Config volume | `homepage_config_dir:/app/config` |

The upstream container defaults to root for backwards compatibility, but supports dropping privileges through `PUID` and `PGID`. This wrapper sets those defaults to `10004:10004` and prepares `/app/config` with matching ownership.

## Environment

| Variable | Default |
| --- | --- |
| `PUID` | `10004` |
| `PGID` | `10004` |
| `HOMEPAGE_ALLOWED_HOSTS` | `localhost:3000,127.0.0.1:3000` |

Set `HOMEPAGE_ALLOWED_HOSTS` to the real DNS name or host:port used to reach Homepage in the lab.

## Operational Guide

Run these commands inside the `image-homepage` directory.

```bash
make build
make test
make up
```

Publish a multi-platform release:

```bash
make build-multiarch
```

The local `make up` target uses a Docker named volume for `/app/config`. It does not mount the Docker socket by default. If Docker integrations are needed later, prefer a restricted socket proxy rather than mounting `/var/run/docker.sock` directly.
