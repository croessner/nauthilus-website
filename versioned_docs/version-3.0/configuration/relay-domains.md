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

## Policy Attributes

When `builtin.relay_domains` is part of `auth.policy.checks`, Nauthilus exports these relay-domain facts:

- `auth.relay_domain.present`: the username contains a valid domain part.
- `auth.relay_domain.known`: the domain is known to the configured static list.
- `auth.relay_domain.value`: the parsed domain value.
- `auth.relay_domain.rejected`: the relay-domain control rejected the request.
- `auth.relay_domain.static_match`: a configured static domain matched.
- `auth.relay_domain.soft_allowlisted`: the soft allowlist suppressed the check.
- `auth.relay_domain.configured_count`: number of configured static domains.
- `auth.relay_domain.error`: technical relay-domain error fact.

Use `value` when the exact domain matters, and use `known`, `rejected`, or `soft_allowlisted` for most policy decisions. For policy examples, see [Auth Policy Configuration Guide](../guides/auth-policy-configuration.md).
