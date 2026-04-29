---
title: Relay Domains
description: Configuration for auth.controls.relay_domains
keywords: [Configuration, Relay, Domains]
sidebar_position: 7
---

# Relay Domains

Relay-domain validation is configured under `auth.controls.relay_domains` and enabled by listing `relay_domains` in `auth.controls.enabled`.

## Current Paths

- `auth.controls.relay_domains.static`
- `auth.controls.relay_domains.allowlist`

## Example

```yaml
auth:
  controls:
    enabled:
      - relay_domains
    relay_domains:
      static:
        - "example.com"
        - "example.org"
      allowlist:
        admin@example.com: true
        relay-bypass@example.org: true
```

Use `static` for known relay domains and `allowlist` for explicit login exceptions.
