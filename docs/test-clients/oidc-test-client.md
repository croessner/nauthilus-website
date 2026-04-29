---
title: OIDC Test Client
description: OIDC test client examples using the current identity config
keywords: [OIDC, OAuth2, Test Client, Device Code, Client Credentials]
sidebar_position: 2
---

# OIDC Test Client

The `oidctestclient` can exercise `authorization_code`, `device_code`, and `client_credentials` flows against the built-in Nauthilus OIDC provider.

## Current Nauthilus Client Configuration Examples

Authorization Code:

```yaml
identity:
  oidc:
    clients:
      - name: "OIDC Test Client"
        client_id: "test-client"
        client_secret: "test-secret"
        redirect_uris:
          - "http://127.0.0.1:9094/oauth2"
        grant_types:
          - "authorization_code"
        scopes:
          - "openid"
          - "profile"
          - "email"
```

Device Code:

```yaml
identity:
  oidc:
    clients:
      - name: "OIDC Test Client Device"
        client_id: "test-client"
        client_secret: "test-secret"
        grant_types:
          - "urn:ietf:params:oauth:grant-type:device_code"
        scopes:
          - "openid"
          - "profile"
```

Client Credentials:

```yaml
identity:
  oidc:
    clients:
      - name: "OIDC Test Client CC"
        client_id: "test-client"
        client_secret: "test-secret"
        grant_types:
          - "client_credentials"
        scopes:
          - "nauthilus:authenticate"
          - "nauthilus:admin"
```

## Notes

- use `identity.oidc`, not `idp.oidc`
- Device Authorization server defaults live under `identity.oidc.device_flow`
