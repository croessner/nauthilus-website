---
title: Cache Namespaces
description: Redis cache namespace configuration in config v2
keywords: [Configuration, Cache, Namespaces, Redis]
sidebar_position: 4
---

# Cache Namespaces

Each backend search block can define a Redis cache namespace through `cache_name`.

Current locations:

- `auth.backends.ldap.search[].cache_name`
- `auth.backends.lua.backend.search[].cache_name`

## LDAP Example

```yaml
auth:
  backends:
    ldap:
      search:
        - protocol:
            - imap
            - pop3
            - lmtp
          cache_name: "dovecot"
        - protocol:
            - smtp
            - submission
          cache_name: "submission"
```

## Lua Example

```yaml
auth:
  backends:
    lua:
      backend:
        search:
          - protocol:
              - oidc
              - saml
            cache_name: "identity"
```

TTL behavior comes from:

- `storage.redis.positive_cache_ttl` for the positive password cache (UCP)
- `storage.redis.negative_cache_ttl`
- `storage.redis.identity_cache.ttl` for the LDAP identity lookup cache (UCI), when
  `storage.redis.identity_cache.enabled` is `true`

## Redis Keys

| Cache | Key |
|---|---|
| Positive password cache (UCP) | `<prefix>UCP:<cache_name>:<account>` |
| Identity lookup cache (UCI) | `<prefix>UCI:<cache_name>:<username>` |
| Identity cache generation | `<prefix>UCI:epoch` (persistent) |
| Native backend plugin password cache | `<prefix>UCP:` followed by an internal `\x00plugin.<module>.<backend>:<account>` suffix |

`<prefix>` is `storage.redis.prefix`. The Redis key identifies the account and cache namespace; the password digest of
a UCP entry is stored in the encrypted value, never in the key. Native plugin namespaces start with a NUL byte, which a
printable-ASCII `cache_name` cannot contain, so they never collide with an operator-configured cache name.

The user-cache flush API removes the UCP entries of all configured namespaces, including native plugin namespaces, and
rotates the identity cache generation. See [Identity Lookup Cache](../server-configuration.md#identity-lookup-cache).

Cache lookups of the typed authentication providers stay within their backend family: `authn/builtin/ldap_backend` and
`authn/builtin/lua_backend` keep a configured cache-first `auth.backends.order` and accept only entries of their own
backend and configured instances, and `authn/builtin/plugin_backend_order` only reads the namespaces of opted-in plugin
backends.
