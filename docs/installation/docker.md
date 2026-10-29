---
title: Docker
description: Run Nauthilus in Docker with the current configuration model
keywords: [Docker, Compose, Container, Installation, Configuration]
sidebar_position: 1
---

# Docker Installation

Docker remains the recommended way to deploy Nauthilus.

## Quick Start

Create a `docker-compose.yml`:

```yaml
services:
  nauthilus:
    image: ghcr.io/croessner/nauthilus:latest
    container_name: nauthilus
    restart: unless-stopped
    ports:
      - "9080:9080"
    environment:
      TZ: "Europe/Berlin"
    volumes:
      - ./nauthilus.yml:/etc/nauthilus/nauthilus.yml:ro
    depends_on:
      - redis
    healthcheck:
      test: ["CMD", "/usr/app/healthcheck", "--url", "http://localhost:9080/ping"]
      interval: 30s
      timeout: 30s
      retries: 2
      start_period: 5s

  redis:
    image: redis:alpine
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data

volumes:
  redis-data:
```

Create a minimal `nauthilus.yml` next to it:

```yaml
runtime:
  servers:
    http:
      address: "0.0.0.0:9080"

observability:
  log:
    level: "info"

storage:
  redis:
    primary:
      address: "redis:6379"
    password_nonce: "replace-with-a-long-random-string"
```

This intentionally starts only Nauthilus and Redis so that the process and
health endpoint can be verified. It does not configure an authentication
backend. Add and configure LDAP, Lua, a remote authority, or a native Go plugin
backend before sending authentication traffic.

Then start the stack:

```bash
docker compose up -d
```

## Mounting Configuration

The recommended pattern is still to mount a file:

```yaml
volumes:
  - ./nauthilus.yml:/etc/nauthilus/nauthilus.yml:ro
```

This keeps the runtime image immutable while the configuration stays version-controlled.

## Kubernetes ConfigMap and Secret Mounts

Kubernetes projects ConfigMap and Secret volumes as symbolic links: each visible file points to `..data/<name>`, and
`..data` points to a hidden timestamped directory in the same mount. Nauthilus accepts exactly this layout for files
that the configuration references, for example TLS material, IdP signing keys, Lua scripts and package modules, and
frontend templates:

```yaml
volumes:
  - name: nauthilus-tls
    secret:
      secretName: nauthilus-tls
containers:
  - name: nauthilus
    volumeMounts:
      - name: nauthilus-tls
        mountPath: /etc/nauthilus/tls
        readOnly: true
```

```yaml
runtime:
  servers:
    http:
      tls:
        enabled: true
        cert: "/etc/nauthilus/tls/tls.crt"
        key: "/etc/nauthilus/tls/tls.key"
```

Other symbolic links, links that point outside the mount directory, and absolute link targets are still rejected. The
frontend asset directories (`css`, `js`, `img`, `fonts`) must not contain symbolic links; keep them in the image or in a
plain volume. See [File Artifacts and Symbolic Links](../configuration/reference.md#file-artifacts-and-symbolic-links).

## Environment Variables

Environment variables follow the canonical v2 path mapping.

Examples:

```yaml
environment:
  NAUTHILUS_RUNTIME_SERVERS_HTTP_ADDRESS: "0.0.0.0:9080"
  NAUTHILUS_STORAGE_REDIS_PRIMARY_ADDRESS: "redis:6379"
  NAUTHILUS_STORAGE_REDIS_PASSWORD_NONCE: "${PASSWORD_NONCE}"
  NAUTHILUS_AUTH_BACKCHANNEL_BASIC_AUTH_USERNAME: "${BASIC_AUTH_USERNAME}"
  NAUTHILUS_AUTH_BACKCHANNEL_BASIC_AUTH_PASSWORD: "${BASIC_AUTH_PASSWORD}"
```

## TLS

For production, terminate TLS either in Nauthilus or in a reverse proxy.

Direct TLS in Nauthilus:

```yaml
runtime:
  servers:
    http:
      address: "0.0.0.0:9443"
      tls:
        enabled: true
        cert: "/etc/nauthilus/tls.crt"
        key: "/etc/nauthilus/tls.key"
```

Mount the files:

```yaml
volumes:
  - ./certs/tls.crt:/etc/nauthilus/tls.crt:ro
  - ./certs/tls.key:/etc/nauthilus/tls.key:ro
```

## Validation and Dumps

Useful operational commands:

```bash
docker run --rm -v "$PWD/nauthilus.yml:/etc/nauthilus/nauthilus.yml:ro" \
  ghcr.io/croessner/nauthilus:latest \
  --config /etc/nauthilus/nauthilus.yml --config-check
```

```bash
docker run --rm ghcr.io/croessner/nauthilus:latest -d
```

```bash
docker run --rm -v "$PWD/nauthilus.yml:/etc/nauthilus/nauthilus.yml:ro" \
  ghcr.io/croessner/nauthilus:latest \
  -n --config /etc/nauthilus/nauthilus.yml
```

## Bundled Native Go Plugins

Current stable and debug images build `geoip.so`, `clickhouse.so`, `haveibeenpwnd.so`, `reputation.so`, and `dkim2-intelligence.so` from the same source tree and Go toolchain as the server. The stable image also ships `/usr/app/reputation-worker`; the debug image leaves it out on purpose. The artifacts are installed below:

```text
/usr/local/lib/nauthilus/plugins/
```

Release image builds place detached `.minisig` files beside the artifacts. Loading is opt-in: configure the root-level `plugins` section, trust the public build signer, and select only the modules you need. Do not copy a plugin artifact between image versions or architectures and assume Go ABI compatibility.

See [Native Go Plugin Configuration](../configuration/native-go-plugins.md) and [Reference Plugins](../developer/go-plugins/reference-plugins/index.md).

## Next Steps

- [Getting Started](/docs/about/getting-started)
- [Configuration Overview](../configuration/index.md)
- [Full Configuration Example](/docs/configuration/full-example)
