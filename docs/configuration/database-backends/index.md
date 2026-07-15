---
title: Database Backends
description: Overview of authentication backends in config v2
keywords: [Configuration, Database, Backends]
sidebar_position: 1
---

# Database Backends

Backends validate credentials. In config v2 they live under `auth.backends`.

## Main Structure

```yaml
auth:
  backends:
    order:
      - cache
      - ldap
      - lua
      - plugin(customer_sql.passdb)
```

Important:

- `cache` should remain first
- LDAP config lives under `auth.backends.ldap`
- Lua backend config lives under `auth.backends.lua.backend`
- remote authority backend config lives under `auth.backends.remote`
- native Go backends are registered by a configured module and selected as `plugin(<module>.<backend>)`
- Lua policy scripts live under `auth.policy.attribute_sources.lua` and `auth.policy.obligation_targets.lua`; hooks live under `auth.controls.lua.hooks`

## Topics

- [Protocols](protocols.md)
- [LDAP](ldap.md)
- [Lua](lua.md)
- [Remote Authority Backend](remote.md)
- [Macros](macros.md)
- [Cache Namespaces](cache-namespaces.md)
- [Encrypted Passwords](encrypted-passwords.md)
- [Native Go Plugin Configuration](../native-go-plugins.md)
- [Native Go Backend API](../../developer/go-plugins/api-reference/backends.md)

## Named Backends

Named LDAP pools and named Lua backends are still supported through the order list:

```yaml
auth:
  backends:
    order:
      - cache
      - ldap(pool1)
      - lua(reporting)
      - remote(authority)
      - plugin(customer_sql.passdb)
```

- `ldap(pool1)` refers to `auth.backends.ldap.pools.pool1`
- `lua(reporting)` refers to `auth.backends.lua.backend.named_backends.reporting`
- `remote(authority)` refers to `auth.backends.remote.authority`
- `plugin(customer_sql.passdb)` refers to backend `passdb` registered by native module `customer_sql`

Remote backends are intended for edge instances that authenticate and resolve identity through a private Nauthilus authority over gRPC. A strict edge configuration usually has `auth.backends.order: [remote]` and no local LDAP or Lua backend credentials.

Native plugin selectors must be fully qualified and refer to a component that was registered successfully at startup. The base backend handles password verification and account listing; the same component may implement independent typed TOTP, recovery-code, WebAuthn, and public-MFA-state interfaces. A missing ordered native backend is a configuration/startup error rather than an implicit fallback.
