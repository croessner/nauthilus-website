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

- `storage.redis.positive_cache_ttl`
- `storage.redis.negative_cache_ttl`
