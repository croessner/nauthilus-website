---
title: Deduplication
description: In-process deduplication in Nauthilus
keywords: [Configuration, Deduplication]
sidebar_position: 45
---

# Deduplication

Nauthilus performs in-process request deduplication to avoid doing the same work multiple times concurrently on a single instance. This reduces load and latency spikes when identical requests arrive in bursts.

:::warning Deprecated/Removed in v1.11.4
As of v1.11.4, the in-process request deduplication feature has been removed due to instability that could not be fully resolved. The following settings are deprecated and ignored:

- `server.dedup.in_process_enabled`
- `server.timeouts.singleflight_work`

If these keys are present in your configuration, they will be ignored.
:::

## How it works

- In-process dedup uses a per-request key and a short work budget (singleflight pattern).
- One request becomes the leader and performs the work; concurrent duplicates wait for the result within the caller’s deadline and a small safety cap.

## Configuration

Top‑level server configuration:

```yaml
server:
  # ...
  # Dedup configuration has been removed in v1.11.4.
  # The following keys are deprecated and ignored if present:
  # dedup:
  #   in_process_enabled: true
  #
  # timeouts:
  #   singleflight_work: 3s
```

Notes
- Prior to v1.11.4, `in_process_enabled` toggled the in-process deduplication feature and `timeouts.singleflight_work` capped the leader’s work time.
- Starting with v1.11.4 these options are ignored; there is no replacement at this time.

## Related topics

- Configuration → Server Configuration → Timeouts
- Filters → Account Protection (burst protection and progressive delays)
