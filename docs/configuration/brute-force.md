---
title: Brute Force Protection
description: Configuration for auth.controls.brute_force
keywords: [Configuration, Brute Force, Protection]
sidebar_position: 8
---

# Brute Force Protection

Brute-force protection is configured under `auth.controls.brute_force` and activated by listing `brute_force` in `auth.controls.enabled`.

```yaml
auth:
  controls:
    enabled:
      - brute_force
```

## Main Paths

- `auth.controls.brute_force.protocols`
- `auth.controls.brute_force.ip_allowlist`
- `auth.controls.brute_force.buckets`
- `auth.controls.brute_force.learning`
- `auth.controls.brute_force.custom_tolerations`
- `auth.controls.brute_force.ip_scoping`
- `auth.controls.brute_force.tolerate_ttl`
- `auth.controls.brute_force.tolerate_percent`
- `auth.controls.brute_force.adaptive_toleration`
- `auth.controls.brute_force.pw_history_for_known_accounts`

## Example

```yaml
auth:
  controls:
    enabled:
      - brute_force
    brute_force:
      protocols:
        - imap
        - smtp
        - submission
      ip_allowlist:
        - 127.0.0.0/8
        - ::1
      buckets:
        - name: "login_rule"
          period: 10m
          ban_time: 4h
          cidr: 24
          ipv4: true
          ipv6: false
          failed_requests: 5
      learning:
        - rbl
        - relay_domains
        - brute_force
        - lua
      tolerate_percent: 20
      tolerate_ttl: 48h
      custom_tolerations:
        - ip_address: "192.168.1.0/24"
          tolerate_percent: 30
          tolerate_ttl: 72h
      ip_scoping:
        rwp_ipv6_cidr: 64
        tolerations_ipv6_cidr: 64
      adaptive_toleration: true
      pw_history_for_known_accounts: true
```

## Policy Attributes

When `builtin.brute_force` is part of `auth.policy.checks`, Nauthilus exports both global brute-force facts and generated per-bucket facts. Bucket names become policy-safe identifier segments:

| Bucket name | Policy segment | Example attribute |
|---|---|---|
| `login_rule` | `login_rule` | `auth.brute_force.bucket.login_rule.ratio` |
| `IMAP Short` | `imap_short` | `auth.brute_force.bucket.imap_short.over_limit` |
| `24h` | `b_24h` | `auth.brute_force.bucket.b_24h.repeating` |

The generated bucket attributes include:

- `matched`
- `count`
- `limit`
- `effective_limit`
- `remaining`
- `ratio`
- `over_limit`
- `already_banned`
- `repeating`

Global brute-force policy attributes also include toleration facts:

- `auth.brute_force.toleration.active`
- `auth.brute_force.toleration.mode`
- `auth.brute_force.toleration.custom`
- `auth.brute_force.toleration.positive`
- `auth.brute_force.toleration.negative`
- `auth.brute_force.toleration.max_negative`
- `auth.brute_force.toleration.percent`
- `auth.brute_force.toleration.ttl_seconds`
- `auth.brute_force.toleration.suppressed_block`

Use these when a policy needs to distinguish "bucket pressure exists" from "the request was tolerated by reputation". For example, `suppressed_block` is true when toleration prevented a block that would otherwise have been applied.

Normalized bucket identifiers must be unique. If two bucket names normalize to the same policy segment, the policy snapshot fails validation. For the full attribute list and YAML examples, see [Auth Policy Reference](auth-policy.md) and [Auth Policy Configuration Guide](../guides/auth-policy-configuration.md).

## Notes

- `ip_allowlist` is the current canonical name.
- `protocols` now belongs inside the brute-force block.
- learning names use the current control names, for example `rbl`, not `realtime_blackhole_lists`.
- old neural-network configuration is not part of the current public configuration model.
