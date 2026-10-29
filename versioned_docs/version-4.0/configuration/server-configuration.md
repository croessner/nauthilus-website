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

### Trusted Proxies and Client IP Resolution

Forwarding headers are honored only when the direct TCP peer matches `runtime.servers.http.trusted_proxies`. For such a
peer, Nauthilus resolves the client IP as follows:

1. All `X-Forwarded-For` header lines are joined in wire order, so a proxy that appends its peer as a separate header
   line is not overridden by a client-supplied first line.
2. The joined chain is walked from right to left. The first address that is not a trusted proxy is the client IP; if
   every hop is trusted, the leftmost address is used.
3. If `X-Forwarded-For` is present but does not resolve to a valid address (for example, it contains a malformed
   entry), the direct peer address is used. `X-Real-IP` is not consulted in that case, because it may carry a
   client-controlled value.
4. `X-Real-IP` is used only when the trusted peer sent no `X-Forwarded-For` header at all.

Requests from peers that are not trusted proxies always use the direct peer address. Keep `trusted_proxies` limited to
proxy addresses or narrow networks you operate: the resolved address feeds authentication and brute-force handling,
the HTTP rate limit, IdP flows, and logs.

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

`middlewares.limit` bounds the number of requests in flight to `auth.pipeline.max_concurrent_requests`. The HTTP API and
the gRPC authority listener share this one budget; see [Concurrency Limit](#concurrency-limit).

`middlewares.rate` enables a per-client-IP token bucket with `rate_limit.per_second` and `burst`. It applies to every
request of the IdP, frontend, UI, Policy API, and custom hooks; the health routes below and `/metrics` are exempt. On the
caller-authenticated backchannel API it is a failure budget instead: requests whose caller authentication succeeds never
consume it, only failed caller authentications do. See
[Backchannel Caller Rejections](../rest-api.md#backchannel-caller-rejections).

### Health Endpoints

The HTTP listener serves three unauthenticated health routes. They bypass the concurrency limiter and the per-IP rate
limiter, and Basic credentials sent to them are never counted as backchannel caller outcomes.

| Route | Answer | Checks | Purpose |
|---|---|---|---|
| `GET /ping` | `200` with the plain text `pong` | none | Manual reachability test |
| `GET /livez` | `200` with `{"status":"up"}` | none | Liveness probe |
| `GET /healthz` | `200` or `503` with `{"status":...,"checks":{...}}` | test backend login, Redis, LDAP | Readiness and startup probe |

`/livez` only proves that the process accepts and answers HTTP requests. It never touches Redis, LDAP, a backend, or
the configuration, so it stays fast when the server is saturated or a dependency is slow.

`/healthz` runs a test login against the test backend and checks Redis reads, Redis writes, and LDAP. Its `status` is
`down` (HTTP `503`) when the test login fails and `degraded` (HTTP `200`) when only its MFA storage checks fail. Failed
Redis or LDAP checks are reported in `checks` without making the instance unready, with one exception: the
`ldap_queue` check turns `down` (HTTP `503`) when an LDAP lookup or auth pool with a running worker holds queued
requests and no worker has taken one for the longer of 30 seconds and `connect_abort_timeout` plus the 30 second
connect deadline (40 seconds with the default abort timeout). The affected pools are listed as `lookup:<pool>` or
`auth:<pool>` in `meta.pools`. Workers that take requests at any rate count as progress, so a slow but working
directory never trips the check.

Use `/livez` for Kubernetes liveness probes and `/healthz` for readiness and startup probes. A liveness probe that runs
the readiness checks restarts healthy pods whenever a dependency is slow. The image's `/usr/app/healthcheck` binary
expects a JSON `status` field, so `/ping` is not a valid target for it:

```yaml
livenessProbe:
  exec:
    command: ["/usr/app/healthcheck", "--url", "https://127.0.0.1:9443/livez", "--tls-skip-verify"]
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
readinessProbe:
  exec:
    command: ["/usr/app/healthcheck", "--url", "https://127.0.0.1:9443/healthz", "--tls-skip-verify"]
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
startupProbe:
  exec:
    command: ["/usr/app/healthcheck", "--url", "https://127.0.0.1:9443/healthz", "--tls-skip-verify"]
  periodSeconds: 5
  timeoutSeconds: 5
  failureThreshold: 30
```

### OpenAPI Runtime Request Validation

Nauthilus publishes stable OpenAPI contracts for the management API and the public IdP API. The runtime request validation block is optional and disabled by default. Existing production deployments do not need to add this block unless they explicitly want Nauthilus to reject selected malformed management requests before handler execution.

Default configuration:

```yaml
runtime:
  servers:
    http:
      openapi_validation:
        enabled: false
        enforce: false
        operations: []
```

To enable runtime request validation, set both `enabled` and `enforce` to `true` and select at least one supported operation ID. Warn-only validation is not supported; validation is either off or enforcing.

```yaml
runtime:
  servers:
    http:
      openapi_validation:
        enabled: true
        enforce: true
        operations:
          - flushUserCache
          - enqueueUserCacheFlush
          - flushBruteForceRule
          - enqueueBruteForceRuleFlush
          - listBruteForceEntries
          - listFilteredBruteForceEntries
```

Supported operation IDs:

| Operation ID | Route |
|---|---|
| `flushUserCache` | `DELETE /api/v1/cache/flush` |
| `enqueueUserCacheFlush` | `DELETE /api/v1/cache/flush/async` |
| `flushBruteForceRule` | `DELETE /api/v1/bruteforce/flush` |
| `enqueueBruteForceRuleFlush` | `DELETE /api/v1/bruteforce/flush/async` |
| `listBruteForceEntries` | `GET /api/v1/bruteforce/list` |
| `listFilteredBruteForceEntries` | `POST /api/v1/bruteforce/list` |

The validator uses the same OpenAPI contract that Nauthilus serves at `/api/v1/openapi.yaml` and `/api/v1/openapi.json`. It currently covers only the selected management operations above. Authentication behavior, auth protocol handling, CBOR decoding, and IdP browser/protocol flows stay implemented by the normal runtime code paths.

### gRPC Authority Listener

The gRPC authority listener is a separate optional listener. It exposes the gRPC AuthService with the same authentication pipeline as the JSON and CBOR endpoints without sharing the HTTP/Gin listener. The internal identity backend service used by split edge/authority deployments is a separate opt-in capability on that listener.

```yaml
runtime:
  servers:
    grpc:
      authority:
        enabled: true
        address: "127.0.0.1:9444"
        backend_refs:
          enabled: false
        tls:
          enabled: false
          cert: ""
          key: ""
          client_ca: ""
          min_tls_version: "TLS1.2"
          require_client_cert: false
```

The listener defaults to loopback. Plaintext gRPC is only valid on loopback addresses; non-loopback listeners require TLS. `min_tls_version` accepts `TLS1.2` and `TLS1.3` and defaults to `TLS1.2`. The gRPC listener always uses HTTP/2 ALPN and does not expose configurable cipher suites.

`backend_refs.enabled` defaults to `false`. With that default, the listener registers only `nauthilus.auth.v1.AuthService` and does not create backend-reference state. Set it to `true` on an authority that serves remote Nauthilus edges; this also registers `nauthilus.identity.v1.IdentityBackendService` and requires a working Redis configuration at startup.

#### Connection Ageing and Keepalive

gRPC multiplexes all RPCs of one client channel over a long-lived HTTP/2 connection. A connection-level load balancer,
for example a Kubernetes `ClusterIP` service, only chooses a replica when a connection is opened. Without a bounded
connection lifetime, a client stays pinned to the first replica it reached, and replicas that start later receive no
traffic. `runtime.servers.grpc.authority.keep_alive` therefore bounds the connection lifetime by default:

```yaml
runtime:
  servers:
    grpc:
      authority:
        keep_alive:
          max_connection_age: 5m
          max_connection_age_grace: 60s
          max_connection_idle: 0s
          min_ping_interval: 10s
          permit_without_stream: true
```

| Key | Default | Meaning |
|---|---|---|
| `max_connection_age` | `5m` | The listener sends an HTTP/2 GOAWAY after this age. gRPC adds a random jitter of +/-10% so clients do not reconnect in lockstep. `0` disables connection ageing. |
| `max_connection_age_grace` | `60s` | In-flight RPCs may finish for this long after GOAWAY before the connection is closed forcibly. `0` means no forced close. A positive value requires `max_connection_age > 0`. The default exceeds the default `runtime.timeouts.lua_script` (`30s`). |
| `max_connection_idle` | `0s` | Closes connections without active RPCs after this idle time. `0` disables the idle limit. |
| `min_ping_interval` | `10s` | Shortest client keepalive ping interval the listener tolerates. Clients that ping more often receive GOAWAY `too_many_pings`. `0` selects the default. |
| `permit_without_stream` | `true` | Allows client keepalive pings while no RPC is active. |

Negative durations are rejected during configuration validation.

GOAWAY is graceful: the client finishes in-flight RPCs on the old connection, opens a new one for the next RPC, and
re-resolves the target name. Keep `max_connection_age_grace` above the longest client RPC deadline and the longest
server-side pipeline step. Connection ageing lets a connection-level load balancer re-pick a replica on each reconnect,
which spreads long-lived clients statistically over time, but one client channel still sends all RPCs to one replica
at a time. For an even per-RPC distribution, let clients resolve all replicas (for example a headless Kubernetes
service with a `dns:///` target) and use the `round_robin` load-balancing policy.

Upgrading from an earlier v4 prerelease enables connection ageing with these defaults. Set `max_connection_age: 0s` (and leave
`max_connection_age_grace` unset or `0s`) to keep the previous unbounded connection lifetime.

#### Concurrency Limit

When `runtime.servers.http.middlewares.limit` is enabled, the HTTP API and the gRPC authority listener draw on one
shared counter sized by `auth.pipeline.max_concurrent_requests`, because both transports allocate memory of the same
process. Slots are reserved atomically. An HTTP request beyond the budget is answered with `429`; a gRPC
call beyond it is answered with `RESOURCE_EXHAUSTED` before tracing, logging, and caller authentication run, so callers
fail fast and can retry instead of queueing inside the server. With the limit middleware disabled, neither transport is
bounded.

Size `max_concurrent_requests` for the combined peak of both transports, including backchannel callers such as a mail
director that sends its load over gRPC.

Backchannel caller authentication uses the existing `auth.backchannel.basic_auth` and `auth.backchannel.oidc_bearer` settings. See [gRPC Authority APIs](../grpc-api.md) for the service contract and [Split Identity Proxy Configuration](identity-proxy.md) for the distributed deployment model.

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
    grpc:
      nauthilus_authorities:
        primary:
          address: "authority.internal.example:9444"
          timeout: 5s
          edge_cluster_id: "dmz-edge"
          edge_instance_id: "edge-a"
          tls:
            enabled: true
            server_name: "authority.internal.example"
            ca: "/etc/nauthilus/tls/authority-ca.pem"
            cert: "/etc/nauthilus/tls/edge-a.crt"
            key: "/etc/nauthilus/tls/edge-a.key"
            min_tls_version: "TLS1.3"
          caller_auth:
            oidc_bearer:
              enabled: true
              mode: "client_credentials"
              token_endpoint: "https://authority.internal.example/oidc/token"
              client_id: "edge-primary"
              token_endpoint_auth_method: "private_key_jwt"
              client_private_key_file: "/etc/nauthilus/keys/edge-primary.key"
              client_assertion_alg: "RS256"
              scopes:
                - nauthilus:authenticate
                - nauthilus:lookup_identity
              token_cache:
                backend: "redis"
                key_prefix: "grpc:authority_tokens:"
```

Outbound HTTP client TLS uses the same `min_tls_version` and `cipher_suites` validation rules as the inbound HTTP server TLS block: TLS 1.3 cipher-suite names are rejected, and `cipher_suites` must be empty when the minimum version is `TLS1.3`.

Outbound authority clients under `runtime.clients.grpc.nauthilus_authorities` are used by the remote backend. Non-loopback targets require TLS and mTLS certificate material. Caller auth is mandatory; use OIDC client credentials with `private_key_jwt` for production edge instances. The caller-token cache uses the edge instance's Redis connection.

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
    notice_ignore_fields: []
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
    endpoint_auth:
      basic:
        enabled: false
        username: ""
        password: ""
```

Important paths:

- `observability.log.*`
- `observability.profiles.pprof.enabled`
- `observability.profiles.block.enabled`
- `observability.tracing.*`
- `observability.metrics.monitor_connections`
- `observability.metrics.prometheus_timer.*`
- `observability.metrics.endpoint_auth.basic.*`

### NOTICE Field Filtering

`observability.log.notice_ignore_fields` removes selected structured field keys from NOTICE records. An omitted or
empty list keeps the complete output.

```yaml
observability:
  log:
    notice_ignore_fields:
      - source
      - ssl_client_subject_dn
      - ssl_client_issuer_dn
      - ldap_lookup
```

- Matching is exact and case-sensitive. Keys can belong to built-in request fields, plugin or Lua `AdditionalLogs`,
  bound logger attributes, or trace correlation. Unknown keys are accepted so that custom fields can be filtered.
- Matching leaf attributes inside structured groups are removed as well; group names are not field selectors. Every
  occurrence of a matching key is omitted.
- Filtering applies to all NOTICE records, including request processing, authentication results, and identity events.
  DEBUG, INFO, WARN, and ERROR records keep their complete fields.
- The required keys `time`, `level`, `instance`, `session`, and `msg` cannot be listed, and blank entries are rejected
  during configuration validation. Required fields stay present wherever the logger or event supplies them; the filter
  does not add session IDs to events that have none.
- JSON, text, and colored text output share the same selection. A configuration reload updates the selection for
  existing and new loggers.

Filtering reduces the encoded output only; producers still compute the values. Removed fields are also missing from
downstream log searches, so keep the identifiers and decision evidence your operations need.

### Startup Failures

A failed startup is logged once at `ERROR` with the failing step, for example
`start HTTP entry points: privilege drop failed: ...`, and the process exits with code `1`. The reason is therefore
visible at every log level.

### Tracing

`observability.tracing.enable_redis` adds OpenTelemetry spans for Redis commands and pipelines. The spans keep the
operation, timing, and status but never carry the raw `db.statement` attribute, because Redis keys and arguments can
contain bearer tokens, credentials, or account data. Telemetry that an older release already exported is not removed.

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
    identity_cache:
      enabled: false
      ttl: 1m
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

A `sentinels` block whose fields are all empty, as printed by `nauthilus -d`, means that Sentinel is not configured.
As soon as any Sentinel field is set, the block is validated strictly: `master` is required and `addresses` must list
at least one Sentinel, so `master` with `addresses: []` fails validation.

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

### Redis for the Identity Provider

When the built-in OIDC provider is enabled, Redis holds token state, dynamic client registrations, device flows, and
revocation epochs:

- keep `storage.redis.encryption_secret` (mandatory, at least 16 characters) stable; token, code, and user-code
  references in Redis keys are keyed digests of it;
- run the IdP Redis with `maxmemory-policy noeviction`, because revocation epochs have no TTL;
- use Redis 6.2 or newer, or a compatible Valkey;
- Redis Cluster is supported; every IdP script and transaction stays within one hash slot.

See [Token State in Redis](idp/oidc.md#token-state-in-redis) for the key layout, secret rotation, and the upgrade impact
from earlier v4 prereleases.

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

`batching` is disabled by default and should stay disabled unless a measurement on the actual workload shows a gain.
The hook drains its queue with a single flush worker per Redis client, so every single command of that client is
serialized behind that worker. Under concurrent load callers wait in the queue; a load test measured waits of up to
1.7 s per command and authentication timeouts at about 40 logins/s across three pods. Explicit pipelines, which the
brute-force paths use, pass through the hook unchanged.

### Positive Caches: UCP and UCI

Nauthilus keeps two independent positive Redis caches for backend results:

| Cache | Key namespace | Serves | Enabled by | Lifetime |
|---|---|---|---|---|
| Positive password cache (UCP) | `<prefix>UCP:<cache_name>:<account>` | password authentication with a verified credential | a `cache` entry in `auth.backends.order` | `storage.redis.positive_cache_ttl` |
| Identity lookup cache (UCI) | `<prefix>UCI:<cache_name>:<username>` | passwordless LDAP identity lookups (`lookup_identity`) | `storage.redis.identity_cache.enabled` | `storage.redis.identity_cache.ttl` |

A UCP entry carries password evidence: the full prepared password digest (including `password_nonce`), never the raw
password. A UCI entry carries no password evidence and can never satisfy a password authentication request. Both use
the configured Redis encryption for their payloads and the `cache_name` of the matching backend search block (see
[Cache Namespaces](database-backends/cache-namespaces.md)).

### Identity Lookup Cache

Passwordless identity lookups (the `lookup_identity` operation: HTTP authentication requests with `mode=no-auth` and
the gRPC `LookupIdentity` call) can use a dedicated positive Redis cache for successful LDAP results. The cache is disabled by default and has to be enabled
explicitly:

```yaml
storage:
  redis:
    identity_cache:
      enabled: true
      ttl: 60s
```

| Key | Type | Default | Purpose |
|---|---|---|---|
| `storage.redis.identity_cache.enabled` | boolean | `false` | Cache successful passwordless LDAP identity lookups in Redis. |
| `storage.redis.identity_cache.ttl` | duration | `1m` | Fixed lifetime of an identity entry. An omitted or zero value uses one minute; explicit values must be between `1s` and `8760h`. |

Behavior:

- Choose a short TTL that matches the freshness you need for account attributes and group membership. Cache hits do
  not extend the lifetime of an entry.
- Enabling the option is sufficient for LDAP identity lookups. It does not require a `cache` entry in
  `auth.backends.order`.
- Only identity lookups are eligible. Password authentication, master-user requests, and identity provider (OIDC/SAML)
  requests always reach LDAP and keep their existing behavior.
- The cache stores successful LDAP backend results (attributes and groups) before per-request Policy and plugin
  processing. Policy and authorization still run for every request, including cache hits. A cache hit is logged with
  the backend `cache` and the field `cache_kind=identity`.
- Native backend plugins and Lua backends do not populate this cache.
- Protocol, client, backend, and the rendered LDAP lookup context separate otherwise similar identity requests. Entries
  for the same username and cache namespace share one slot, so a different context replaces that slot. This can reduce
  the hit rate but never returns an entry for a different context.
- No negative identity entries are stored.
- Redis failures and unusable entries fall back to LDAP. A failed cache write does not turn a successful LDAP lookup
  into an authentication failure.
- Identity cache reads use the Redis primary (write handle) even when replica reads are enabled, so replica lag cannot
  bypass invalidation.

#### LDAP Membership Cache Bypass

Eligible identity lookups bypass both reads and writes of the process-local LDAP group membership cache. A UCI miss
therefore resolves the current LDAP groups before a new snapshot is stored, and the local membership TTL cannot extend
identity-cache staleness or repopulate stale groups after a flush. Password and browser IdP requests keep the existing
membership-cache behavior.

#### Invalidation

The user-cache flush API (`DELETE /api/v1/cache/flush` and the asynchronous `DELETE /api/v1/cache/flush/async`) and the
internal cache purge invalidate identity entries together with the password cache entries of the user.

Identity invalidation deliberately rotates a shared generation for the configured Redis prefix:

:::warning Flushing one user makes all identity entries cold

A user flush invalidates **all** identity cache entries under `storage.redis.prefix`, including entries served by
other Nauthilus instances that share the same Redis. The canonical account of an alias can be unknown until LDAP
answers, so a narrower invalidation could let an in-flight lookup repopulate stale data after the flush. Old payloads
expire through their fixed TTL.

:::

- The generation is stored in the persistent key `<prefix>UCI:epoch`. Keep it persistent; it is not an expiring
  payload. A lost or unreadable generation never makes previously invalidated entries usable again.
- Every user flush rotates the generation, also on instances that do not enable the identity cache themselves, so
  caches of enabled peers are always invalidated.
- If the generation cannot be rotated, the synchronous flush answers `503` with `Identity cache invalidation failed`
  and the asynchronous job is reported as failed. A successful flush is required for immediate invalidation;
  investigate reported Redis errors.
- After an external LDAP account or group change, flush the affected user or wait for the identity TTL.

#### Security Notes

- Configure `storage.redis.encryption_secret`; identity payloads are encrypted with the Redis encryption manager.
- If the generation key is lost, for example through Redis eviction, Nauthilus creates a new generation and all
  existing identity entries become cold; previously invalidated entries never become valid again.
- A cached identity is never password evidence. Account authorization, Policy rules, and plugins still evaluate every
  request.

## What Moved Out

The following things are no longer documented under a generic `server` block:

- request header names -> `auth.request.headers`
- backchannel auth -> `auth.backchannel`
- backend order -> `auth.backends.order`
- brute-force protocols -> `auth.controls.brute_force.protocols`
- frontend / login UI -> `identity.frontend`
- OIDC / SAML -> `identity.oidc`, `identity.saml`

Use the dedicated pages for those sections.
