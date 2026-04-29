---
title: REST API
description: REST API details and current configuration references
keywords: [API, REST, JSON, Authentication, MFA, OIDC, SAML2]
sidebar_position: 10
---

# REST API

Nauthilus exposes REST endpoints for authentication, administration, and the native identity flows.

## Current Configuration References

The configurable request-header names for `/api/v1/auth/header`, `/api/v1/auth/basic`, and `/api/v1/auth/nginx` now live under:

- `auth.request.headers`

Examples:

- `auth.request.headers.username`
- `auth.request.headers.password`
- `auth.request.headers.protocol`
- `auth.request.headers.auth_method`
- `auth.request.headers.login_attempt`
- `auth.request.headers.password_encoded`
- `auth.request.headers.oidc_cid`

The examples below still use the default header names such as `Auth-User`, `Auth-Pass`, and `Auth-Protocol`.

## Header Authentication Example

```text
Auth-User: testuser
Auth-Pass: testpassword
Auth-Protocol: imap
Auth-Method: plain
Auth-Login-Attempt: 1
Auth-Password-Encoded: 0
X-OIDC-CID: demo-client
```

## OIDC Bearer Access for `/api/v1/*`

Bearer-token acceptance for backchannel APIs is configured with:

```yaml
auth:
  backchannel:
    oidc_bearer:
      enabled: true
```

## Configuration Endpoint Example

If you call the configuration endpoint, the returned object now reflects the current config-v2 shape. For example:

```json
{
  "session": "8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f",
  "object": "config",
  "operation": "load",
  "result": "{\"observability\":{\"log\":{\"level\":\"info\"}}}"
}
```

## Identity Endpoints

Current browser-facing endpoints remain:

- `/login`
- `/logout`
- `/mfa/*`
- `/oidc/*`
- `/saml/*`

See the dedicated configuration pages for endpoint-specific configuration:

- [OIDC](/docs/configuration/idp/oidc)
- [SAML](/docs/configuration/idp/saml2)
