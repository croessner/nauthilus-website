---
title: Database Backends
description: Overview of database backends configuration in Nauthilus
keywords: [Configuration, Database, Backends]
sidebar_position: 1
---

# Database Backends

Nauthilus needs database backends to validate user credentials. Besides the **cache** backend, which is special, 
Nauthilus can use LDAP and Lua based backends. The current implementation is limited to use one LDAP and one Lua
backend at the same time.

If you define an LDAP and a Lua backend, both will be queried in the order you have defined in **server::backends**

:::warning
The "idea" of a backend is to check user credentials!

Do not mix password verification and policy tasks in the backends!

If you want to enforce policies, make use of Lua filters, because they never influence the brute-force-logic nor is it cached on Redis.
If you combine both aspects in the backends, you will risk of learning correct passwords as wrong!
:::

## Database Backend Topics

The database backends configuration is divided into the following topics:

- [Protocols](protocols.md) - Protocol-specific settings for backends
- [Macros](macros.md) - Macro definitions for queries
- [Cache Namespaces](cache-namespaces.md) - Redis cache namespace configuration
- [Encrypted Passwords](encrypted-passwords.md) - Supported password encryption formats
- [LDAP](ldap.md) - LDAP backend configuration
- [Lua](lua.md) - Lua backend configuration

## Configuration in server::backends

To enable database backends, you need to configure them in the `server::backends` section of your configuration file:

```yaml
server:
  backends:
    - cache
    - ldap
    - lua
```

The order of backends matters! The cache backend should always be the first backend.

For Multi-LDAP and Multi Lua-backends, you can use a special syntax to specify which pool or backend to use:

```yaml
server:
  backends:
    - cache
    - ldap(pool1)  # Use the LDAP pool named "pool1"
    - lua(backend2)  # Use the Lua backend named "backend2"
```

This syntax allows you to use multiple LDAP pools or Lua backends with different configurations. The pool or backend name must match a name defined in the `optional_ldap_pools` or `optional_lua_backends` sections.