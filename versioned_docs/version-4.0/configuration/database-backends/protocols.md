---
title: Protocols
description: Protocol-specific backend selection in config v2
keywords: [Configuration, Protocols, Backends]
sidebar_position: 2
---

# Protocols

Protocol selection still works the same operationally, but the config-v2 paths changed.

Protocol-specific search definitions now live in:

- `auth.backends.ldap.search`
- `auth.backends.lua.backend.search`

The incoming protocol is taken from the configured request header name under `auth.request.headers.protocol`.

## LDAP Example

```yaml
auth:
  backends:
    ldap:
      search:
        - protocol:
            - imap
            - pop3
            - default
          cache_name: "dovecot"
          base_dn: "ou=people,dc=example,dc=com"
          filter:
            user: "(&(objectClass=inetOrgPerson)(uid=%L{user}))"
          mapping:
            account_field: "uid"
          attribute:
            - "uid"
            - "userPassword"
```

## Lua Example

```yaml
auth:
  backends:
    lua:
      backend:
        search:
          - protocol:
              - smtp
              - submission
            cache_name: "submission"
          - protocol:
              - oidc
              - saml
            cache_name: "identity"
```

Special protocols such as `oidc`, `saml`, `http`, `internal-basic-auth`, and `account-provider` remain valid where the backend supports them.
