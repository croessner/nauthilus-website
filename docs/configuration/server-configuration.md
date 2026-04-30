---
title: Runtime, Observability, and Storage
description: Runtime, gRPC, observability, and Redis settings in config v2
keywords: [Configuration, Runtime, gRPC, Observability, Redis]
sidebar_position: 3
---

# Runtime, Observability, and Storage

What used to be spread across a large `server` section is now split into three focused roots:

- `runtime`
- `observability`
- `storage`

This page covers those sections.

## `runtime`

`runtime` contains process settings, inbound HTTP and gRPC servers, shared runtime timeouts, and outbound client configuration.

### Process

```yaml
runtime:
  process:
    run_as_user: "nauthilus"
    run_as_group: "nauthilus"
    chroot: "/var/empty"
```

### HTTP Server and TLS

```yaml
runtime:
  servers:
    http:
      address: "[::]:9443"
      http3: true
      haproxy_v2: false
      trusted_proxies:
        - "127.0.0.1"
        - "::1"
      tls:
        enabled: true
        cert: "/etc/nauthilus/tls.crt"
        key: "/etc/nauthilus/tls.key"
        ca_file: "/etc/nauthilus/ca.pem"
        min_tls_version: "TLS1.3"
        cipher_suites: []
```

`min_tls_version` accepts `TLS1.2` and `TLS1.3`; unset values default to `TLS1.2`. `cipher_suites` only applies when TLS 1.2 is allowed. Nauthilus rejects TLS 1.3 cipher-suite names in this list because Go does not expose TLS 1.3 cipher-suite selection through `tls.Config.CipherSuites`. Leave the list empty when `min_tls_version: "TLS1.3"` is configured.

### HTTP Runtime

```yaml
runtime:
  servers:
    http:
      disabled_endpoints:
        auth_header: false
        auth_json: false
        auth_cbor: false
        auth_basic: false
        auth_nginx: false
        auth_jwt: false
        custom_hooks: false
        configuration: false
      middlewares:
        logging: true
        limit: true
        recovery: true
        trusted_proxies: true
        request_decompression: true
        response_compression: true
        metrics: true
        rate: true
      compression:
        enabled: true
      keep_alive:
        enabled: true
        timeout: 30s
        max_idle_connections: 100
        max_idle_connections_per_host: 10
      rate_limit:
        per_second: 200
        burst: 400
```

### gRPC Auth Service

The gRPC AuthService runs on a separate optional listener. It exposes the same authentication pipeline as the JSON and CBOR endpoints without sharing the HTTP/Gin listener.

```yaml
runtime:
  servers:
    grpc:
      auth:
        enabled: true
        address: "127.0.0.1:9444"
        tls:
          enabled: false
          cert: ""
          key: ""
          client_ca: ""
          min_tls_version: "TLS1.2"
          require_client_cert: false
```

The listener defaults to loopback. Plaintext gRPC is only valid on loopback addresses; non-loopback listeners require TLS. `min_tls_version` accepts `TLS1.2` and `TLS1.3` and defaults to `TLS1.2`. The gRPC listener always uses HTTP/2 ALPN and does not expose configurable cipher suites.

Backchannel caller authentication uses the existing `auth.backchannel.basic_auth` and `auth.backchannel.oidc_bearer` settings. See [gRPC Auth API](../grpc-api.md) for the service contract.

### Shared Runtime Timeouts

Timeouts are shared by HTTP and gRPC authentication paths.

```yaml
runtime:
  timeouts:
    redis_read: 1s
    redis_write: 2s
    ldap_search: 3s
    ldap_bind: 3s
    ldap_modify: 5s
    lua_backend: 5s
    lua_script: 30s
```

`runtime.timeouts.singleflight_work` is deprecated and ignored; do not use it for new configurations.

### Outbound Clients

```yaml
runtime:
  clients:
    http:
      max_connections_per_host: 10
      max_idle_connections: 10
      max_idle_connections_per_host: 5
      idle_connection_timeout: 60s
      proxy: "http://proxy.example.com:8080"
      tls:
        skip_verify: false
        min_tls_version: "TLS1.2"
        cipher_suites: []
    dns:
      resolver: "192.0.2.53"
      timeout: 5s
      resolve_client_ip: false
```

Outbound HTTP client TLS uses the same `min_tls_version` and `cipher_suites` validation rules as the inbound HTTP server TLS block: TLS 1.3 cipher-suite names are rejected, and `cipher_suites` must be empty when the minimum version is `TLS1.3`.

## `observability`

`observability` groups logs, profiles, tracing, and metrics.

```yaml
observability:
  log:
    json: false
    color: true
    level: "info"
    add_source: false
    debug_modules: []
  profiles:
    pprof:
      enabled: false
    block:
      enabled: false
  tracing:
    enabled: false
    exporter: "none"
    endpoint: ""
    sampler_ratio: 0.1
    service_name: "nauthilus"
    propagators:
      - "tracecontext"
      - "baggage"
    enable_redis: false
    log_export_results: false
  metrics:
    monitor_connections: false
    prometheus_timer:
      enabled: false
      labels: []
```

Important paths:

- `observability.log.*`
- `observability.profiles.pprof.enabled`
- `observability.profiles.block.enabled`
- `observability.tracing.*`
- `observability.metrics.monitor_connections`
- `observability.metrics.prometheus_timer.*`

## `storage`

`storage` currently contains the Redis configuration.

```yaml
storage:
  redis:
    protocol: 2
    database_number: 0
    prefix: "nt:"
    password_nonce: "replace-with-a-long-random-string"
    encryption_secret: "replace-with-a-long-random-string"
    pool_size: 128
    idle_pool_size: 32
    positive_cache_ttl: 1h
    negative_cache_ttl: 2h
    primary:
      address: "127.0.0.1:6379"
      username: ""
      password: ""
```

### Topologies

Primary / standalone:

```yaml
storage:
  redis:
    primary:
      address: "redis:6379"
```

Replicas:

```yaml
storage:
  redis:
    replica:
      addresses:
        - "redis-replica-1:6379"
        - "redis-replica-2:6379"
```

Sentinel:

```yaml
storage:
  redis:
    sentinels:
      master: "mymaster"
      addresses:
        - "sentinel-1:26379"
        - "sentinel-2:26379"
```

Cluster:

```yaml
storage:
  redis:
    cluster:
      addresses:
        - "redis-1:6379"
        - "redis-2:6379"
        - "redis-3:6379"
```

### Redis Subsystems

These parts also moved under `storage.redis`:

- `tls`
- `account_local_cache`
- `batching`
- `client_tracking`

Example:

```yaml
storage:
  redis:
    client_tracking:
      enabled: true
      bcast: false
      noloop: true
      prefixes:
        - "nt:"
```

## What Moved Out

The following things are no longer documented under a generic `server` block:

- request header names -> `auth.request.headers`
- backchannel auth -> `auth.backchannel`
- backend order -> `auth.backends.order`
- brute-force protocols -> `auth.controls.brute_force.protocols`
- frontend / login UI -> `identity.frontend`
- OIDC / SAML -> `identity.oidc`, `identity.saml`

Use the dedicated pages for those sections.
