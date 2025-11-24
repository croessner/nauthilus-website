---
title: Cache Namespaces
description: Redis cache namespace configuration in Nauthilus
keywords: [Configuration, Cache, Namespaces, Redis]
sidebar_position: 4
---

# Cache Namespaces

Each protocol block can define a Redis cache namespace. That is especially useful, if you require different results
for different protocols. By not using a namespace, a default namspace "**\_\_default\_\_**" is used.

You can apply the same namespaces to different protocols as long as the requested results carry the same information. If
you use the Dovecot IMAP/POP3 server i.e. with the submission proxy feature, Dovecot requires the same information for *
*imap** and **submission**, but your protocol sections may serve different queries/filters. But the list of returned
keys (not values) will be the same.

## Purpose of Cache Namespaces

Cache namespaces serve several important purposes in Nauthilus:

1. **Protocol-Specific Caching**: Different protocols may require different user attributes or authentication rules. Namespaces allow you to cache protocol-specific information separately.

2. **Performance Optimization**: By grouping similar protocols under the same namespace, you can reduce redundant cache entries and optimize Redis memory usage.

3. **Cache Isolation**: Namespaces provide isolation between different types of cached data, preventing conflicts and making cache management easier.

## Configuration Examples

### LDAP Backend Example

```yaml
ldap:
  search:
    - protocol:
        - imap
        - pop3
        - lmtp
      cache_name: dovecot
      # ...

    - protocol:
        - smtp
        - submission
      cache_name: submission
      # ...

    - protocol: ory-hydra
      cache_name: oidc
      # ...
```

### Lua Backend Example

```yaml
lua:
  search:
    - protocol:
        - imap
        - pop3
        - lmtp
      cache_name: dovecot

    - protocol:
        - smtp
        - submission
      cache_name: submission

    - protocol: ory-hydra
      cache_name: oidc
```

## Cache Keys and TTL

Cache entries are stored in Redis with keys that include the namespace. The TTL (Time To Live) for these entries is controlled by the Redis configuration:

```yaml
server:
  redis:
    positive_cache_ttl: 3600s  # TTL for successful authentications
    negative_cache_ttl: 7200s  # TTL for failed authentications
```

The negative cache TTL is typically longer as it's also used in the brute-force logic to detect users that try to log in with a repeating wrong password.