---
title: Server Configuration
description: Server configuration settings for Nauthilus
keywords: [Configuration, Server]
sidebar_position: 3
---

# Server Configuration

This section defines all required settings that are needed to run the Nauthilus server.

## Basic Server Settings

### server::address
_Default: "127.0.0.1:9080"_

This is the IPv4 or IPv6 addresses combined with a TCP port.

```yaml
server:
  address: "[::]:9443"
```

### server::max_concurrent_requests
_Default: 100_

This setting defines the maximum number of concurrent requests that can be processed by the server.

```yaml
server:
  max_concurrent_requests: 200
```

### server::max_password_history_entries
_Default: 0_

This setting defines the maximum number of password history entries to store for each user.

```yaml
server:
  max_password_history_entries: 10
```

### server::haproxy_v2
_Default: false_

If this setting is turned on (true), Nauthilus can make use of the HAproxy version 2 protocol header to identify the original client request.

```yaml
server:
  haproxy_v2: true
```

### server::http3
_Default: false_

Enable HTTP/3 support for the server. There does not exist the PROXY protocol for this version!

### server::disabled_endpoints

_New in version 1.4.9_<br/>
_Default: All endpoints are enabled_

It is possible to disable certain HTTP location endpoints that are not needed.

```yaml
server:
  disabled_endpoints:
    auth_header: false
    auth_json: false
    auth_basic: false
    auth_nginx: false
    auth_saslauthd: false
    auth_jwt: false
    custom_hooks: false
    configuration: false    # Available from version 1.7.11
```

:::tip
Disableing unused endpoints may enhance overall security!
:::

#### Meaning

| Key-name        | location               | description                                                    |
|-----------------|------------------------|----------------------------------------------------------------|
| auth\_header    | /api/v1/auth/header    | Turn off requests based on HTTP headers                        |
| auth\_json      | /api/v1/auth/json      | Turn off HTTP JSON-POST requests                               |
| auth\_basic     | /api/v1/auth/basic     | Turn off HTTP Basic Authorization requests (recommended!)      |
| auth\_nginx     | /api/v1/auth/nginx     | Turn off Nginx based requests used by the mail plugin of Nginx |
| auth\_saslauthd | /api/v1/auth/saslauthd | Turn off saslauthd requests used with cyrus-sasl               |
| auth\_jwt       | /api/v1/jwt/*          | Turn off JWT authentication endpoints                          |
| custom\_hooks   | /api/v1/custom/*       | Turn off all Lua based custom hooks                            |
| configuration   | /api/v1/config/*       | Turn off all configuration related endpoints                   |

## HTTP Client Configuration

### server::http_client

Whenever Nauthilus is acting as an HTTP client, a common shared Go-builtin HTTP client is used to handle all requests.

There do exist the following HTTP clients in Nauthilus:

| Scope   | Usage                                                                                     |
|---------|-------------------------------------------------------------------------------------------|
| core    | If the Ory hydra frontend is turned on, all admin-API requests are handled by this client |
| action  | Used for Lua actions, if HTTP requests are used                                           |
| filter  | Used for Lua filters, if HTTP requests are used                                           |
| feature | Used for Lua featuress, if HTTP requests are used                                         |
| hook    | Used for Lua custom hooks, if HTTP requests are used                                      |

Settings are shared with all HTTP clients!

| Setting                           | Meaning (Used from official Go docs)                                                                                                                  | Default      |
|-----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|--------------|
| max\_connections\_per\_host       | Limits the total number of connections per host, including connections in the dialing, active, and idle states. On limit violation, dials will block. | 0, no limits |
| max\_idle\_connections            | Controls the maximum number of idle (keep-alive) connections across all hosts.                                                                        | 0, no limits |
| max\_idle\_connections\_per\_host | Controls the maximum idle (keep-alive) connections to keep per-host.                                                                                  | 0, no limits |
| idle\_connection\_timeout         | Is the maximum amount of time an idle (keep-alive) connection will remain idle before closing itself.                                                 | 0, no limits |
| proxy                             | HTTP proxy URL to use for client connections. _New in version 1.7.11_                                                                                 | "", no proxy |
| tls                               | TLS configuration for the HTTP client. _New in version 1.7.11_                                                                                        | See below    |

Units for the timeout option should add a time unit like

* s - seconds
* m - minutes
* h - hours

```yaml
server:
  http_client:
      max_connections_per_host: 10
      max_idle_connections: 5
      max_idle_connections_per_host: 1
      idle_connection_timeout: 60s
      proxy: "http://proxy.example.com:8080"
      tls:
        skip_verify: false
```

## Timeouts

_New in version 1.10.0_

Global, operation-specific timeouts for selected subsystems. Values use Go's duration format (e.g., 500ms, 2s, 1m30s).

```yaml
server:
  timeouts:
    redis_read: 1s          # Timeout for Redis read operations (GET, HGET, etc.). Default: 1s
    redis_write: 2s         # Timeout for Redis write operations (SET, HSET, etc.). Default: 2s
    ldap_search: 3s         # Timeout for LDAP search operations. Default: 3s
    ldap_bind: 3s           # Timeout for LDAP bind/auth operations. Default: 3s
    ldap_modify: 5s         # Timeout for LDAP modify operations. Default: 5s
    lua_backend: 5s         # Timeout for Lua backend operations. Default: 5s
```

Notes
- These are client-side timeouts applied by Nauthilus when talking to external systems or running local subsystems.
- All fields are optional; if omitted or set to a non-positive duration, the defaults shown above are used.
- Deprecated: As of v1.11.4, `singleflight_work` is removed and ignored because in-process deduplication has been withdrawn.

### Keys and defaults

- server::timeouts::redis_read — Default: 1s
- server::timeouts::redis_write — Default: 2s
- server::timeouts::ldap_search — Default: 3s
- server::timeouts::ldap_bind — Default: 3s
- server::timeouts::ldap_modify — Default: 5s
- server::timeouts::lua_backend — Default: 5s
Deprecated/removed in v1.11.4
- server::timeouts::singleflight_work — Removed. Ignored if present.

## HTTP Middlewares

### server::middlewares

New in version 1.11.3

Feature switches to enable/disable individual HTTP middlewares. When a key is omitted, it defaults to true to preserve legacy behavior.

Available switches (all default to true):

- server::middlewares::logging — Access and request logging middleware.
- server::middlewares::limit — Request limiting middleware (enforces server::max_concurrent_requests and protects against overload).
- server::middlewares::recovery — Panic recovery middleware; converts panics into 500 responses and logs stack traces.
- server::middlewares::trusted_proxies — Honors X-Forwarded-For / proxy headers from trusted upstreams.
- server::middlewares::request_decompression — Transparently decompresses incoming requests (e.g., gzip) when applicable.
- server::middlewares::response_compression — Compresses HTTP responses when accepted by the client.
- server::middlewares::metrics — Exposes Prometheus-compatible HTTP metrics.

Example

```yaml
server:
  middlewares:
    logging: true
    limit: true
    recovery: true
    trusted_proxies: true
    request_decompression: true
    response_compression: true
    metrics: true
```

Notes
- Omit a key to keep it enabled. Set a key explicitly to false to disable the corresponding middleware.

## Request de-duplication

### server::dedup

New in version 1.11.0

Controls in-process request de-duplication (singleflight) to collapse identical concurrent work.

:::warning Deprecated/Removed in v1.11.4
In-process deduplication has been removed due to unresolved instability under load. The following keys are deprecated and ignored:

- `server.dedup.in_process_enabled`
- `server.timeouts.singleflight_work`
:::

Keys
- server::dedup::in_process_enabled — Deprecated/ignored since v1.11.4.
- server::dedup::distributed_enabled — Deprecated/ignored. Distributed (Redis-based) deduplication was removed earlier; this flag has no effect.

Example

```yaml
# Deprecated/ignored since v1.11.4
# server:
#   dedup:
#     in_process_enabled: true
#     # distributed_enabled is deprecated and ignored
```

## TLS Configuration

### server::tls

This object defines TLS related settings.

#### server::tls::enabled
_Default: false_

This flag turns on (true) TLS support in the server.

```yaml
server:
  tls:
    enabled: true
```

#### server::tls::cert and server::tls::key
_Default: ""_

These two settings define a path to an X509 PEM-formatted certificate and key.

```yaml
server:
  tls:
    cert: /usr/local/etc/nauthilus/localhost.localdomain.pem
    key: /usr/local/etc/nauthilus/localhost.localdomain.key.pem
```

#### server::tls::skip_verify
_Default: false_  
_New in version 1.7.11_

This flag turns on (true) insecure TLS connections by skipping client certificate verification.

```yaml
server:
  tls:
    skip_verify: true
```

#### server::tls::http_client_skip_verify
_Default: false_  
_Deprecated: Use server::http_client::tls::skip_verify instead_

This flag turns on (true) insecure TLS connections for HTTP(s) requests that are originating from Nauthilus to some remote.

```yaml
server:
  tls:
    http_client_skip_verify: true
```

#### server::tls::min_tls_version
_Default: "TLS1.2"_  
_New in version 1.7.11_

This setting defines the minimum TLS version that the server will accept. Valid values are "TLS1.2" and "TLS1.3".

```yaml
server:
  tls:
    min_tls_version: "TLS1.3"
```

#### server::tls::ca_file
_Default: ""_  
_New in version 1.7.11_

This setting defines the path to a CA certificate file in PEM format. This is used to verify client certificates when mutual TLS authentication is enabled.

```yaml
server:
  tls:
    ca_file: /usr/local/etc/nauthilus/ca.pem
```

#### server::tls::cipher_suites
_Default: []_  
_New in version 1.7.11_

This setting defines a list of cipher suites that the server will use for TLS connections. If not specified, the default Go cipher suites will be used.

```yaml
server:
  tls:
    cipher_suites:
      - "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
      - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
      - "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
```

## Authentication Configuration

### server::basic_auth

This object defines basic authorization settings.

#### server::basic_auth::enabled
_Default: false_

This flag turns on (true) **Basic Auth support** in the server.

#### server::basic_auth::username and server::basic_auth::password
_Default: ""_

These settings define a username and its password that is required by HTTP(s) clients to communicate with Nauthilus. The password must be at least 16 characters long and can contain alphanumeric characters and symbols, but no spaces.

### server::jwt_auth

This object defines JWT (JSON Web Token) authentication settings. JWT authentication provides a more secure and flexible alternative to HTTP Basic Authentication.

When enabled, Nauthilus provides the following JWT endpoints:

- **Token Generation**: `POST /api/v1/jwt/token` - Generate a new JWT token with username and password
- **Token Refresh**: `POST /api/v1/jwt/refresh` - Refresh an existing token using a refresh token

JWT tokens include roles that determine what actions the user can perform:

- `authenticate`: This role is needed to perform authentication requests (renamed from "authenticated" in version 1.7.11)
- `user_info`: Required to access endpoints with `mode=no-auth`
- `list_accounts`: Required to access endpoints with `mode=list-accounts`
- `security`: Access to security-related features like metrics and brute force management
- `admin`: Full access to all features
- Custom roles: Can be defined for your users and used for custom hooks

For multi-instance environments (e.g., behind a load balancer), enable Redis storage for JWT tokens to ensure that tokens generated by one instance can be validated by another instance.

#### server::jwt_auth::enabled
_Default: false_

This flag turns on (true) **JWT authentication support** in the server.

```yaml
server:
  jwt_auth:
    enabled: true
```

#### server::jwt_auth::secret_key
_Default: ""_

This setting defines the secret key used for JWT signing. It should be at least 32 characters long and can contain alphanumeric characters and symbols, but no spaces.

```yaml
server:
  jwt_auth:
    secret_key: "your-secret-key-at-least-32-characters"
```

#### server::jwt_auth::token_expiry
_Default: 1h_

This setting defines the expiration time for JWT tokens.

```yaml
server:
  jwt_auth:
    token_expiry: 2h
```

#### server::jwt_auth::refresh_token
_Default: false_

This flag enables refresh tokens for JWT authentication.

```yaml
server:
  jwt_auth:
    refresh_token: true
```

#### server::jwt_auth::refresh_token_expiry
_Default: 24h_

This setting defines the expiration time for JWT refresh tokens.

```yaml
server:
  jwt_auth:
    refresh_token_expiry: 48h
```

#### server::jwt_auth::store_in_redis
_Default: false_

This flag enables storing JWT tokens in Redis.

```yaml
server:
  jwt_auth:
    store_in_redis: true
```

#### server::jwt_auth::users

This section defines users that can authenticate using JWT.

```yaml
server:
  jwt_auth:
    users:
      - username: admin
        password: "secure-password"
        roles:
          - admin
          - user
      - username: user
        password: "another-secure-password"
        roles:
          - user
```

## Instance Name

### server::instance_name
_Default: "nauthilus"_

This defines the application name. If not defined, it defaults to **nauthilus**

## Logging Configuration

### server::logs

This object defined logging relates settings.

#### server::log::json
_Default: false_

This flag turns on (true) logging in JSON format.

```yaml
server:
  log:
    json: true
```

#### server::log::level
_Default: "none"_

This string defines the log level. It is one of:

| **Level** | Comment                                |
|-----------|----------------------------------------|
| none      | Entirely turn of logging               |
| debug     | See debug modules below!               |
| info      |                                        |
| notice    | New in v1.11.0 — essential events only |
| warn      |                                        |
| error     |                                        |

```yaml
server:
  log:
    level: notice
```

Notes:
- notice is intended for production environments to log only essential, high‑signal events (service start/stop, configuration issues, degraded backends, protection mode changes, and authentication outcomes without verbose details). It reduces log volume while preserving operational visibility.

#### server::log::add_source
_New in version 1.10.0_
_Default: false_

Controls whether the logger attaches source code information (file:line) to each log record. This maps to Go's slog HandlerOptions.AddSource.

Notes:
- When enabled, the JSON formatter adds a "source" object (with file and line) to each entry.
- The text formatter emits a compact source field near the message.
- There is a small performance cost when enabled because caller information must be computed.

Example:
```yaml
server:
  log:
    add_source: true
```

#### server::log::debug_modules
_Default: empty list_

if debugging is turned on, only very limited debug messages are logged by default. You can increase logging by activating
additional log modules. This is the list of all available debug modules:

| **Module**   | Application                                                                            |
|--------------|----------------------------------------------------------------------------------------|
| all          | Full debugging                                                                         |
| auth         | This turns on logging for the main authentication process                              |
| hydra        | Communication with the Ory hydra server                                                |
| webauthn     | Turn on debugging for WebAuthn (under development)                                     |
| statistics   | Prometheus related debugging                                                           |
| whitelist    | Show whitelist related debugging                                                       |
| ldap         | Show LDAP command and filter related debugging                                         |
| ldappool     | Show LDAP-pool related debugging such as free/busy/closed connections and housekeeping |
| cache        | Turn on cache backend related debugging                                                |
| brute\_force | Turn on brute-force related debugging                                                  |
| rbl          | Turn on RBL (realtime-blackhole-list) related debugging                                |
| action       | Turn on Lua post-action related debugging                                              |
| feature      | Turn on feature related debugging                                                      |
| lua          | Turn on Lua related debugging                                                          |
| filter       | Turn on filter related debugging                                                       |
| tolerate     | Turn on debugging for operations related to tolerance or error allowances              |
| neural       | Turn on debugging for neural network-related operations                                |
| jwt          | Turn on debugging for JWT-related operations                                           |
| http         | Turn on debugging for HTTP-related operations                                          |
| account      | Turn on debugging for account lookup/mapping related operations                        |

```yaml
server:
  log:
    debug_modules:
      - auth
      - ldap 
      - filter
```

## Backend Configuration

### server::backends
_Default: none_<br/>
_required_

This object defines, which backends are enabled. You **must** define at least one backend!

| Name  | Comment                                                                                          |
|-------|--------------------------------------------------------------------------------------------------|
| cache | The Redis cache backend is used for positive and failed login requests and **should** be enabled |
| ldap  | This is the native LDAP backend. See settings below for configuration                            |
| lua   | This is a Lua backend                                                                            |

For Multi-LDAP and Multi Lua-backends, you can use a special syntax to specify which pool or backend to use:

```yaml
server:
  backends:
    - cache
    - ldap(pool1)  # Use the LDAP pool named "pool1"
    - lua(backend2)  # Use the Lua backend named "backend2"
```

This syntax allows you to use multiple LDAP pools or Lua backends with different configurations. The pool or backend name must match a name defined in the `optional_ldap_pools` or `optional_lua_backends` sections.

:::note
The **cache* backend not only caches positive and negative requests. It is also a major component for the brute force buckets to detect
users with repetitive wrong passwords.
:::

:::warning
The cache backend should always be the first backend. The order of backends matters!
:::

## Features Configuration

### server::features
_Default: empty list_

This object defines runtime features.

Here is a list of features that can be turned on:

| Name                        | Usage                                                                                                     |
|-----------------------------|-----------------------------------------------------------------------------------------------------------|
| lua                         | General purpose Lua feature. You can have as many features as you like. They run in sequential order      |
| tls\_encryption             | Clients must be connected securely to a service to be allowed to authenticate                             |
| relay\_domains              | If the login name equals to an email address, the domain component is compared to a list of known domains |
| rbl                         | Check a client IP address against realtime blackhole lists                                                |
| backend\_server\_monitoring | This is a special feature that is not used for filtering                                                  |

These features are primarely used to filter out requests before the main authentication process starts.

:::note
The features are run one-by-one. The rbl feature does query lists in parallel. The lua feature is always run as first feature and is the only one that can
skip further processing of other features!
:::

The **backend\_server\_monitoring** feature turns on a background job that does a health check for any kind of backend servers. It holds an in-memory list of alive servers that can be
used in Lua scripts to select healthy servers.

```yaml
server:
  features:
    - tls_encryption
    - lua
    - rbl 
```

## Brute Force Configuration

### server::brute_force_protocols
_Default: empty list_

This object defines a list of protocols for which the brute force protection is turned on.

When a service talks to Nauthilus, it must provide a **protocol** that is used by a remote client while authenticating.

This list describes protocols for which Nauthilus does brute force checks.

Here is a good working example that can be taken in a production environment:

```yaml
server:
  brute_force_protocols:
    - imap
    - imaps
    - submission
    - smtp
    - smtps
    - ory-hydra
    - http
```

:::note
While most of the protocols are free to chose, **ory-hydra** has a special meaning for Nauthilus and is assigned to the
communication between Nauthilus and the Ory hydra serverr.
:::

## Ory Hydra Configuration

### server::ory_hydra_admin_url
_Default: "http://127.0.0.1:4445"_

This setting is the Ory hydra admin URL.

```yaml
server:
  ory_hydra_admin_url: https://hydra.example.com:4445
```

## DNS Configuration

### server::dns

This object defines settings related to the DNS name resolver.

#### server::dns::resolver
_Default: ""_

If this setting is given, Nauthilus does not use the Go internal DNS resolver. Instead, it uses the provided resolver for DNS resolution.

```yaml
server:
  dns:
    resolver: 192.168.0.1
```

#### server::dns::timeout
_Default: 5_

If a custom DNS resolver is set, you can specify a default timeout in seconds, after which DNS queries are aborted without waiting for a result.

```yaml
server:
  dns:
    timeout: 3
```

#### server::dns::resolve_client_ip
_Default: false_

If a DNS reverse lookup should be done for incoming client requests, you can turn on (true) this feature.

```yaml
server:
  dns:
    resolve_client_ip: true
```

:::warning
Turning on this feature will heavily increase network latency and DNS resolver load. It is suggested to use this feature with care.
:::

## Insights Configuration

### server::insights

This object defines settings related to **go pprof** and is mainly useful for developers.

#### server::insights::enable_pprof
_Default: false_

Enable (true) pprof in Go for debugging purposes.

```yaml
server:
  insights:
    enable_pprof: true
```
#### server::insights::enable_block_profile
_Default: false_

If pprof is enabled (required for this flag), you can also activate a block profile, which helps to find blocking code.

```yaml
server:
  insights:
      enable_block_profile: true
```

#### server::insights::monitor_connections
_Default: false_

This flag turns on (true) connection monitoring.

```yaml
server:
  insights:
    monitor_connections: true
```

#### server::insights::tracing (New in v1.11.5)
_Default: disabled_

Enable distributed tracing via OpenTelemetry and configure exporter, endpoint, sampling, and propagators. See the dedicated guide for full details and examples.

```yaml
server:
  insights:
    tracing:
      enabled: true
      exporter: otlphttp
      endpoint: otel-collector.example.com:4318
      sampler_ratio: 0.1
      service_name: nauthilus
      propagators: [tracecontext, baggage, b3]
      enable_redis: true
```

See also: Guides → Tracing (OpenTelemetry): /docs/guides/tracing-opentelemetry

## Redis Configuration

### server::redis

This object defines settings related to the Redis server.

### Connection and timeout tuning (New in v1.11.0)

- Nauthilus 1.11 optimizes Redis connection handling for higher throughput and lower tail latency. The defaults for connection reuse and timeouts have been tuned to better suit busy deployments.
- Application‑level operation budgets continue to be governed by server.timeouts.redis_read and server.timeouts.redis_write.
- Pool sizing and idling are controlled by existing keys server.redis.pool_size and server.redis.idle_pool_size. Sizing guidance:
  - Start pool_size near the expected concurrent backend operations and scale based on saturation metrics.
  - Keep idle_pool_size small unless you have bursty traffic with frequent warmups.
- For clusters, prefer enabling route_reads_to_replicas for read‑heavy workloads.

Operational notes:
- The 1.11 runtime reduces connection churn and improves pipeline efficiency under load.
- Slow Redis or network hiccups will now trip faster client‑side timeouts to keep request latency bounded; review your redis_read/write budgets accordingly.

### Compatibility and RESP3 features (New in v1.11.5)

Nauthilus prefers RESP3 to support push notifications used by client tracking and maintenance notifications. The following options allow you to opt into related functionality while maintaining backward compatibility with older Redis deployments or proxies.

#### server::redis::identity_enabled
_Default: false_

Controls whether the Redis client sends `CLIENT SETINFO` on connect (advertises client identity). Keep disabled for maximum compatibility with older Redis or proxies.

```yaml
server:
  redis:
    identity_enabled: true
```

#### server::redis::maint_notifications_enabled
_Default: false_

Enables `CLIENT MAINT_NOTIFICATIONS` (push‑based maintenance notifications; requires RESP3). Only applicable to standalone and cluster clients.

```yaml
server:
  redis:
    maint_notifications_enabled: true
```

#### server::redis::client_tracking

Enable Redis client‑side caching (RESP3 `CLIENT TRACKING`) to reduce read round‑trips by caching values and receiving invalidation pushes.

```yaml
server:
  redis:
    client_tracking:
      enabled: true
      bcast: true       # broadcast invalidations
      noloop: true      # do not receive invalidations for own writes
      opt_in: false     # require CACHING yes on commands
      opt_out: false    # track all unless CACHING no
      prefixes: ["user:", "account:"]
```

Notes:
- Requires Redis 6+ and RESP3. Use with care in environments with unstable networks or proxies that do not forward push messages.
- Consider excluding blocking commands from batching (see `server.redis.batching.skip_commands`).

#### server::redis::pool_timeout
_New in version 1.11.0_<br/>
_Default: 80ms_

Maximum time to wait for a free connection to become available from the pool before failing the operation.

Valid range: 1ms–30s.

```yaml
server:
  redis:
    pool_timeout: 150ms
```

#### server::redis::dial_timeout
_New in version 1.11.0_<br/>
_Default: 200ms_

TCP connect timeout when establishing a new Redis connection.

Valid range: 1ms–60s.

```yaml
server:
  redis:
    dial_timeout: 500ms
```

#### server::redis::read_timeout
_New in version 1.11.0_<br/>
_Default: 100ms_

Per‑read operation timeout for Redis commands.

Valid range: 1ms–60s.

```yaml
server:
  redis:
    read_timeout: 250ms
```

#### server::redis::write_timeout
_New in version 1.11.0_<br/>
_Default: 100ms_

Per‑write operation timeout for Redis commands.

Valid range: 1ms–60s.

```yaml
server:
  redis:
    write_timeout: 250ms
```

#### server::redis::client_tracking
_New in version 1.11.4_<br/>
_Default: disabled_

Client-side caching based on Redis CLIENT TRACKING (RESP3). When enabled, each new Redis connection issues a `CLIENT TRACKING ON` with the configured flags. This can reduce read round-trips by serving cached values and consuming invalidation push messages from Redis.

Options:
- `enabled` (bool): Turn tracking on for all new connections.
- `bcast` (bool): Use broadcast mode (`BCAST`) to receive invalidations for all keys touched by the server, without per-key tracking.
- `noloop` (bool): Avoid receiving invalidations for writes that originate from the same client connection.
- `opt_in` (bool): Track only commands that explicitly opt-in via `CACHING yes`.
- `opt_out` (bool): Track all commands except those that opt out via `CACHING no`.
- `prefixes` (list of strings): Restrict tracking to keys with any of the given prefixes.

Notes:
- Requires Redis 6+ and RESP3.
- `opt_in` and `opt_out` are mutually exclusive; configure at most one of them.
- Use with care when network conditions are unstable, as invalidation push messages must be delivered reliably.

Example:
```yaml
server:
  redis:
    client_tracking:
      enabled: true
      bcast: false
      noloop: true
      opt_in: false
      opt_out: true
      prefixes: ["nt_", "sess:"]
```

#### server::redis::pool_fifo
_New in version 1.11.0_<br/>
_Default: true_

Whether the pool hands out connections in FIFO order. Keeping this enabled generally reduces tail latency under load.

```yaml
server:
  redis:
    pool_fifo: true
```

#### server::redis::conn_max_idle_time
_New in version 1.11.0_<br/>
_Default: 90s_

Maximum time a connection may remain idle in the pool before it is closed.

Valid range: 0s–24h.

```yaml
server:
  redis:
    conn_max_idle_time: 2m
```

#### server::redis::max_retries
_New in version 1.11.0_<br/>
_Default: 1_

Maximum number of retries for a Redis command on transient errors (like timeouts). Set to 0 to disable client‑side retries.

```yaml
server:
  redis:
    max_retries: 2
```

#### server::redis::account_local_cache
New in version 1.11.3

Lightweight in-process cache for mapping username to account name. Reduces Redis lookups for frequently accessed users. Disabled by default.

Keys and defaults
- server::redis::account_local_cache::enabled — Default: false. Turns the cache on/off.
- server::redis::account_local_cache::ttl — Default: 60s. Time to keep an item cached.
- server::redis::account_local_cache::shards — Default: 32. Number of internal shards to reduce lock contention (1–1024).
- server::redis::account_local_cache::cleanup_interval — Default: 10m. Background cleanup interval.
- server::redis::account_local_cache::max_items — Default: 0 (unlimited). Best‑effort upper bound; when reached, new items are not added until entries expire.

Example

```yaml
server:
  redis:
    account_local_cache:
      enabled: true
      ttl: 90s
      shards: 64
      cleanup_interval: 5m
      max_items: 100000
```

Notes
- This is an in‑memory cache per Nauthilus instance. It does not replicate across nodes.
- Set max_items: 0 to disable size limiting (TTL still applies).

#### server::redis::batching
New in version 1.11.3

Optional client‑side command batching for Redis. When enabled, commands are briefly queued and flushed as a pipeline, reducing network round‑trips under load.

Keys and defaults
- server::redis::batching::enabled — Default: false. Master switch.
- server::redis::batching::max_batch_size — Default: 16. Max commands per pipeline (2–1024).
- server::redis::batching::max_wait — Default: 2ms. Max time a command may wait before a forced flush (0–200ms; 0 disables time‑based flushing).
- server::redis::batching::queue_capacity — Default: 8192. Internal queue capacity; 0 uses the default.
- server::redis::batching::skip_commands — Default: []. List of command names to never batch (lowercase), e.g., ["blpop", "subscribe"].
- server::redis::batching::pipeline_timeout — Default: 5s. Max time to wait when sending a pipeline.

Example

```yaml
server:
  redis:
    batching:
      enabled: true
      max_batch_size: 32
      max_wait: 3ms
      queue_capacity: 12000
      skip_commands: ["blpop", "brpop", "subscribe"]
      pipeline_timeout: 5s
```

Operational guidance
- Batching is most beneficial with high concurrency and many small commands. Measure p95/p99 latency before and after.
- Do not batch blocking or PubSub‑related commands; add them to skip_commands.

#### server::redis::database_number
_Default: 0_

If Redis is configured to run standalone, master-slave or as sentinel, you can select the database number that Nauthilus must use.

```yaml
server:
  redis:
      database_number: 2
```

#### server::redis::prefix
_Default: ""_

You can define a prefix that has to be used for any keys in Redis.

```yaml
server:
  redis:
    prefix: "nt_"
```

:::note
This prefix is for Nauthilus internal keys only. If you chode to use Redis within Lua, you have to manage Redis keys yourself
:::

:::tip
You may define custom prefixes in Lua with "ntc:" Like "Nauthilus-custom". That way you have a difference between built-in keys and user defined keys.
:::

#### server::redis::password_nonce
_Default: ""_<br/>
_required_

This is a random string used to concatenate it with the password. The result will be hashed and truncated and
is used in Redis. This helps secure password storage in Redis. The password nonce must be at least 16 characters long and can contain alphanumeric characters and symbols, but no spaces.

```yaml
server:
  redis:
    password_nonce: "some-random-string-used-for-password-hashing"
```

#### server::redis::pool_size
_Default: 0_<br/>
_required_

This is a Redis pool size. The pool is managed by the underlying redis library go-redis.

```yaml
server:
  redis:
    pool_size: 10
```

#### server::redis::idle_pool_size
_Default: 0_

This is a Redis idle pool size. The pool is managed by the underlying redis library go-redis.

```yaml
server:
  redis:
    idle_pool_size: 2
```

#### server::redis::tls
_New in version 1.7.11_

This section configures TLS for Redis connections.

```yaml
server:
  redis:
    tls:
      skip_verify: false
```

#### server::redis::positive_cache_ttl and server::redis::negative_cache_ttl
_Default: 3600_

Both values set the expiration value for Redis keys in seconds. The positive cache TTL is for authenticated users, while the
negative cache TTL is for authentication failures. The latter may be larger as it is also used in the brute-force logic to
detect users that try to log in with a repeating wrong password. Such requests are never treated as an attack.

```yaml
server:
  redis:
    positive_cache_ttl: 3600
    negative_cache_ttl: 7200
```

_Changes in version 1.4.9:_

Units should now add a time unit like

* s - seconds
* m - minutes
* h - hours

#### server::redis::protocol
_New in version 1.11.11_<br/>
_Default: 2 (or 3 if RESP3 features are enabled)_

This setting allows forcing the Redis protocol version (2 or 3). If not set (0), it defaults to 2 unless features requiring RESP3 (like client-side tracking or maintenance notifications) are enabled.

Forcing the protocol to 2 can resolve parsing issues with asynchronous push messages in pipelines, especially during heavy brute-force protection logic where RESP3 push messages might interfere with command responses ("Pipeline BruteForce").

```yaml
server:
  redis:
    protocol: 2
```

Valid values: `0` (auto), `2`, or `3`.

#### server::redis::master

If running Redis standalone or in master-slave mode, you have to define the master object.

#### server::redis::master::address
_Default: "127.0.0.1:6379"_

This is the socket for a Redis connection to either a standalone server or for a master.

```yaml
server:
  redis:
    master:
      address: 127.0.0.1:6379
```

#### server::redis::master::username and server::redis::master::password
_Default: empty_

This is an optional username and password for Redis, if the service requires authentication.

```yaml
Server:
  redis:
    master:
      username: some_user
      password: some_secret
```

#### server::redis::replica

This object defines a replica to a master. Currently, there is only support for one master and one replica. If you need more
replica server, consider using sentinel instead or use some load balancer in front of Nauthilus that may distribute replica
connections to more than one replica instance.

#### server::redis::replica::address
_Deprecated in version 1.4.10_<br/>
_Default: ""_

This is the socket for a Redis connection to a replica instance.

```yaml
server:
  redis:
    replica:
      address: 10.10.10.10:6379
```

#### server::redis::replica::addresses
_New in version 1.4.10_<br/>
_Default: []

This is a list of one or more sockets for a Redis connection to a replica instance.

```yaml
server:
  redis:
    replica:
      addresses:
        - 10.10.10.10:6379
```

#### server::redis::sentinels

NAuthilus can connect to Redis sentinels. The following options define such a setup.

#### server::redis::sentinels::master
_Default: ""_

This is the name of the sentinel master.

```yaml
server:
  redis:
    sentinels:
      master: mymaster
```

#### server::redis::sentinels::addresses
_Default: empty list_

This is a list of Redis sentienl sockets.

```yaml
server:
  redis:
    sentinels:
      addresses:
        - 127.0.0.1:26379
        - 127.0.0.1:26378
        - 127.0.0.1:26377
```

:::note
At least one sentinel address is required.
:::

Here is an example for K8s redis-operator sentinel, if you run Nauthilus in Kubernetes on-premise and a NodePort service:

```yaml
server:
  redis:
    sentinels:
      master: myMaster
      addresses:
        - redis-sentinel-sentinel-0.redis-sentinel-sentinel-headless.ot-operators.svc.cluster.local:26379
        - redis-sentinel-sentinel-1.redis-sentinel-sentinel-headless.ot-operators.svc.cluster.local:26379
        - redis-sentinel-sentinel-2.redis-sentinel-sentinel-headless.ot-operators.svc.cluster.local:26379
```

#### server::redis::sentinels::username and server::reids::sentinels::password
_Default: ""_

Both of these parameters are optional settings, if your Redis sentinels require authentication.

```yaml
server:
  redis:
    sentinels:
      username: some_user
      password: some_secret
```

#### server::redis::cluster

If NAuthilus should be connected to a Redis cluster, the following settings can be set to do so.

#### server::redis::cluster::addresses
_Default: empty list_

This is a list of one or more Redis sockets pointing to a Redis cluster.

```yaml
server:
  redis:
    cluster:
      addresses:
      - 127.0.0.1:6379
      - 127.0.0.1:6378
      - 127.0.0.1:6377
```

#### server::redis::cluster::username and server::redis::cluster::password
_Default: ""_

These parameters are optional settings for authentication with the Redis cluster.

```yaml
server:
  redis:
    cluster:
      username: some_user
      password: some_secret
```

#### server::redis::cluster::route_by_latency
_Default: false_

When enabled, commands are routed to the Redis node with the lowest latency.

```yaml
server:
  redis:
    cluster:
      route_by_latency: true
```

#### server::redis::cluster::route_randomly
_Default: false_

When enabled, commands are routed randomly across Redis nodes.

```yaml
server:
  redis:
    cluster:
      route_randomly: true
```

#### server::redis::cluster::route_reads_to_replicas
_New in version 1.7.11_  
_Default: false_

When enabled, read commands are routed to Redis replica nodes, which can improve performance by distributing the read load across the cluster.

```yaml
server:
  redis:
    cluster:
      route_reads_to_replicas: true
```

#### server::redis::cluster::read_only
_Default: false_  
_Deprecated: Use route_reads_to_replicas instead_

When enabled, read commands are routed to Redis replica nodes. This parameter has been renamed to `route_reads_to_replicas` to better reflect its actual functionality.

```yaml
server:
  redis:
    cluster:
      read_only: true  # Deprecated
```

#### server::redis::cluster::max_redirects
_Default: 3_

This setting defines the maximum number of redirects to follow when executing Redis commands.

```yaml
server:
  redis:
    cluster:
      max_redirects: 5
```

#### server::redis::cluster::read_timeout and server::redis::cluster::write_timeout
_Default: 0 (no timeout)_

These settings define the timeout duration for read and write operations to the Redis cluster.

Units should add a time unit like:
* s - seconds
* m - minutes
* h - hours

```yaml
server:
  redis:
    cluster:
      read_timeout: 3s
      write_timeout: 3s
```

## Master User Configuration

### server::master_user

This object defines settings related to a so-called **master user**

#### server::master_user::enabled
_Default: false_

If this flag is turned on (true), Nauthilus honors login usernames that are master users. A master user looks something like this:

```
user@domain.tld*masteruser
```

As you can see, the master user is separated from the real login name by a "*" character followed by the name of a master user. If NAuthilus
detecs such a user, it will do authentication against the master user.

```yaml
server:
  master_user:
    enabled: true
```

#### server::master_user::delimiter
_Default: "*"_

This is the character that splits the real username from the master user.

```yaml
server:
  master_user:
    delimiter: "*"
```

## Frontend Configuration

### server::frontend

Nauthilus specific settings for the frontend (OIDC)

#### server::frontend::enabled
_Default: false_

Turn on the frontend.

```yaml
server:
  frontend:
    enabled: true
```

#### server::frontend::csrf_secret
_Default: ""_<br/>
_required_

This key is required whenever CSRF (cross-site-request-forgery) attacks must be prevented. This is currently used, if
Nauthilus is configured to communicate with Ory Hydra. The login, consent and logout pages are protected with a CSRF
token. This value defines the secret used for that token.

This value **MUST** be 32 bytes long and can contain alphanumeric characters and symbols, but no spaces.

#### server::frontend::cookie_store_auth_key and server::frontend::cookie_store_encryption_key
_Default: ""_<br/>
_required_

These keys are used to encrypt and decrypt session cookies.

The cookie_store_auth_key **MUST** be 32 bytes long and can contain alphanumeric characters and symbols, but no spaces.

The cookie_store_encryption_key **MUST** be 16, 24, or 32 bytes long and can contain alphanumeric characters and symbols, but no spaces.

## Prometheus Timer Configuration

### server::prometheus_timer

Turn on several Prometheus labels, which are timers for certain aspects of the application.

#### server::prometheus\timer::enabled

Turn on the prometheus timers.

```yaml
server:
  prometheus_timer:
    enabled: true
```

#### server::prometheus\timer::labels

The following labels can be turned on:

| Label name   | Description                                              |
|--------------|----------------------------------------------------------|
| account      | Mode "list-accounts" timer                               |
| action       | Timers for Lua actions                                   |
| backend      | Timers for backends                                      |
| brute\_force | Timers for the brute force functions                     |
| feature      | Timers for all features                                  |
| filter       | Timers for Lua filters                                   |
| request      | Timer for the entire client request without post actions |
| store\_totp  | Timer for storing a new TOTP secret to a backend         |
| post\_action | Timers for Lua post actions                              |
| dns          | Timers for DNS queries                                   |

Example:

```yaml
server:
  prometheus_timer:
    enabled: true
    labels:
      - request
      - dns
```

## Compression Configuration

### server::compression

This object defines settings related to HTTP response compression.

Note: As of version 1.9.2, MIME types for compression are deprecated and no longer used. Compression decisions are automatically based on negotiation and thresholds (see options below).
#### server::compression::enabled
_Default: false_

This flag turns on (true) HTTP response compression.

```yaml
server:
  compression:
    enabled: true
```

#### server::compression::level
_Default: 5_

Deprecated: As of v1.9.9 use server::compression::level_gzip instead. The old key remains supported for backward compatibility and will be removed in a future release.

```yaml
# Deprecated — prefer level_gzip
server:
  compression:
    level: 7
```

#### server::compression::level_gzip (since v1.9.9)
_Default: 5_

Defines the gzip compression level (1-9, where 1 is fastest and 9 is best compression). This replaces the old level key to mirror the style of level_zstd.

```yaml
server:
  compression:
    level_gzip: 7
```

#### server::compression::content_types
_Default: deprecated since v1.9.2_

Deprecated: As of version 1.9.2 MIME/content types are no longer used to decide compression and this option has no effect. The server now determines compression automatically based on request/response negotiation and size thresholds.

If present in your configuration, this key will be ignored from v1.9.2 onwards and can be safely removed.

```yaml
# Prior to v1.9.2:
# server:
#   compression:
#     content_types:
#       - text/html
#       - application/json

# Since v1.9.2 this option is ignored and should be removed.
```

#### server::compression::min_length
_Default: 1024_

This setting defines the minimum content length required for compression.

```yaml
server:
  compression:
    min_length: 2048
```

#### server::compression::algorithms (since v1.9.8)
_Default: ["zstd", "gzip"]_

Defines the enabled compression algorithms in order of preference. The router applies only one response compression middleware at a time based on this list. If the client supports Zstandard (zstd) and it is listed first, zstd will be used; otherwise it falls back to gzip when available. Since v1.9.9, Brotli (br) can also be selected and typically offers excellent ratios for text assets.

Valid values include: "br" (Brotli), "zstd" (or aliases "zst", "zstandard") and "gzip".

```yaml
server:
  compression:
    enabled: true
    algorithms: ["br", "zstd", "gzip"]
```

Notes:
- Only one algorithm is applied for a given response.
- If the list is empty or no known algorithm is listed, zstd is used by default.

#### server::compression::level_zstd (since v1.9.8)
_Default: 0 (DefaultCompression)_

Configures the Zstandard compression level mapping used by the built-in zstd middleware:
- 0 = DefaultCompression
- 1 = BestSpeed
- 2 = BetterCompression
- 3 = BestCompression

```yaml
server:
  compression:
    enabled: true
    algorithms: ["br", "zstd", "gzip"]
    level_zstd: 2 # BetterCompression
```

#### server::compression::level_brotli (since v1.9.9)
_Default: 0 (DefaultCompression)_

Configures the Brotli compression level mapping used by the built-in Brotli middleware:
- 0 = DefaultCompression
- 1 = BestSpeed
- 2 = BetterCompression
- 3 = BestCompression

```yaml
server:
  compression:
    enabled: true
    algorithms: ["br", "zstd", "gzip"]
    level_brotli: 2 # BetterCompression
```

Implementation details:
- Zstandard is implemented via klauspost/compress.
- Brotli is implemented via andybalholm/brotli.
- For gzip, the new level_gzip (1-9) supersedes the deprecated level key (still accepted for backward compatibility).

Request decompression (since v1.9.8; extended in v1.9.9):
- Incoming requests with Content-Encoding: gzip are decompressed when compression is enabled.
- Incoming requests with Content-Encoding: zstd/zst/zstandard are decompressed when compression is enabled.
- Incoming requests with Content-Encoding: br (Brotli) are decompressed when compression is enabled (since v1.9.9).

## Keep Alive Configuration

### server::keep_alive

This object defines settings related to HTTP connection keep-alive optimization.

#### server::keep_alive::enabled
_Default: false_

This flag turns on (true) HTTP keep-alive optimization.

```yaml
server:
  keep_alive:
    enabled: true
```

#### server::keep_alive::timeout
_Default: 30s_

This setting defines the keep-alive timeout duration.

```yaml
server:
  keep_alive:
    timeout: 60s
```

#### server::keep_alive::max_idle_connections
_Default: 100_

This setting defines the maximum number of idle connections.

```yaml
server:
  keep_alive:
    max_idle_connections: 200
```

#### server::keep_alive::max_idle_connections_per_host
_Default: 10_

This setting defines the maximum number of idle connections per host.

```yaml
server:
  keep_alive:
    max_idle_connections_per_host: 20
```
