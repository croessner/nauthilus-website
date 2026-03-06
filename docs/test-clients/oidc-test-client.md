---
title: OIDC Test Client
description: Complete user guide for the contrib/oidctestclient tool and all available options
keywords: [OIDC, OAuth2, Test Client, Device Code, Client Credentials]
sidebar_position: 2
---

# OIDC Test Client

The `oidctestclient` is a small OIDC/OAuth2 test application in `contrib/oidctestclient`. It can run three flows against a Nauthilus IdP:

- `authorization_code` (browser-based)
- `device_code` (console-based)
- `client_credentials` (console-based)

This page documents all runtime options and how each flow behaves.

## Where It Lives

- Source: `nauthilus/contrib/oidctestclient`
- Typical binary path used in examples: `./nauthilus/bin/oidctestclient`

## All Supported Options

`oidctestclient` is configured via environment variables only.

| Variable | Required | Default | Description |
|---|---|---|---|
| `OPENID_PROVIDER` | yes | none | OIDC issuer URL (for discovery), e.g. `http://127.0.0.1:8080` |
| `OAUTH2_CLIENT_ID` | yes | none | OAuth2/OIDC client ID |
| `OAUTH2_CLIENT_SECRET` | yes | none | OAuth2/OIDC client secret |
| `OAUTH2_FLOW` | no | `authorization_code` | Flow selector: `authorization_code`, `device_code`, `client_credentials` |
| `OAUTH2_SCOPES` | no | built-in defaults | Requested scopes (comma and/or space separated) |

Notes:
- Unknown values in `OAUTH2_FLOW` fall back to `authorization_code`.
- `OAUTH2_SCOPES` accepts mixed separators, e.g. `openid,profile email`.

### Default Scope Set

If `OAUTH2_SCOPES` is not set (or parses to an empty list), these defaults are used:

- `openid`
- `profile`
- `email`
- `groups`
- `offline`
- `offline_access`
- `nauthilus:mfa:manage`

## No Additional CLI Flags

The current tool does not provide command-line flags for runtime config. Configuration is environment-based.

The local listen address for browser endpoints is fixed to:

- `127.0.0.1:9094`

## Quick Start

```bash
export OPENID_PROVIDER=http://127.0.0.1:8080
export OAUTH2_CLIENT_ID=test-client
export OAUTH2_CLIENT_SECRET=test-secret
export OAUTH2_FLOW=authorization_code
export OAUTH2_SCOPES="openid profile email"

./nauthilus/bin/oidctestclient
```

## Provider Metadata Used by the Client

From OIDC discovery, the client consumes these fields when available:

- `end_session_endpoint`
- `introspection_endpoint`
- `jwks_uri`
- `device_authorization_endpoint`
- `userinfo_endpoint`
- `token_endpoint`

If an optional endpoint is missing, related checks are skipped (for example introspection).

## Flow Behavior

## Authorization Code (`authorization_code`)

Mode:
- Browser flow with local HTTP handlers on `http://127.0.0.1:9094`.

Registered local routes:
- `GET /` (landing page)
- `GET /start` (starts login)
- `GET /oauth2` (callback)
- `GET /frontchannel-logout`
- `POST /backchannel-logout`
- `GET /logout-callback`

What it validates:
- `state` cookie vs callback `state`
- nonce cookie vs ID token nonce (when `openid` scope is requested)
- ID token signature via discovered JWKS (when `openid` scope is requested)

Additional actions:
- token introspection (if endpoint exists)
- UserInfo request (if endpoint exists)
- renders a success page with token/claims/JWKS details

Logout integration shown on success page:
- front-channel logout URI
- back-channel logout URI
- provider end-session redirect link

## Device Code (`device_code`)

Mode:
- Console-only flow.

What it does:
1. Requests device code at `device_authorization_endpoint`.
2. Prints verification URL and user code.
3. Polls `token_endpoint` until success/timeout/error.
4. Verifies returned ID token via JWKS if `openid` was requested.
5. Calls UserInfo and introspection when available.

Polling behavior:
- Uses server-provided `interval` (defaults to 5s if absent/0).
- Handles RFC-style responses like `authorization_pending`, `slow_down`, `expired_token`, `access_denied`.

## Client Credentials (`client_credentials`)

Mode:
- Console-only flow.

What it does:
1. Requests token from `token_endpoint`.
2. Attempts JWT signature verification via JWKS.
3. Runs introspection (if endpoint exists).

Important behavior:
- Access token verification can fail if the provider returns opaque tokens; this is logged as expected behavior.
- This client currently authenticates with `client_id` + `client_secret` form fields.

## Nauthilus Client Configuration Examples

## Authorization Code client

```yaml
idp:
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

## Device Code client

```yaml
idp:
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

## Client Credentials client

```yaml
idp:
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

## Practical Notes

- For pure OAuth2 tests without ID token verification, omit `openid` from `OAUTH2_SCOPES`.
- For backchannel API tests, prefer `client_credentials` plus `nauthilus:*` scopes.
- For MFA user self-service tests, include `nauthilus:mfa:manage` and use browser flow.
