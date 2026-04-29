---
title: TLS Enforcement / Cleartext Allowlist
description: Configuration for auth.controls.tls_encryption.allow_cleartext_networks
keywords: [Configuration, TLS, Cleartext, Networks]
sidebar_position: 6
---

# TLS Enforcement / Cleartext Allowlist

The TLS-enforcement control rejects unauthenticated cleartext connections except for explicitly trusted networks.

The current path is:

- `auth.controls.tls_encryption.allow_cleartext_networks`

Enable it with:

```yaml
auth:
  controls:
    enabled:
      - tls_encryption
```

## Example

```yaml
auth:
  controls:
    enabled:
      - tls_encryption
    tls_encryption:
      allow_cleartext_networks:
        - 127.0.0.0/8
        - ::1
        - 192.168.0.0/16
        - fd00::/8
```

Notes:

- localhost remains a natural candidate for the allowlist
- old top-level `cleartext_networks` is no longer the public path
