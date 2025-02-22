---
title: Overview
description: See how Nauthilus is integrated into a larger IT eco system
keywords: [Overview, Components, Design]
sidebar_position: 2
---
# The big picture

See how Nauthilus is integrated into a larger IT eco system.

## Compontents

Nauthilus is part of a number of different services around it. To get an idea, how things work together and want you can
achieve with this software, the following picture is a detailed overview.

```mermaid
flowchart LR
    subgraph Incoming authentication request
        direction LR
        app(((Application))) -->|Alternative 1| ngx[/Nginx with mail plugin/]
        app -->|Alternative 2| dcot[/Dovecot with Lua backend/]
        app -->|Alternative 3| lbr[HAProxy]
        app --- oidc[/OAuth 2 OpenID Connect/]
    end
    subgraph OIDC server
        direction LR
        oidc -->|Frontchannel| ory
        ory <--> lbr
    end
    subgraph Ressources
        direction LR
        as((Nauthilus)) <-->|Backchannel| ory[Ory Hydra]
        as -. uses .-> redis[(Redis DB)]
        as -. uses .-> ldap[(LDAP<br/>Active Directory)]
        as -. uses .-> lua[(Lua backend)]
        as -. may use .-> dns[(DNS Resolver)]
        ngx <-->|Backchannel| as
        dcot <-->|BackChannel| as
        lbr <-->|Backchannel| as
    end
    subgraph Metrics
        prom[Prometheus] -. uses .-> as
    end
```

:::note
Built-in MySQL/MariaDB, PostgreSQL and sqlite support is available by using the Lua backend.
::: 

:::note
Your help is very welcome to improve Nauthilus and its documentation. Feel free to send PRs on Github.
:::
