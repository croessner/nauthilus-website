---
title: REST API
description: REST API details and current configuration references
keywords: [API, REST, JSON, CBOR, Authentication, MFA, OIDC, SAML2]
sidebar_position: 10
---

# REST API

Nauthilus exposes REST endpoints for authentication, administration, and the native identity flows.

For generated endpoint references and raw OpenAPI downloads, see [API Reference](api-reference/index.md).

For typed gRPC authentication, see [gRPC Auth API](grpc-api.md).

## Authentication Endpoints

The authentication API is available below `/api/v1/auth/`:

- `/api/v1/auth/json` accepts JSON request bodies.
- `/api/v1/auth/cbor` accepts CBOR request bodies.
- `/api/v1/auth/header` and `/api/v1/auth/nginx` map request metadata from headers or NGINX-style form fields.
- `/api/v1/auth/basic` maps end-user credentials from the HTTP Basic `Authorization` header. This endpoint exists only in binaries built with the Go build tag `auth_basic_endpoint`.

The JSON and CBOR endpoints use the same logical request model. CBOR clients must send `Content-Type: application/cbor`; JSON clients must send `Content-Type: application/json`.

When an auth policy selects `response_message.from: i18n`, the HTTP auth response renderer uses `Accept-Language` unless policy selected a `response_language`. The rendered status message is returned through the existing response field or status header for that endpoint. When localization selects a language, the response includes:

```text
Content-Language: de
```

If the translation key is missing, Nauthilus returns the configured policy fallback text. Existing policies without `response_message.from: i18n` keep their current response text behavior and do not gain localization headers.

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

## CBOR Authentication Responses

`/api/v1/auth/cbor` returns CBOR response bodies with `Content-Type: application/cbor`.

Successful authentication returns the same logical response object as the JSON endpoint, encoded as a CBOR map:

```json
{
  "ok": true,
  "account_field": "uid",
  "totp_secret_field": "totp_secret",
  "backend": 1,
  "attributes": {
    "uid": ["alice@example.test"]
  }
}
```

Authentication denials are domain decisions, not decoder failures. They keep the normal auth-failure status code, set
`Auth-Status` to the rendered status message, and return a CBOR `null` body.

Temporary failures return the temporary-failure status code, set `Auth-Status` to the rendered status message, and
encode the error payload as a CBOR map:

```json
{
  "error": "Temporary server problem"
}
```

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

When `mode=list-accounts` negotiates `application/cbor`, the response body is a single CBOR array containing the
account names.

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

For header-based authentication, configured client-IP and client-port headers are accepted only when the immediate
network peer belongs to `runtime.servers.http.trusted_proxies`. Requests from any other peer cannot override the
connection-derived client address with those headers. Configure only proxy addresses or narrow proxy networks that you
operate; do not trust a general client network.

CBOR authentication can be disabled independently from the JSON endpoint:

```yaml
runtime:
  servers:
    http:
      disabled_endpoints:
        auth_cbor: true
```

The Basic authentication endpoint is different from `auth.backchannel.basic_auth`. Backchannel Basic auth protects management routes. `/api/v1/auth/basic` is an authentication protocol endpoint and is only present when the binary was built with `-tags auth_basic_endpoint`; `runtime.servers.http.disabled_endpoints.auth_basic` only has an effect for that tagged binary.

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

Protected backchannel routes can use configured backchannel Basic authentication, OIDC Bearer authentication, or both.
They have different authorization semantics:

- A Bearer token must be an access token with `token_type=access_token`, audience `nauthilus:backchannel`, and the base
  scope `nauthilus:authenticate` on every protected `/api/v1/*` request.
- Routes with an additional scope check accept any one of the listed route scopes.
- Configured backchannel Basic authentication is the administrative management credential. After it succeeds, it is not
  subject to Bearer scope checks.
- Missing or invalid authentication returns `401`. A valid Bearer token that lacks the base or route scope returns
  `403`.

The current route-specific Bearer requirements are:

| Route family | Additional Bearer scope, any-of |
| --- | --- |
| Authentication routes and management OpenAPI documents | None beyond `nauthilus:authenticate`. |
| Cache flush, brute-force list/flush, and asynchronous job status | `nauthilus:security` or `nauthilus:admin`. |
| OIDC session list/delete | `nauthilus:security` or `nauthilus:admin`. |
| Add/delete TOTP or recovery-code state | `nauthilus:mfa_write` or `nauthilus:admin`. |
| Read WebAuthn credential descriptors | `nauthilus:webauthn_read` or `nauthilus:admin`. |
| Save/update/delete WebAuthn credentials | `nauthilus:webauthn_write` or `nauthilus:admin`. |

Grant only the route scopes the client needs. The built-in IdP issues suitable machine-to-machine tokens with the
Client Credentials Grant; do not request `openid` for such clients.

## OIDC Session Administration

`GET /api/v1/oidc/sessions/{user_id}` returns token-safe metadata rather than stored token material:

```json
{
  "sessions": [
    {
      "id": "a stable SHA-256-derived session identifier",
      "client_id": "example-web",
      "user_id": "alice",
      "username": "alice@example.test",
      "display_name": "Alice Example",
      "redirect_uri": "https://app.example.com/callback",
      "mfa_method": "webauthn",
      "scopes": ["openid", "profile"],
      "auth_time": "2026-07-10T08:30:00Z",
      "mfa_completed": true
    }
  ]
}
```

The `id` is derived from the stored access-token reference and is safe to display; it is not the access token. Pass this
`id` to the single-session delete route as its historical `{token}` path parameter. Dynamic-client bearer material is
never exposed by the list operation. The all-sessions delete route revokes both static and dynamic access and refresh
state for the user and is the correct operation for complete user-wide revocation.

## Request Decompression Boundary

When `runtime.servers.http.middlewares.request_decompression` is enabled, Nauthilus accepts gzip, Brotli, and Zstandard
request encodings. The expanded body is capped at 1 MiB before the handler parses it. This limit
applies after decompression and prevents a small compressed request from expanding without a bound.

## Sensitive Authentication Output

Backend attributes may contain password, token, private-key, TOTP-secret, or recovery-code material needed internally.
Nauthilus removes attributes classified as secret-bearing from JSON/CBOR authentication response objects and from
generated authentication response headers. Configured deployment-specific TOTP secret and recovery fields are also
filtered. Clients must not depend on receiving those fields from an authentication response.

## OpenAPI Contracts and Runtime Validation

Nauthilus serves its management OpenAPI contract at:

- `/api/v1/openapi.yaml`
- `/api/v1/openapi.json`

The public IdP contract is served at:

- `/.well-known/openapi.yaml`
- `/.well-known/openapi.json`

These documents are the stable machine-readable contracts used by the generated client checks and by the website API reference. Runtime request validation is optional and default-off. When enabled, it validates only selected management operation IDs such as cache flush and brute-force list/flush requests. See [Runtime, Observability, and Storage](configuration/server-configuration.md#openapi-runtime-request-validation) for the configuration block and the current operation allowlist.

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
