---
title: LDAP Backend
description: LDAP backend configuration in config v2
keywords: [Configuration, LDAP, Backend]
sidebar_position: 6
---

# LDAP Backend

The LDAP backend now lives under `auth.backends.ldap`.

## Main Structure

```yaml
auth:
  backends:
    ldap:
      default: {}
      pools: {}
      search: []
```

- `default`: the main LDAP pool
- `pools`: named additional pools
- `search`: protocol-specific search definitions

## Default Pool Example

```yaml
auth:
  backends:
    ldap:
      default:
        number_of_workers: 10
        lookup_pool_size: 8
        lookup_idle_pool_size: 2
        auth_pool_size: 8
        auth_idle_pool_size: 2
        server_uri:
          - "ldap://ldap1.example.com:389"
          - "ldap://ldap2.example.com:389"
        bind_dn: "cn=admin,dc=example,dc=com"
        bind_pw: "secret"
        starttls: true
        tls_skip_verify: false
```

## Named Pools

```yaml
auth:
  backends:
    ldap:
      pools:
        pool1:
          lookup_pool_size: 5
          auth_pool_size: 5
          server_uri:
            - "ldap://pool1.example.com:389"
        pool2:
          lookup_pool_size: 3
          auth_pool_size: 3
          server_uri:
            - "ldap://pool2.example.com:389"
```

Reference them from backend order or from search entries.

## Search Example

```yaml
auth:
  backends:
    ldap:
      search:
        - protocol:
            - imap
            - smtp
            - default
          cache_name: "mail"
          pool_name: "pool1"
          base_dn: "ou=people,dc=example,dc=com"
          filter:
            user: "(&(objectClass=inetOrgPerson)(uid=%L{user}))"
          mapping:
            account_field: "uid"
            display_name_field: "cn"
          attribute:
            - "uid"
            - "cn"
            - "mail"
            - "userPassword"
```

## Groups Resolution

Group resolution remains part of search entries and is especially useful for `oidc` and `saml` protocols.

```yaml
auth:
  backends:
    ldap:
      search:
        - protocol:
            - oidc
            - saml
          groups:
            strategy: "search"
            base_dn: "ou=groups,dc=example,dc=com"
            scope: "sub"
            filter: "(&(objectClass=groupOfNames)(member=%{user_dn}))"
            name_attribute: "cn"
            recursive: false
            max_depth: 1
```

## Notes

- use `starttls`, not `tls` for LDAP STARTTLS
- `lookup_pool_only` is the current pool-only-style switch on the default/named pool object
- old top-level `ldap.*` paths are no longer the documented surface
