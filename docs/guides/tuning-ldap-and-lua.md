---
title: Tuning LDAP and Lua
description: Performance tuning guidance for LDAP and Lua under the current config model
keywords: [LDAP, Lua, Tuning, Performance]
sidebar_position: 20
---

# Tuning LDAP and Lua

This guide summarizes the tuning knobs that matter most for the current config-v2 layout.

## Current Paths

LDAP:

- `auth.backends.ldap.default`
- `auth.backends.ldap.pools.*`
- `auth.backends.ldap.search`

Lua backend:

- `auth.backends.lua.backend.default`
- `auth.backends.lua.backend.named_backends.*`
- `auth.backends.lua.backend.search`

Lua controls and filters:

- `auth.controls.lua.controls`
- `auth.controls.lua.filters`
- `auth.controls.lua.actions`
- `auth.controls.lua.hooks`

## LDAP: Small Stable Starting Point

```yaml
auth:
  backends:
    ldap:
      default:
        number_of_workers: 8
        lookup_pool_size: 8
        lookup_idle_pool_size: 2
        auth_pool_size: 8
        auth_idle_pool_size: 2
        lookup_queue_length: 16
        auth_queue_length: 16
        connect_abort_timeout: 5s
        search_timeout: 2s
        bind_timeout: 2s
        modify_timeout: 2s
        search_size_limit: 200
        search_time_limit: 2s
        retry_max: 2
        retry_base: 200ms
        retry_max_backoff: 2s
        cb_failure_threshold: 5
        cb_cooldown: 30s
        cb_half_open_max: 1
        health_check_interval: 10s
        health_check_timeout: 1.5s
        negative_cache_ttl: 20s
        cache_impl: ttl
        cache_max_entries: 5000
        include_raw_result: false
```

## Lua Backend: Small Stable Starting Point

```yaml
auth:
  backends:
    lua:
      backend:
        default:
          backend_number_of_workers: 4
          queue_length: 16
```

## What to Watch

LDAP:

- queue wait and queue depth
- retries and circuit-breaker openings
- target health
- cache hit/miss ratios

Lua:

- queue wait
- queue depth
- VM utilization
- VM replacement rate

## Practical Heuristics

- keep queues small when you prefer predictable latency
- increase pool sizes gradually, not in large jumps
- raise timeouts only when latency is real and persistent, not just because queues are too deep
- keep `include_raw_result: false` unless you truly need the extra allocation cost
- use named LDAP pools or named Lua backends to isolate workloads

## Scoped IPs in Lua

When Lua features aggregate client IPs, use scoped identifiers instead of raw addresses if privacy-address churn or NAT noise distorts the data.

Current config paths:

- `auth.backends.lua.backend.default.ip_scoping_v6_cidr`
- `auth.backends.lua.backend.default.ip_scoping_v4_cidr`

Example:

```yaml
auth:
  backends:
    lua:
      backend:
        default:
          ip_scoping_v6_cidr: 64
          ip_scoping_v4_cidr: 24
```

## Rule of Thumb

Start conservative, measure real traffic, then adjust one axis at a time:

1. pool sizes
2. queue lengths
3. timeouts
4. retries
5. cache sizing
