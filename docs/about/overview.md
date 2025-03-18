---
title: Overview
description: See how Nauthilus is integrated into a larger IT eco system
keywords: [Overview, Components, Design]
sidebar_position: 2
---

<!-- TOC -->
* [The big picture](#the-big-picture)
  * [Compontents](#compontents)
  * [Additional notes](#additional-notes)
  * [Related projects](#related-projects)
<!-- TOC -->

# The big picture

See how Nauthilus is integrated into a larger IT eco system.

## Compontents

Nauthilus is part of a number of different services around it. To get an idea, how things work together and want you can
achieve with this software, the following picture is a detailed overview.

```mermaid
flowchart TB
    subgraph Example applications and there communication paths
        direction TB
        app(((Application))) --> ngx
        app --> dcot
        app --> postfix
        app --> keycloak
    end

    subgraph Nauthilus
        direction TB
        as(((Nauthilus)))
    end


    subgraph Keycloak
        direction TB
        keycloak[Keycloak OIDC/SAML] --> nauthiluskeycloak[Nauthilus-Keycloak] 
        nauthiluskeycloak --> as
    end

    subgraph Resources
        as -. uses .-> redis[(Redis DB)]
        as -. may use .-> ldap[(LDAP)]
        as -. may use .-> lua[(Lua backend)]
        as -. may use .-> dns[(DNS Resolver)]
    end

    subgraph Metrics
        prom[Prometheus] -. uses .-> as
    end

    subgraph Postfix
        direction LR
        postfix[Postfix] -. uses .-> pfxhttp
        pfxhttp --> as
    end

    subgraph Dovecot
        direction LR
        dcot[Dovecot] -. uses .-> luabackend[Lua backend]
        luabackend --> as
    end

    subgraph Nginx
        direction LR
        ngx[Nginx] -. uses .-> ngxmailplugin[Mail plugin]
        ngxmailplugin --> as
    end

    subgraph GeoIP Policyd
        as -. may use .-> geopol[GeoIP Policyd]
    end

    subgraph Blocklist
        as -. may use .-> blocklist[Blocklist service]
    end
```

## Additional notes

Built-in MySQL/MariaDB, PostgreSQL and sqlite support is available by using the Lua backend.

## Related projects

| Project             | Link                                                                                               |
|---------------------|----------------------------------------------------------------------------------------------------|
| nauthilus-keycloack | [https://github.com/croessner/nauthilus-keycloak](https://github.com/croessner/nauthilus-keycloak) |
| pfxhttp             | [https://github.com/croessner/pfxhttp](https://github.com/croessner/pfxhttp)                       |
| geoip-policyd       | [https://github.com/croessner/geoip-policyd](https://github.com/croessner/geoip-policyd)           |
| blocklist           | Bundled with Nauthilus                                                                             |