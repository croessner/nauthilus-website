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
  listen:
    address: "0.0.0.0:9080"

observability:
  log:
    level: "info"

storage:
  redis:
    primary:
      address: "redis:6379"
    password_nonce: "replace-with-a-long-random-string"

auth:
  backends:
    order:
      - cache
      - ldap
```

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

## Environment Variables

Environment variables follow the canonical v2 path mapping.

Examples:

```yaml
environment:
  NAUTHILUS_RUNTIME_LISTEN_ADDRESS: "0.0.0.0:9080"
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
  listen:
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

## Next Steps

- [Getting Started](/docs/about/getting-started)
- [Configuration Overview](../configuration/index.md)
- [Full Configuration Example](/docs/configuration/full-example)
