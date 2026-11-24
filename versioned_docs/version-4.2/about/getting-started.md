---
title: Getting started
description: Practical first steps with the current Nauthilus configuration model
keywords: [Quickstart, Setup, Configuration, Authentication]
sidebar_position: 3
---

# Getting Started with Nauthilus

This guide introduces the current Nauthilus configuration model and gives you a minimal working starting point.

Nauthilus now uses five human-facing root sections:

- `runtime`: inbound HTTP and gRPC servers, shared timeouts, outbound clients, process settings
- `observability`: logs, profiling, tracing, metrics
- `storage`: Redis
- `auth`: request headers, backchannel auth, authentication pipeline, backends, controls, services
- `identity`: frontend, MFA, OIDC, SAML, remember-me/session behavior

## Prerequisites

Before deploying Nauthilus, ensure you have:

- Redis
- at least one authentication backend (LDAP or Lua)
- a YAML configuration file
- TLS and reverse-proxy planning if you expose browser-facing IdP endpoints

## Minimal Configuration

Create a minimal `nauthilus.yml`:

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

auth:
  backends:
    order:
      - cache
      - ldap
    ldap:
      default:
        server_uri:
          - "ldap://ldap-server:389"
        bind_dn: "cn=admin,dc=example,dc=com"
        bind_pw: "password"
      search:
        - protocol:
            - "imap"
            - "smtp"
            - "default"
          cache_name: "mail"
          base_dn: "ou=people,dc=example,dc=com"
          filter:
            user: "(&(objectClass=inetOrgPerson)(uid=%L{user}))"
          mapping:
            account_field: "uid"
          attribute:
            - "uid"
            - "userPassword"
```

That is enough to boot a basic LDAP-backed instance.

## Mental Model

The most important split is this:

- `auth.backends.*` decides how credentials are verified.
- `auth.controls.*` applies policy before or around verification.
- `auth.services.*` runs supporting background services such as backend health checks.
- `identity.*` configures the browser-facing IdP surface.

This avoids the old overloading where unrelated runtime, Redis, frontend, and policy settings lived under the same root.

## Command-Line Flags

The server supports these relevant flags:

- `--config <path>`: use a specific configuration file
- `--config-format <yaml|json|toml|...>`: set the input format
- `--config-check`: validate configuration and exit
- `-d`: print canonical defaults (`postconf`/`doveconf` style)
- `-n`: print only values that differ from defaults
- `-P`: print sensitive values in dump output; without `-P`, sensitive values are redacted
- `--version`: print version and exit

Examples:

```bash
nauthilus --config /etc/nauthilus/nauthilus.yml --config-check
nauthilus -d
nauthilus -n --config /etc/nauthilus/nauthilus.yml
nauthilus -n -P --config /etc/nauthilus/nauthilus.yml
```

## Configuration Validation and Dumps

Configuration errors now use canonical config paths. That means the messages refer to the same names you see in the YAML file, for example:

- `storage.redis.primary.address`
- `auth.request.headers.username`
- `identity.oidc.tokens.token_endpoint_allow_get`

This also means old root names and aliases are not accepted anymore. If your file still contains `server`, `ldap`, `lua`, `idp`, `realtime_blackhole_lists`, or `backend_server_monitoring`, rewrite it to the v2 structure.

## Redis Topologies

Redis remains essential. The current paths are:

- standalone / primary: `storage.redis.primary`
- replicas: `storage.redis.replica`
- sentinels: `storage.redis.sentinels`
- cluster: `storage.redis.cluster`

Examples:

```yaml
storage:
  redis:
    primary:
      address: "redis:6379"
```

```yaml
storage:
  redis:
    primary:
      address: "redis-primary:6379"
    replica:
      addresses:
        - "redis-replica-1:6379"
        - "redis-replica-2:6379"
```

```yaml
storage:
  redis:
    sentinels:
      master: "mymaster"
      addresses:
        - "sentinel-1:26379"
        - "sentinel-2:26379"
        - "sentinel-3:26379"
```

## Enabling Controls

Controls are opt-in. A control is active only when it is listed in `auth.controls.enabled`.

Example:

```yaml
auth:
  controls:
    enabled:
      - tls_encryption
      - rbl
      - relay_domains
      - brute_force
```

Then configure the matching blocks under `auth.controls.*`.

## Backends

The backend order lives in `auth.backends.order`:

```yaml
auth:
  backends:
    order:
      - cache
      - ldap
      - lua
      - ldap(pool1)
      - lua(reporting)
```

- `cache` should stay first.
- `ldap(pool1)` refers to `auth.backends.ldap.pools.pool1`.
- `lua(reporting)` refers to `auth.backends.lua.backend.named_backends.reporting`.

## Identity Provider

The native IdP now lives fully below `identity`:

```yaml
identity:
  session:
    remember_me_ttl: 720h
  frontend:
    enabled: true
    links:
      privacy_policy_url: "https://example.com/privacy"
      terms_of_service_url: "https://example.com/tos"
  mfa:
    webauthn:
      rp_display_name: "Nauthilus"
      rp_id: "idp.example.com"
      rp_origins:
        - "https://idp.example.com"
  oidc:
    enabled: true
    issuer: "https://idp.example.com"
  saml:
    enabled: true
    entity_id: "https://idp.example.com/saml"
```

## Next Steps

- [Configuration Overview](../configuration/index.md)
- [Runtime, Observability, and Storage](/docs/configuration/server-configuration)
- [Database Backends](/docs/configuration/database-backends)
- [Identity](/docs/configuration/idp)
- [Full Configuration Example](/docs/configuration/full-example)
- [Config v2 Migration Guide](../guides/config-v2-migration.md)
- [Hands-on Tutorials](../guides/tutorials.md)
- [Tutorial: OpenLDAP](../guides/tutorial-openldap.md)
- [Tutorial: MariaDB + Lua](../guides/tutorial-mariadb-lua.md)
- [Tutorial: Mail Infrastructure](../guides/tutorial-mail-infrastructure.md)
