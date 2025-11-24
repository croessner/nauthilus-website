---
title: Deduplication
description: In-process deduplication in Nauthilus
keywords: [Configuration, Deduplication]
sidebar_position: 45
---

# Deduplication

Nauthilus performs in-process request deduplication to avoid doing the same work multiple times concurrently on a single instance. This reduces load and latency spikes when identical requests arrive in bursts.

## How it works

- In-process dedup uses a per-request key and a short work budget (singleflight pattern).
- One request becomes the leader and performs the work; concurrent duplicates wait for the result within the caller’s deadline and a small safety cap.

## Configuration

Top‑level server configuration:

```yaml
server:
  # ...
  dedup:
    in_process_enabled: true    # Default: true. Enable local in-process dedup within one instance

  timeouts:
    singleflight_work: 3s       # Default: 3s. Work budget for the leader
```

Notes
- If `in_process_enabled` is set to `false`, dedup is disabled and each request is handled independently.
- `timeouts.singleflight_work` controls how long the leader is allowed to do the actual work before timing out.

## Related topics

- Configuration → Server Configuration → Timeouts → `singleflight_work`
- Filters → Account Protection (burst protection and progressive delays)
