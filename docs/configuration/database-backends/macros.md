---
title: Macros
description: Macro definitions for backend queries in config v2
keywords: [Configuration, Macros, Queries]
sidebar_position: 3
---

# Macros

Backend queries can use Dovecot-style macros such as `%L{user}`.

## Example

```yaml
auth:
  backends:
    ldap:
      search:
        - protocol:
            - imap
          base_dn: "ou=people,dc=example,dc=com"
          filter:
            user: |
              (&
                (objectClass=inetOrgPerson)
                (uid=%L{user})
              )
```

The macro `%L{user}` inserts the lowercase version of the supplied username.
