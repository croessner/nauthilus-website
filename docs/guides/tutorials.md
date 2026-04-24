---
title: Hands-on tutorials
description: Practical tutorials for learning Nauthilus with OpenLDAP, MariaDB, Lua, Dovecot, Postfix, and pfxhttp
keywords: [Tutorial, OpenLDAP, MariaDB, Lua, Mail, Dovecot, Postfix, pfxhttp]
sidebar_position: 10
---

# Hands-on Tutorials

These tutorials are the practical entry point into Nauthilus. They are written for new users who want to run something concrete before reading the full configuration reference.

Each tutorial starts with a small, working Docker Compose stack and then explains the relevant configuration files directly in the page. You do not need to follow links into a temporary source tree to understand what is being built.

## Version Note

The examples use:

```text
ghcr.io/croessner/nauthilus:v3.0.0
```

This is intentional. The examples describe the current configuration structure and the target image tag for the v3 line.

## Recommended Order

1. [OpenLDAP Tutorial](tutorial-openldap.md)
2. [MariaDB + Lua Tutorial](tutorial-mariadb-lua.md)
3. [Mail Infrastructure Tutorial](tutorial-mail-infrastructure.md)

This order moves from the smallest mental model to a more complete mail deployment:

- OpenLDAP shows a classic directory-backed authentication flow.
- MariaDB + Lua shows how to use an application-style database without LDAP.
- The mail infrastructure tutorial shows how Nauthilus fits between Dovecot, Postfix, pfxhttp, Valkey, and Lua hooks.

## What You Learn

Across the three tutorials you will learn:

- how a current `config v2` file is structured
- how `runtime`, `observability`, `storage`, `auth`, and `identity` fit together
- how LDAP and Lua backends are connected
- how Redis or Valkey is used for cache and operational state
- how to use the backchannel API for quick checks
- how Nauthilus can act as a central decision point inside a mail infrastructure
