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

## Notes

- `ip_allowlist` is the current canonical name.
- `protocols` now belongs inside the brute-force block.
- learning names use the current control names, for example `rbl`, not `realtime_blackhole_lists`.
- old neural-network configuration is not part of the current public configuration model.
