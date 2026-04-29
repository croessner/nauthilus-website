---
title: PAM (pam_nauthilus)
description: Guide for the contrib/pam_nauthilus module with current identity config
keywords: [PAM, SSH, Device Code, OIDC]
sidebar_position: 6
---

# PAM with `pam_nauthilus`

`pam_nauthilus` authenticates users through the Nauthilus OIDC Device Authorization flow.

## Required Nauthilus Configuration

Minimal current config:

```yaml
identity:
  oidc:
    enabled: true
    issuer: "https://idp.example.com"
    signing_keys:
      - id: "main"
        key_file: "/etc/nauthilus/oidc.key"
        active: true
    device_flow:
      code_expiry: 10m
      polling_interval: 5
      user_code_length: 8
    clients:
      - name: "SSH"
        client_id: "ssh"
        client_secret: "REDACTED"
        grant_types:
          - "urn:ietf:params:oauth:grant-type:device_code"
        token_endpoint_auth_method: "client_secret_basic"
        scopes:
          - "openid"
          - "profile"
          - "email"
```

## Notes

- device-flow settings live below `identity.oidc.device_flow`
- old `idp.oidc.*` examples are obsolete in current docs
- if you increase timeouts for PAM polling, review both the PAM module timeout and `identity.oidc.device_flow.code_expiry`
