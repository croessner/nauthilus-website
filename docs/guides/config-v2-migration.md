---
title: Config v2 Migration
description: Hard migration from the legacy monolithic layout to the current config-v2 structure
keywords: [Configuration, Migration, v2]
sidebar_position: 6
---

# Config v2 Migration

This guide describes the migration from the legacy monolithic configuration layout to the current `config v2` structure.

The migration is intentionally breaking:

- legacy root nodes are removed
- legacy aliases are removed where the v2 design requires a hard semantic cleanup
- existing configuration files must be rewritten to the new root structure

## Migration Goals

Config v2 reorganizes the file around human-facing concerns instead of implementation history:

- `runtime`: process, inbound HTTP and gRPC servers, shared timeouts, outbound clients
- `observability`: logs, profiling, tracing, metrics
- `storage`: Redis and related cache/storage behavior
- `auth`: request model, backchannel auth, pipeline behavior, backends, controls, services
- `identity`: frontend, MFA, OIDC, SAML, remember-me/session behavior

## Hard Breaking Changes

The following old roots are not part of the current surface anymore:

- `server`
- `ldap`
- `lua`
- `idp`
- `realtime_blackhole_lists`
- `relay_domains`
- `brute_force`
- `backend_server_monitoring`
- `cleartext_networks`

The following old names are replaced by canonical v2 names:

- `backend_server_monitoring` -> `auth.services.backend_health_checks`
- `default_http_request_header` -> `auth.request.headers`
- `lua.custom_hooks` -> `auth.controls.lua.hooks`
- `server.redis.primary` -> `storage.redis.primary`

Removed legacy aliases include:

- `soft_allowlist`
- `soft_whitelist`
- `storage.redis.master`
- flat SAML SLO aliases such as `identity.saml.slo_enabled`

## Root Mapping

| Legacy root | v2 location |
|---|---|
| `server` | split across `runtime`, `observability`, `storage`, `auth`, `identity` |
| `ldap` | `auth.backends.ldap` |
| `lua` | split across `auth.backends.lua.backend` and `auth.controls.lua` |
| `idp` | `identity` |
| `realtime_blackhole_lists` | `auth.controls.rbl` |
| `relay_domains` | `auth.controls.relay_domains` |
| `brute_force` | `auth.controls.brute_force` |
| `backend_server_monitoring` | `auth.services.backend_health_checks` |
| `cleartext_networks` | `auth.controls.tls_encryption.allow_cleartext_networks` |

## Common Path Migrations

| Legacy path | v2 path |
|---|---|
| `server.address` | `runtime.servers.http.address` |
| `server.tls` | `runtime.servers.http.tls` |
| `server.middlewares` | `runtime.servers.http.middlewares` |
| `server.timeouts` | `runtime.timeouts` |
| `server.http_client` | `runtime.clients.http` |
| `server.dns` | `runtime.clients.dns` |
| `server.log` | `observability.log` |
| `server.insights.enable_pprof` | `observability.profiles.pprof.enabled` |
| `server.insights.enable_block_profile` | `observability.profiles.block.enabled` |
| `server.insights.tracing` | `observability.tracing` |
| `server.prometheus_timer` | `observability.metrics.prometheus_timer` |
| `server.redis` | `storage.redis` |
| `server.default_http_request_header` | `auth.request.headers` |
| `server.basic_auth` | `auth.backchannel.basic_auth` |
| `server.oidc_auth` | `auth.backchannel.oidc_bearer` |
| `server.backends` | `auth.backends.order` |
| `server.brute_force_protocols` | `auth.controls.brute_force.protocols` |
| `brute_force.learning` | `auth.controls.brute_force.learning` |
| `ldap.config` | `auth.backends.ldap.default` |
| `ldap.pools` | `auth.backends.ldap.pools` |
| `ldap.search` | `auth.backends.ldap.search` |
| `lua.config` | `auth.backends.lua.backend.default` |
| `lua.optional_backends` | `auth.backends.lua.backend.named_backends` |
| `lua.search` | `auth.backends.lua.backend.search` |
| `lua.actions` | `auth.controls.lua.actions` |
| `lua.controls` | `auth.controls.lua.controls` |
| `lua.filters` | `auth.controls.lua.filters` |
| `lua.custom_hooks` | `auth.controls.lua.hooks` |
| `idp.remember_me_ttl` | `identity.session.remember_me_ttl` |
| `server.frontend` | `identity.frontend` |
| `server.frontend.totp_issuer` | `identity.mfa.totp.issuer` |
| `server.frontend.totp_skew` | `identity.mfa.totp.skew` |
| `idp.webauthn` | `identity.mfa.webauthn` |
| `idp.oidc` | `identity.oidc` |
| `idp.saml2` | `identity.saml` |

## Example

Legacy:

```yaml
server:
  address: "[::]:9443"
  log:
    level: "info"
  redis:
    primary:
      address: "redis:6379"
  backends:
    - cache
    - ldap
  brute_force_protocols:
    - imap

ldap:
  config:
    server_uri:
      - "ldap://ldap:389"

brute_force:
  protocols:
    - imap
  learning:
    - brute_force
```

Current:

```yaml
runtime:
  servers:
    http:
      address: "[::]:9443"

observability:
  log:
    level: "info"

storage:
  redis:
    primary:
      address: "redis:6379"

auth:
  backends:
    order:
      - cache
      - ldap
    ldap:
      default:
        server_uri:
          - "ldap://ldap:389"
  controls:
    enabled:
      - brute_force
    brute_force:
      protocols:
        - imap
      learning:
        - brute_force
```

## Recommended Migration Order

1. move runtime, log, and Redis settings
2. move backend order and backend definitions
3. move controls and services
4. move frontend, MFA, OIDC, and SAML to `identity`
5. validate with `--config-check`
6. compare with `-n`

## Migration Helper Script

Nauthilus now ships a best-effort converter for legacy monolithic YAML files:

```bash
python3 scripts/convert-config-v1-to-v2.py legacy-nauthilus.yml --output nauthilus-v2.yml
```

Useful options:

- `--report <path>`: write a migration report with warnings and dropped paths
- `--validate`: run `nauthilus --config-check` against the converted output
- `--dry-run --stdout`: print the converted YAML without writing files

The helper currently also covers:

- optional LDAP pools
- optional Lua backends
- legacy `server.features` and `lua.features` aliases
- legacy dotted keys such as `server.oidc_auth.enabled`
- top-level `x-*` extension roots, which are preserved as-is
- best-effort `x-*` anchor reuse in the generated YAML when equivalent subtrees still exist
- legacy mapping order where the converted structure still allows it
- legacy `server.address`, `server.tls`, and HTTP runtime settings into `runtime.servers.http`
- legacy `server.timeouts` into shared `runtime.timeouts`

Example:

```bash
python3 scripts/convert-config-v1-to-v2.py \
  legacy-nauthilus.yml \
  --output nauthilus-v2.yml \
  --report migration-report.txt \
  --validate
```

Important limits:

- current scope is single-file legacy YAML to single-file config-v2 YAML
- the helper migrates legacy v1 roots; it does not rewrite already-v2 `runtime.listen` or `runtime.http` files
- include tree refactoring is out of scope
- unsupported legacy paths are reported for manual review instead of being silently guessed
- comment preservation is out of scope

Treat the script as a migration accelerator, not as a substitute for final review.

## Operational Validation

Use these commands during migration:

```bash
nauthilus --config /etc/nauthilus/nauthilus.yml --config-check
```

```bash
nauthilus -n --config /etc/nauthilus/nauthilus.yml
```

```bash
nauthilus -d
```

This is the fastest way to prove that your migrated file is aligned with the current schema and defaults.
