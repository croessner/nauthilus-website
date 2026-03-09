---
title: SAML2 Test Client
description: Complete user guide for the contrib/saml2testclient tool and all available options
keywords: [SAML2, Test Client, Service Provider]
sidebar_position: 3
---

# SAML2 Test Client

The `saml2testclient` is a lightweight SAML 2.0 Service Provider (SP) test application in `contrib/saml2testclient`.
It is intended for end-to-end validation of Nauthilus SAML login and logout behavior.

## Where It Lives

- Source: `nauthilus/contrib/saml2testclient`
- Typical binary path used in examples: `./nauthilus/bin/saml2testclient`

## All Supported Options

`testclient` is configured via environment variables only.

| Variable | Required | Default | Description |
|---|---|---|---|
| `SAML2_IDP_METADATA_URL` | no | `https://localhost:9443/saml/metadata` | Nauthilus IdP metadata URL |
| `SAML2_SP_ENTITY_ID` | no | `https://localhost:9095/saml/metadata` | Entity ID presented by the test SP |
| `SAML2_SP_URL` | no | `https://localhost:9095` | Base URL where the test SP listens |
| `SAML2_INSECURE_SKIP_VERIFY` | no | `true` | TLS verification for IdP metadata fetch (`false` disables insecure mode) |

Notes:
- `SAML2_INSECURE_SKIP_VERIFY` is treated as insecure by default; only exact value `false` enables TLS verification.
- No additional CLI flags are supported for runtime behavior.

## Startup and Certificate Behavior

At startup the client tries to load:

- `contrib/saml2testclient/token.crt`
- `contrib/saml2testclient/token.key`

If loading fails, it generates an in-memory self-signed certificate for the local HTTPS server.

It also exports the SP certificate to:

- `contrib/saml2testclient/sp-cert.pem`

Use this exported certificate in Nauthilus `idp.saml2.service_providers[].cert_file`.

## Transport Mode (HTTP vs HTTPS)

The server mode is derived from `SAML2_SP_URL`:

- `https://...` -> listens with TLS (`ListenAndServeTLS`)
- `http://...` -> listens without TLS (`ListenAndServe`)

Default is HTTPS on `localhost:9095`.

## Internal Endpoints Exposed by the Test Client

- `GET /` -> login page or authenticated attribute view
- `GET /saml/login` -> starts SAML authentication flow
- `GET /logout` -> clears local cookies and redirects to IdP SLO (if discovered)
- `/saml/*` -> SP endpoints provided by `crewjam/samlsp` (includes ACS/metadata handling)

## Runtime Behavior

On successful metadata retrieval and SP initialization, the client:

1. Initializes SAML SP configuration from env settings.
2. Fetches IdP metadata from `SAML2_IDP_METADATA_URL`.
3. Enables IdP-initiated SSO (`AllowIDPInitiated: true`).
4. Tries to discover IdP Single Logout (HTTP-Redirect binding).
5. Serves login + SAML handlers.

Authenticated view (`/`) shows received SAML attributes as JSON and a link to:

- `/mfa/register/home` on the IdP base host (derived from metadata URL)

Local logout (`/logout`) behavior:

- clears cookies `token` and `Nauthilus_session`
- redirects to IdP SLO endpoint when available, otherwise back to `/`

## Quick Start

```bash
export SAML2_IDP_METADATA_URL=https://localhost:9443/saml/metadata
export SAML2_SP_ENTITY_ID=https://localhost:9095/saml/metadata
export SAML2_SP_URL=https://localhost:9095
export SAML2_INSECURE_SKIP_VERIFY=true

./nauthilus/bin/saml2testclient
```

## Required Nauthilus Configuration

```yaml
idp:
  saml2:
    enabled: true
    entity_id: "https://localhost:9443/saml/metadata"
    cert: "YOUR_IDP_CERTIFICATE_HERE" # or cert_file
    key: "YOUR_IDP_KEY_HERE"          # or key_file
    service_providers:
      - entity_id: "https://localhost:9095/saml/metadata"
        acs_url: "https://localhost:9095/saml/acs"
        cert_file: "contrib/saml2testclient/sp-cert.pem"
```

## LDAP Backend Reminder

For actual user login in SAML flow, your backend must allow protocol `saml` (for example in LDAP search config).

## Troubleshooting

### Browser TLS warnings / redirect loops

When both IdP and test SP use self-signed certificates, browsers may block the flow until you trust both origins.

Recommended sequence:

1. Open the test SP URL from `SAML2_SP_URL` directly and accept the certificate warning.
2. Open the Nauthilus URL used by `SAML2_IDP_METADATA_URL` and accept its warning.
3. Retry `/saml/login`.

### Metadata fetch failures

If metadata cannot be fetched, startup may continue with warnings, but auth flow will not succeed until metadata is reachable and valid.
