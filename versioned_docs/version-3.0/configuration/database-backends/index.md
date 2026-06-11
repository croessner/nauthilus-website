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
```

Important:

- `cache` should remain first
- LDAP config lives under `auth.backends.ldap`
- Lua backend config lives under `auth.backends.lua.backend`
- remote authority backend config lives under `auth.backends.remote`
- Lua policy scripts live under `auth.policy.attribute_sources.lua` and `auth.policy.obligation_targets.lua`; hooks live under `auth.controls.lua.hooks`

## Topics

- [Protocols](protocols.md)
- [LDAP](ldap.md)
- [Lua](lua.md)
- [Remote Authority Backend](remote.md)
- [Macros](macros.md)
- [Cache Namespaces](cache-namespaces.md)
- [Encrypted Passwords](encrypted-passwords.md)

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
```

- `ldap(pool1)` refers to `auth.backends.ldap.pools.pool1`
- `lua(reporting)` refers to `auth.backends.lua.backend.named_backends.reporting`
- `remote(authority)` refers to `auth.backends.remote.authority`

Remote backends are intended for edge instances that authenticate and resolve identity through a private Nauthilus authority over gRPC. A strict edge configuration usually has `auth.backends.order: [remote]` and no local LDAP or Lua backend credentials.
