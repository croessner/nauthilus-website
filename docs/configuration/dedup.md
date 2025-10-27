---
title: Deduplication
description: Local vs distributed deduplication in Nauthilus and how to configure it
keywords: [Configuration, Deduplication, Redis]
sidebar_position: 45
---

# Deduplication

This page describes how Nauthilus deduplicates certain operations and signals, and how to enable cluster‑wide (distributed) deduplication.

Dedup is relevant in these areas:
- Backchannel authentication callbacks and coordination between multiple Nauthilus instances.
- Long‑window account metrics and protection signals where multiple nodes may observe the same client activity.

By default, deduplication is local to a single instance. Starting with v1.9.12 and continuing in v1.10.0, cross‑instance deduplication can be enabled via Redis so that all nodes participate in the same dedup domain.

## Configuration

Top‑level server configuration:

```yaml
server:
  # ...
  dedup:
    distributed_enabled: false  # Default: false. Enable Redis-based cross-instance dedup for backchannel auth (v1.9.12+)
    in_process_enabled: true    # Default: true. Enable local in-process dedup (singleflight) within one instance (v1.10.0)
```

- distributed_enabled: when set to true, Nauthilus uses Redis to coordinate deduplication across the cluster. Keep it false when running a single node or when Redis is not available.

Redis connection and pool settings are configured under `server.redis` (standalone) or `server.redis.cluster`. See the Redis configuration section for details.

## Environment variables

Configuration keys can be set via environment variables by uppercasing and joining with underscores, prefixed by NAUTHILUS_. For dedup settings:

```shell
# Enable cross-instance (Redis-based) dedup
NAUTHILUS_DEDUP_DISTRIBUTED_ENABLED=true

# Control local in-process dedup (single instance). Default is true.
NAUTHILUS_DEDUP_IN_PROCESS_ENABLED=false
```

Notes:
- DEDUP_IN_PROCESS_ENABLED defaults to true when unset.
- You can enable both local and distributed dedup. Local singleflight reduces duplicate work within one process; distributed dedup coordinates across instances via Redis.

## Interaction with scoped IP metrics (v1.10.0)

Nauthilus 1.10 introduced scoped IP normalization for Lua features and metrics to reduce noise from IPv6 privacy addresses and large NAT pools. While this is not part of the dedup block above, it complements deduplication of signals across nodes.

- Lua Backend configuration:
  - `lua.config.ip_scoping_v6_cidr` (e.g., 64)
  - `lua.config.ip_scoping_v4_cidr` (e.g., 24)
- Lua API helper: `nauthilus_misc.scoped_ip(ctx, ip)` ensures consistent scoping for metrics and features across components.

See also:
- Filters → Account Protection: Scoped IP normalization and protection thresholds.
- Lua API → Misc → `scoped_ip`.

## Examples

Enable cluster‑wide dedup with a single Redis instance:

```yaml
server:
  redis:
    address: 127.0.0.1:6379
  dedup:
    distributed_enabled: true
```

Enable cluster‑wide dedup in a Redis Cluster:

```yaml
server:
  redis:
    cluster:
      addresses:
        - 10.0.0.11:6379
        - 10.0.0.12:6379
        - 10.0.0.13:6379
  dedup:
    distributed_enabled: true
```

## Notes and recommendations

- When enabling distributed dedup, ensure all Nauthilus instances point to the same Redis deployment.
- Monitor Redis availability and latency; dedup operations are lightweight but require Redis to coordinate state.
- For small single‑node deployments, keep the default (disabled) to avoid external dependencies.

## Version

- distributed_enabled introduced in v1.9.12; documented and recommended patterns updated for v1.10.0.
