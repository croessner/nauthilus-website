---
title: REST API
description: REST API details and current configuration references
keywords: [API, REST, JSON, CBOR, Authentication, MFA, OIDC, SAML2]
sidebar_position: 10
---

# REST API

Nauthilus exposes REST endpoints for authentication, administration, and the native identity flows.

For typed gRPC authentication, see [gRPC Auth API](grpc-api.md).

## Authentication Endpoints

The authentication API is available below `/api/v1/auth/`:

- `/api/v1/auth/json` accepts JSON request bodies.
- `/api/v1/auth/cbor` accepts CBOR request bodies.
- `/api/v1/auth/header`, `/api/v1/auth/basic`, and `/api/v1/auth/nginx` map request metadata from headers, Basic auth, or NGINX-style form fields.

The JSON and CBOR endpoints use the same logical request model. CBOR clients must send `Content-Type: application/cbor`; JSON clients must send `Content-Type: application/json`.

```json
{
  "username": "alice@example.test",
  "password": "secret",
  "client_ip": "198.51.100.10",
  "client_port": "54321",
  "client_hostname": "client.example.test",
  "client_id": "imap-proxy-1",
  "external_session_id": "upstream-session-id",
  "user_agent": "imap-proxy/1.0",
  "local_ip": "127.0.0.1",
  "local_port": "143",
  "protocol": "imap",
  "method": "plain",
  "ssl": "off",
  "ssl_session_id": "",
  "ssl_client_verify": "NONE",
  "ssl_client_dn": "",
  "ssl_client_cn": "",
  "ssl_issuer": "",
  "ssl_client_notbefore": "",
  "ssl_client_notafter": "",
  "ssl_subject_dn": "",
  "ssl_issuer_dn": "",
  "ssl_client_subject_dn": "",
  "ssl_client_issuer_dn": "",
  "ssl_protocol": "",
  "ssl_cipher": "",
  "ssl_serial": "",
  "ssl_fingerprint": "",
  "oidc_cid": "",
  "auth_login_attempt": 1
}
```

`username` is required. `password` is required for normal authentication requests, but may be omitted when `mode=no-auth` or `mode=list-accounts` is used.

CBOR uses the same field names as JSON. The server decodes CBOR with a strict shared policy:

- maximum request body size is 1 MiB;
- indefinite length items and CBOR tags are rejected;
- duplicate map keys are rejected;
- unknown request fields are rejected;
- maximum nesting depth is 32;
- maximum array elements and map pairs are 4096 each.

## CBOR Authentication Example

```bash
python3 contrib/auth-cbor-request.py \
  --url http://127.0.0.1:8080/api/v1/auth/cbor \
  --username alice@example.test \
  --password secret \
  --protocol imap \
  --method plain
```

The helper sends `Content-Type: application/cbor` and prefers a CBOR response with:

```text
Accept: application/cbor, application/json;q=0.5, text/plain;q=0.1, */*;q=0.05
```

See [CBOR Auth Request Client](test-clients/cbor-auth-request.md) for the full script documentation.

## No-Auth and List-Accounts Modes

`/api/v1/auth/cbor` supports the same query modes as the JSON endpoint:

- `mode=no-auth` runs a request without requiring a password.
- `mode=list-accounts` returns the known account names for the current request context.

`list-accounts` uses HTTP content negotiation. The server supports these response media types, in server-preferred order:

- `application/cbor`
- `application/json`
- `application/x-www-form-urlencoded`
- `text/plain`

If the `Accept` header is missing, wildcarded, or ties with equal quality values, `application/cbor` is selected first. A client can prefer JSON explicitly:

```text
Accept: application/json, application/cbor;q=0.4
```

Unsupported `Accept` combinations return `415 Unsupported Media Type`.

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

CBOR authentication can be disabled independently from the JSON endpoint:

```yaml
runtime:
  servers:
    http:
      disabled_endpoints:
        auth_cbor: true
```

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
