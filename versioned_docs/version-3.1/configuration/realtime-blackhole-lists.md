---
title: RBL Control
description: Configuration for auth.controls.rbl
keywords: [Configuration, RBL, DNSBL]
sidebar_position: 5
---

# RBL Control

The RBL control checks the client IP address against configured DNS blocklists. It is configured under `auth.controls.rbl` and enabled via `auth.controls.enabled`.

```yaml
auth:
  controls:
    enabled:
      - rbl
```

## Main Paths

- `auth.controls.rbl.threshold`
- `auth.controls.rbl.lists`
- `auth.controls.rbl.ip_allowlist`

## Example

```yaml
auth:
  controls:
    enabled:
      - rbl
    rbl:
      threshold: 10
      lists:
        - name: "SpamRats AuthBL"
          rbl: "auth.spamrats.com."
          ipv4: true
          ipv6: true
          return_codes:
            - "127.0.0.43"
          allow_failure: false
          weight: 10
        - name: "Abusix"
          rbl: "YOUR-API-KEY.authbl.mail.abusix.zone."
          ipv4: true
          ipv6: true
          return_codes:
            - "127.0.0.4"
          allow_failure: false
          weight: 10
      ip_allowlist:
        - 127.0.0.0/8
        - ::1
        - 192.168.0.0/16
        - 10.0.0.0/8
```

## Notes

- `return_codes` is the canonical list field.
- `ip_allowlist` is the canonical allowlist field.
- hostnames may include a trailing dot to force a fully qualified DNS name.

## Policy Attributes

When `builtin.rbl` is part of `auth.policy.checks`, Nauthilus exports aggregate RBL facts and generated per-list facts.

Aggregate attributes include:

- `auth.rbl.threshold_reached`
- `auth.rbl.score`
- `auth.rbl.threshold`
- `auth.rbl.matched_count`
- `auth.rbl.matched_lists`
- `auth.rbl.list_count`
- `auth.rbl.allow_failure_error_count`
- `auth.rbl.effective_error`
- `auth.rbl.soft_allowlisted`
- `auth.rbl.ip_allowlisted`
- `auth.rbl.error`

For each configured list, the list name is normalized into a policy-safe identifier segment and these attributes are registered:

- `auth.rbl.list.<list>.listed`
- `auth.rbl.list.<list>.weight`
- `auth.rbl.list.<list>.error`
- `auth.rbl.list.<list>.allow_failure`

Example: `SpamRats AuthBL` becomes `spamrats_authbl`, so the match attribute is `auth.rbl.list.spamrats_authbl.listed`.

If two RBL list names normalize to the same identifier, the policy snapshot fails validation. For policy examples, see [Auth Policy Configuration Guide](../guides/auth-policy-configuration.md).
