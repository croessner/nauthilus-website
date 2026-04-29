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
