---
title: REST API
description: Detailed documentation of the Nauthilus REST API
keywords: [API, REST, JSON, Authentication, MFA, Brute Force, OIDC, SAML2]
sidebar_position: 10
---

# REST API

Nauthilus exposes REST endpoints for authentication, administration, and the native Identity Provider (OIDC/SAML2). All paths listed here are **current** and available without versioned docs.

## Conventions and Common Headers

- **Admin APIs** under `/api/v1` are usually protected by Basic Auth or JWT (depending on your backchannel configuration).
- **IdP endpoints** (`/login`, `/oidc/*`, `/saml/*`) are public and used by browsers and protocol clients.
- **Rate limiting** and **brute force protection** apply to all endpoints.

### Tracking Headers

All authentication-related endpoints return these headers:

| Header | Description |
| :--- | :--- |
| `X-Nauthilus-Session` | Request GUID for correlation |
| `X-Nauthilus-Memory-Cache` | `Hit` or `Miss` (cache status) |
| `Auth-Status` | `OK`, `FAIL`, or a temporary error string |

### Attribute Headers

Attribute mappings are exposed as `X-Nauthilus-<AttributeName>` headers (for header/basic/nginx services). Example: `X-Nauthilus-Mail`.

### Configurable Request Headers

Header names for the header/nginx/basic auth services are configurable via `server::default_http_request_header::*`. The examples below use the default header names (`Auth-User`, `Auth-Pass`, `Auth-Protocol`, `Auth-Method`, `Auth-Login-Attempt`, `Auth-Password-Encoded`). The OIDC client ID header name is configured with `server::default_http_request_header::oidc_cid`.

---

## Authentication Services

These endpoints are designed for backchannel integrations (mail servers, reverse proxies, or custom applications). All endpoints accept JSON or form data as noted. Authentication failures return `Auth-Status: FAIL` and set the `X-Nauthilus-Session` header for correlation.

### JSON Authentication Service

#### `POST /api/v1/auth/json`

**Content-Type:** `application/json` (also supports `application/x-www-form-urlencoded`)

**Request Body (example):**
```json
{
  "username": "testuser",
  "password": "testpassword",
  "protocol": "imap",
  "method": "plain",
  "client_ip": "203.0.113.9",
  "client_port": "56544",
  "client_hostname": "mail.example",
  "client_id": "imap01",
  "user_agent": "Dovecot/2.3",
  "oidc_cid": "demo-client",
  "auth_login_attempt": 1,
  "ssl": "on",
  "ssl_protocol": "TLSv1.3",
  "ssl_cipher": "TLS_AES_256_GCM_SHA384",
  "ssl_verify": "SUCCESS",
  "ssl_subject_dn": "CN=client",
  "ssl_issuer_dn": "CN=issuer",
  "ssl_serial": "01:02",
  "ssl_fingerprint": "AB:CD:EF",
  "ssl_client_notbefore": "2025-01-01T00:00:00Z",
  "ssl_client_notafter": "2026-01-01T00:00:00Z"
}
```

**Response (success - 200 OK):**
```json
{
  "ok": true,
  "account_field": "account",
  "totp_secret_field": "nauthilusTotpSecret",
  "backend": 1,
  "attributes": {
    "mail": "user@example.com",
    "display_name": "John Doe",
    "uid": "1001"
  }
}
```

**Response (failure - 403 Forbidden):**
```json
null
```

**Response (temporary failure - 500 Internal Server Error):**
```json
{
  "error": "Temporary server problem"
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Authentication successful |
| `400 Bad Request` | Invalid JSON or unsupported media type |
| `403 Forbidden` | Authentication failed or blocked |
| `404 Not Found` | Endpoint disabled |
| `429 Too Many Requests` | Rate limit exceeded |
| `500 Internal Server Error` | Temporary processing error |

---

### Header Authentication Service

#### `POST /api/v1/auth/header`

**Request Headers (example):**
```
Auth-User: testuser
Auth-Pass: testpassword
Auth-Protocol: imap
Auth-Method: plain
Auth-Login-Attempt: 1
Auth-Password-Encoded: 0
<oidc_cid_header>: demo-client
```

When `Auth-Password-Encoded: 1` is set, the password value is expected to be Base64 URL-encoded. The `<oidc_cid_header>` placeholder must match your configured `server::default_http_request_header::oidc_cid` value.

**Response Headers (success):**
```
Auth-Status: OK
X-Nauthilus-Session: 8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f
X-Nauthilus-DisplayName: John Doe
X-Nauthilus-Mail: user@example.com
```

**Response Body (failure):**
```json
null
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Authentication successful |
| `400 Bad Request` | Missing or invalid headers |
| `403 Forbidden` | Authentication failed or blocked |
| `404 Not Found` | Endpoint disabled |
| `429 Too Many Requests` | Rate limit exceeded |
| `500 Internal Server Error` | Temporary processing error |

---

### Basic Authentication Service

#### `GET /api/v1/auth/basic`

**Request Headers (example):**
```
Authorization: Basic dGVzdHVzZXI6dGVzdHBhc3N3b3Jk
Auth-Protocol: imap
Auth-Method: plain
Auth-Login-Attempt: 1
<oidc_cid_header>: demo-client
```

**Response Headers (success):**
```
Auth-Status: OK
X-Nauthilus-Session: 8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f
X-Nauthilus-DisplayName: John Doe
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Authentication successful |
| `400 Bad Request` | Missing Authorization or protocol header |
| `403 Forbidden` | Authentication failed or blocked |
| `404 Not Found` | Endpoint disabled |
| `429 Too Many Requests` | Rate limit exceeded |
| `500 Internal Server Error` | Temporary processing error |

---

### Nginx Authentication Service

#### `GET /api/v1/auth/nginx` / `POST /api/v1/auth/nginx`

**Request Headers (example):**
```
Auth-User: testuser
Auth-Pass: testpassword
Auth-Protocol: imap
X-Real-IP: 203.0.113.9
X-Forwarded-For: 203.0.113.9
```

**Response Headers (success):**
```
Auth-Status: OK
X-Nauthilus-Session: 8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f
X-Nauthilus-Mail: user@example.com
```

**Response Headers (failure):**
```
Auth-Status: FAIL
Auth-Wait: 2
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Success, failure, or temporary failure (see `Auth-Status`) |
| `404 Not Found` | Endpoint disabled |
| `429 Too Many Requests` | Rate limit exceeded |

---

### SASLAuthd Service

#### `POST /api/v1/auth/saslauthd`

**Content-Type:** `application/x-www-form-urlencoded`

**Request Body (example):**
```
username=testuser&password=testpassword&realm=example.com&protocol=imap&method=plain&port=993&tls=on&security=ssl&user_agent=Dovecot/2.3
```

**Response (success - 200 OK):**
```
(empty body)
```

**Response (failure - 403 Forbidden):**
```
FAIL
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Authentication successful |
| `400 Bad Request` | Invalid form data |
| `403 Forbidden` | Authentication failed or blocked |
| `404 Not Found` | Endpoint disabled |
| `429 Too Many Requests` | Rate limit exceeded |
| `500 Internal Server Error` | Temporary processing error |

---

## Identity Provider (IdP)
Nauthilus ships a native OIDC and SAML2 Identity Provider. All IdP endpoints are at the root path (no `/idp` prefix). Language-specific paths are available for `/login`, `/oidc/authorize`, and `/oidc/consent` with the optional `/:languageTag` suffix.

*For flow diagrams, see [OIDC](./configuration/idp/oidc.md) and [SAML2](./configuration/idp/saml2.md).*

### OpenID Connect Discovery

#### `GET /.well-known/openid-configuration`

**Response (example):**
```json
{
  "issuer": "https://idp.example.com",
  "authorization_endpoint": "https://idp.example.com/oidc/authorize",
  "token_endpoint": "https://idp.example.com/oidc/token",
  "introspection_endpoint": "https://idp.example.com/oidc/introspect",
  "userinfo_endpoint": "https://idp.example.com/oidc/userinfo",
  "jwks_uri": "https://idp.example.com/oidc/jwks",
  "end_session_endpoint": "https://idp.example.com/oidc/logout",
  "response_types_supported": ["code"],
  "scopes_supported": ["openid", "profile", "email"],
  "claims_supported": ["sub", "name", "email"],
  "token_endpoint_auth_methods_supported": ["client_secret_basic", "client_secret_post"]
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Discovery document returned |
| `500 Internal Server Error` | Discovery generation failed |

---

### OIDC Authorization Endpoint

#### `GET /oidc/authorize`

**Request (example):**
```
GET /oidc/authorize?response_type=code&client_id=demo&redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback&scope=openid%20profile%20email&state=abc123&code_challenge=xyz&code_challenge_method=S256&nonce=n-0S6_WzA2Mj
```

**Response (success - 302 Found):**
```
Location: https://app.example.com/callback?code=SplxlOBeZQQYbYS6WxSbIA&state=abc123
```

| Status Code | Description |
| :--- | :--- |
| `302 Found` | Redirect to login/consent or client redirect URI |
| `400 Bad Request` | Invalid or missing parameters |
| `500 Internal Server Error` | Authorization processing failed |

---

### OIDC Token Endpoint

#### `POST /oidc/token`

**Content-Type:** `application/x-www-form-urlencoded`

**Request Body (example):**
```
grant_type=authorization_code&code=SplxlOBeZQQYbYS6WxSbIA&redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback&client_id=demo&client_secret=secret
```

**Response (success - 200 OK):**
```json
{
  "access_token": "eyJhbGciOi...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "def50200...",
  "id_token": "eyJhbGciOi..."
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Token issued |
| `400 Bad Request` | Invalid grant or request |
| `401 Unauthorized` | Client authentication failed |
| `500 Internal Server Error` | Token generation failed |

---

### OIDC UserInfo Endpoint

#### `GET /oidc/userinfo`

**Request Headers (example):**
```
Authorization: Bearer eyJhbGciOi...
```

**Response (success - 200 OK):**
```json
{
  "sub": "1001",
  "name": "John Doe",
  "email": "user@example.com"
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Claims returned |
| `401 Unauthorized` | Invalid or missing access token |
| `500 Internal Server Error` | UserInfo processing failed |

---

### OIDC Introspection Endpoint

#### `POST /oidc/introspect`

**Content-Type:** `application/x-www-form-urlencoded`

**Request Body (example):**
```
token=eyJhbGciOi...&token_type_hint=access_token
```

**Response (success - 200 OK):**
```json
{
  "active": true,
  "client_id": "demo",
  "username": "testuser",
  "scope": "openid profile",
  "exp": 1736000000
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Token introspected |
| `400 Bad Request` | Invalid request |
| `401 Unauthorized` | Client authentication failed |
| `500 Internal Server Error` | Introspection failed |

---

### OIDC JWKS Endpoint

#### `GET /oidc/jwks`

**Response (example):**
```json
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "key-1",
      "use": "sig",
      "n": "...",
      "e": "AQAB"
    }
  ]
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | JWKS returned |
| `500 Internal Server Error` | JWKS generation failed |

---

### OIDC Logout Endpoint

#### `GET /oidc/logout` (alias: `GET /logout`)

**Request (example):**
```
GET /oidc/logout?id_token_hint=eyJhbGciOi...&post_logout_redirect_uri=https%3A%2F%2Fapp.example.com%2Flogged_out&state=abc123
```

**Response (success - 302 Found):**
```
Location: https://app.example.com/logged_out?state=abc123
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Logout page rendered |
| `302 Found` | Redirected to `post_logout_redirect_uri` |
| `400 Bad Request` | Invalid logout request |
| `500 Internal Server Error` | Logout processing failed |

---

### OIDC Consent Endpoints

#### `GET /oidc/consent`

**Request (example):**
```
GET /oidc/consent?consent_challenge=abcd&state=xyz
```

**Response (success - 200 OK):**
```
<HTML consent page>
```

#### `POST /oidc/consent`

**Content-Type:** `application/x-www-form-urlencoded`

**Request Body (example):**
```
consent_challenge=abcd&state=xyz&submit=allow
```

**Response (success - 302 Found):**
```
Location: https://app.example.com/callback?code=SplxlOBeZQQYbYS6WxSbIA&state=xyz
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Consent page rendered |
| `302 Found` | Consent accepted and redirected |
| `403 Forbidden` | Consent denied |
| `400 Bad Request` | Invalid consent request |
| `500 Internal Server Error` | Consent processing failed |

---

### IdP Login Endpoints

:::important
These login endpoints are designed exclusively for IdP flows (OIDC and SAML2). They cannot be accessed directly without a valid flow state stored in cookies. The flow state is automatically set when a user initiates an OIDC authorization or SAML2 SSO request. Flow state is managed securely via HTTP-only cookies to prevent Open Redirect vulnerabilities.
:::

#### `GET /login`

Displays the login page. Requires a valid IdP flow state cookie.

**Request (example):**
```
GET /login
```

**Response (success - 200 OK):**
```
<HTML login page>
```

**Response (no valid flow - 400 Bad Request):**
```html
<HTML error page: "This login page can only be accessed through a valid OIDC or SAML2 authentication flow.">
```

#### `POST /login`

**Content-Type:** `application/x-www-form-urlencoded`

**Request Body (example):**
```
username=testuser&password=testpassword&csrf_token=<token>&remember_me=on
```

**Required Form Fields:**
- `username`: The user's username or email
- `password`: The user's password
- `csrf_token`: CSRF protection token (from template variable `.CSRFToken`)
- `remember_me` (optional): Set to `on` to remember the session

**Response (success - 302 Found):**
```
Location: /oidc/authorize?response_type=code&client_id=demo&...
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Login form rendered or re-rendered with error |
| `302 Found` | Login succeeded and redirected to IdP endpoint |
| `400 Bad Request` | Invalid login request, missing flow state, or CSRF token validation failed |
| `500 Internal Server Error` | Login processing failed |

---

### IdP MFA Login Endpoints

All MFA endpoints require a valid IdP flow state cookie and CSRF token.

#### `GET /login/mfa`

Displays the MFA method selection page when the user has multiple MFA methods available.

**Response (success - 200 OK):**
```
<HTML MFA selection page>
```

#### `GET /login/totp`

Displays the TOTP verification form.

**Request (example):**
```
GET /login/totp
```

**Response (success - 200 OK):**
```
<HTML TOTP form>
```

#### `POST /login/totp`

**Content-Type:** `application/x-www-form-urlencoded`

**Request Body (example):**
```
code=123456&csrf_token=<token>
```

**Required Form Fields:**
- `code`: 6-digit TOTP code from authenticator app
- `csrf_token`: CSRF protection token

**Response (success - 302 Found):**
```
Location: /oidc/authorize?response_type=code&client_id=demo&...
```

#### `GET /login/recovery`

Displays the recovery code verification form.

**Request (example):**
```
GET /login/recovery
```

**Response (success - 200 OK):**
```
<HTML recovery code form>
```

#### `POST /login/recovery`

**Content-Type:** `application/x-www-form-urlencoded`

**Request Body (example):**
```
code=R2D2-1C3P&csrf_token=<token>
```

**Required Form Fields:**
- `code`: Recovery code (format: XXXX-XXXX)
- `csrf_token`: CSRF protection token

**Response (success - 302 Found):**
```
Location: /oidc/authorize?response_type=code&client_id=demo&...
```

#### `GET /login/webauthn`

Displays the WebAuthn (passkey/security key) verification page.

**Request (example):**
```
GET /login/webauthn
```

**Response (success - 200 OK):**
```
<HTML WebAuthn verification page with JavaScript>
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | MFA form rendered or re-rendered with error |
| `302 Found` | MFA validation succeeded |
| `400 Bad Request` | Invalid MFA request, missing flow state, or CSRF token validation failed |
| `500 Internal Server Error` | MFA processing failed |

---

### Logged-Out Page

#### `GET /logged_out`

**Response (success - 200 OK):**
```
<HTML logged out page>
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Page rendered |
| `500 Internal Server Error` | Rendering failed |

---

### WebAuthn Endpoints (Names Only)

WebAuthn is intentionally documented by endpoint names only. The UI handles payload details.

- **Login flow:** `GET /login/webauthn/begin`, `POST /login/webauthn/finish`
- **Registration flow:** `GET /api/v1/mfa/webauthn/register/begin`, `POST /api/v1/mfa/webauthn/register/finish`

---

### SAML2 Endpoints

#### `GET /saml/metadata`

**Response (success - 200 OK):**
```xml
<EntityDescriptor entityID="https://idp.example.com/saml">
  <!-- Metadata XML -->
</EntityDescriptor>
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Metadata returned |
| `500 Internal Server Error` | Metadata generation failed |

---

#### `GET /saml/sso` / `POST /saml/sso`

**Request (example):**
```
SAMLRequest=<base64>&RelayState=xyz
```

**Response (success - 200 OK or 302 Found):**
```
<HTML auto-submit form or redirect>
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | SAML response rendered |
| `302 Found` | Redirect to IdP login or SP |
| `400 Bad Request` | Invalid SAML request |
| `500 Internal Server Error` | SSO processing failed |

---

#### `GET /saml/slo` / `POST /saml/slo`

**Request (example):**
```
SAMLRequest=<base64>&RelayState=xyz
```

**Response (success - 200 OK or 302 Found):**
```
<HTML auto-submit form or redirect>
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Logout response rendered |
| `302 Found` | Redirect to SP or IdP |
| `400 Bad Request` | Invalid SAML request |
| `500 Internal Server Error` | SLO processing failed |

---

## Multi-Factor Authentication (MFA) API

:::info Session Required
These endpoints require an active frontend session (cookie). They are typically used by the internal `/account/mfa` management page.
:::

### TOTP (Time-based One-Time Password)

#### `GET /api/v1/mfa/totp/setup`

**Response (success - 200 OK):**
```json
{
  "secret": "JBSWY3DPEHPK3PXP",
  "qr_code_url": "otpauth://totp/Nauthilus:testuser?secret=JBSWY3DPEHPK3PXP&issuer=Nauthilus"
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | TOTP secret generated |
| `401 Unauthorized` | Frontend session missing |
| `500 Internal Server Error` | TOTP generation failed |

---

#### `POST /api/v1/mfa/totp/register`

**Content-Type:** `application/json`

**Request Body (example):**
```json
{
  "code": "123456"
}
```

**Response (success - 200 OK):**
```json
{
  "status": "success",
  "message": "TOTP registered successfully"
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | TOTP registered |
| `400 Bad Request` | Invalid code or request |
| `401 Unauthorized` | Frontend session missing |
| `500 Internal Server Error` | TOTP registration failed |

---

#### `DELETE /api/v1/mfa/totp`

**Response (success - 200 OK):**
```json
{
  "status": "success",
  "message": "TOTP deleted successfully"
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | TOTP deleted |
| `401 Unauthorized` | Frontend session missing |
| `500 Internal Server Error` | TOTP deletion failed |

---

### Recovery Codes

#### `POST /api/v1/mfa/recovery-codes/generate`

**Response (success - 200 OK):**
```json
{
  "codes": [
    "R2D2-1C3P",
    "A9TQ-0Z9L",
    "K2M8-0P1F"
  ]
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Recovery codes generated |
| `400 Bad Request` | No MFA method enabled |
| `401 Unauthorized` | Frontend session missing |
| `500 Internal Server Error` | Generation failed |

---

### WebAuthn (Names Only)

Per requirement, WebAuthn is listed by endpoint name only:

- `GET /api/v1/mfa/webauthn/register/begin`
- `POST /api/v1/mfa/webauthn/register/finish`

---

## Management & Operations
These endpoints are typically protected by Basic Auth or JWT and used for monitoring or administrative tasks.

### OIDC Session Management API

#### `GET /api/v1/oidc/sessions/{user_id}`

**Response (success - 200 OK):**
```json
{
  "at_123": {
    "client_id": "demo",
    "user_id": "1001",
    "username": "testuser",
    "display_name": "John Doe",
    "scopes": ["openid", "profile"],
    "redirect_uri": "https://app.example.com/callback",
    "auth_time": 1736000000,
    "nonce": "n-0S6_WzA2Mj",
    "claims": {
      "email": "user@example.com"
    }
  }
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Sessions returned |
| `400 Bad Request` | Missing `user_id` |
| `401 Unauthorized` | Missing/invalid credentials |
| `403 Forbidden` | Insufficient role |
| `500 Internal Server Error` | Session lookup failed |

---

#### `DELETE /api/v1/oidc/sessions/{user_id}`

**Response (success - 204 No Content):**
```
(empty body)
```

| Status Code | Description |
| :--- | :--- |
| `204 No Content` | All sessions deleted |
| `400 Bad Request` | Missing `user_id` |
| `401 Unauthorized` | Missing/invalid credentials |
| `403 Forbidden` | Insufficient role |
| `500 Internal Server Error` | Deletion failed |

---

#### `DELETE /api/v1/oidc/sessions/{user_id}/{token}`

**Response (success - 204 No Content):**
```
(empty body)
```

| Status Code | Description |
| :--- | :--- |
| `204 No Content` | Session deleted |
| `400 Bad Request` | Missing `token` |
| `401 Unauthorized` | Missing/invalid credentials |
| `403 Forbidden` | Insufficient role |
| `500 Internal Server Error` | Deletion failed |

---

### Brute Force Protection

#### `GET /api/v1/bruteforce/list` / `POST /api/v1/bruteforce/list`

**Request Body (optional, POST example):**
```json
{
  "accounts": ["testuser"],
  "ip_addresses": ["203.0.113.9"]
}
```

**Response (success - 200 OK):**
```json
{
  "session": "8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f",
  "object": "bruteforce",
  "operation": "list",
  "result": [
    {
      "ip_addresses": {
        "203.0.113.9": "default"
      },
      "error": null
    },
    {
      "accounts": {
        "testuser": ["default"]
      },
      "error": null
    }
  ]
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | List returned |
| `400 Bad Request` | Invalid filter request |
| `401 Unauthorized` | Missing/invalid credentials |
| `403 Forbidden` | Missing required role |
| `500 Internal Server Error` | List retrieval failed |

---

#### `DELETE /api/v1/bruteforce/flush`

**Request Body (example):**
```json
{
  "ip_address": "203.0.113.9",
  "rule_name": "default",
  "protocol": "imap",
  "oidc_cid": "demo-client"
}
```

**Response (success - 200 OK):**
```json
{
  "session": "8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f",
  "object": "bruteforce",
  "operation": "flush",
  "result": {
    "ip_address": "203.0.113.9",
    "rule_name": "default",
    "protocol": "imap",
    "oidc_cid": "demo-client",
    "removed_keys": ["bf:203.0.113.9:default"],
    "status": "1 keys flushed"
  }
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Brute force entries flushed |
| `400 Bad Request` | Invalid request payload |
| `401 Unauthorized` | Missing/invalid credentials |
| `403 Forbidden` | Missing required role |
| `500 Internal Server Error` | Flush failed |

---

#### `DELETE /api/v1/bruteforce/flush/async`

**Request Body (example):**
```json
{
  "ip_address": "203.0.113.9",
  "rule_name": "default",
  "protocol": "imap"
}
```

**Response (success - 202 Accepted):**
```json
{
  "session": "8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f",
  "object": "bruteforce",
  "operation": "flush_async",
  "result": {
    "jobId": "1736000000-acde",
    "status": "QUEUED"
  }
}
```

| Status Code | Description |
| :--- | :--- |
| `202 Accepted` | Flush job enqueued |
| `400 Bad Request` | Invalid request payload |
| `401 Unauthorized` | Missing/invalid credentials |
| `403 Forbidden` | Missing required role |
| `500 Internal Server Error` | Enqueue failed |

---

### Cache Management

#### `DELETE /api/v1/cache/flush`

**Request Body (example):**
```json
{
  "user": "testuser"
}
```

**Response (success - 200 OK):**
```json
{
  "session": "8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f",
  "object": "cache",
  "operation": "flush",
  "result": {
    "user": "testuser",
    "removed_keys": ["cache:user:testuser"],
    "status": "1 keys flushed"
  }
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Cache flushed |
| `400 Bad Request` | Invalid request payload |
| `401 Unauthorized` | Missing/invalid credentials |
| `403 Forbidden` | Missing required role |
| `500 Internal Server Error` | Cache flush failed |

---

#### `DELETE /api/v1/cache/flush/async`

**Request Body (example):**
```json
{
  "user": "testuser"
}
```

**Response (success - 202 Accepted):**
```json
{
  "session": "8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f",
  "object": "cache",
  "operation": "flush_async",
  "result": {
    "jobId": "1736000000-acde",
    "status": "QUEUED"
  }
}
```

| Status Code | Description |
| :--- | :--- |
| `202 Accepted` | Cache flush job enqueued |
| `400 Bad Request` | Invalid request payload |
| `401 Unauthorized` | Missing/invalid credentials |
| `403 Forbidden` | Missing required role |
| `500 Internal Server Error` | Enqueue failed |

---

### Async Jobs

#### `GET /api/v1/async/jobs/{jobId}`

**Response (success - 200 OK):**
```json
{
  "session": "8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f",
  "object": "async",
  "operation": "status",
  "result": {
    "jobId": "1736000000-acde",
    "status": "DONE",
    "type": "CACHE_FLUSH",
    "createdAt": "2025-02-05T10:00:00Z",
    "startedAt": "2025-02-05T10:00:01Z",
    "finishedAt": "2025-02-05T10:00:02Z",
    "resultCount": "1250",
    "error": ""
  }
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Job status returned |
| `404 Not Found` | Job ID not found |
| `500 Internal Server Error` | Status lookup failed |

---

### Configuration

#### `GET /api/v1/config/load`

**Response (success - 200 OK):**
```json
{
  "session": "8a7c4c5b-6cf9-4af7-bfde-0a94cfd79f4f",
  "object": "config",
  "operation": "load",
  "result": "{\"server\":{\"log\":{\"log_level\":\"info\"}}}"
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Configuration returned |
| `401 Unauthorized` | Missing/invalid credentials |
| `403 Forbidden` | Missing required role |
| `404 Not Found` | Endpoint disabled |
| `500 Internal Server Error` | Config retrieval failed |

---

## Developer & Miscellaneous
### JWT Generation

#### `POST /api/v1/jwt/token`

**Request Body (example):**
```json
{
  "username": "admin",
  "password": "secret"
}
```

**Response (success - 200 OK):**
```json
{
  "token": "eyJhbGciOi...",
  "expires_at": 1736000000,
  "refresh_token": "def50200..."
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Token issued |
| `400 Bad Request` | Invalid request payload |
| `401 Unauthorized` | Invalid credentials |
| `403 Forbidden` | Missing required role |
| `500 Internal Server Error` | Token creation failed |

---

#### `POST /api/v1/jwt/refresh`

**Request Headers (example):**
```
X-Refresh-Token: def50200...
```

**Response (success - 200 OK):**
```json
{
  "token": "eyJhbGciOi...",
  "expires_at": 1736000000,
  "refresh_token": "def50200..."
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Token refreshed |
| `400 Bad Request` | Missing refresh token |
| `401 Unauthorized` | Invalid refresh token |
| `500 Internal Server Error` | Refresh failed |

---

### Custom Hooks

#### `ANY /api/v1/custom/{hookName}`

**Request Body (example):**
```json
{
  "username": "testuser",
  "action": "provision"
}
```

**Response (example):**
```json
{
  "status": "ok",
  "message": "Hook executed"
}
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Hook executed |
| `403 Forbidden` | Hook disabled or insufficient permissions |
| `500 Internal Server Error` | Hook execution failed |

---

### UI Developer Mode

#### `GET /api/v1/dev/ui`

**Response (success - 200 OK):**
```
<HTML developer UI>
```

#### `GET /api/v1/dev/ui/version`

**Response (success - 200 OK):**
```json
{
  "version": "1.12.0"
}
```

#### `GET /api/v1/dev/ui/render/{template}`

**Response (success - 200 OK):**
```
<Rendered HTML fragment>
```

Optional language variant: `GET /api/v1/dev/ui/render/{template}/{languageTag}`.

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Developer UI rendered |
| `403 Forbidden` | Developer mode disabled |
| `404 Not Found` | Template not found |
| `500 Internal Server Error` | Rendering failed |

---

### Metrics Endpoint

#### `GET /metrics`

**Response (success - 200 OK):**
```
# HELP nauthilus_logins_total Total authentication attempts
# TYPE nauthilus_logins_total counter
nauthilus_logins_total{result="success"} 42
```

| Status Code | Description |
| :--- | :--- |
| `200 OK` | Prometheus metrics returned |
| `404 Not Found` | Metrics route not enabled |

---

## Global Response Headers

Authentication endpoints include these tracking headers:

| Header | Description |
| :--- | :--- |
| `X-Nauthilus-Session` | A unique request GUID for log correlation |
| `X-Nauthilus-Memory-Cache` | `Hit` if the result came from local cache, otherwise `Miss` |
| `Auth-Status` | `OK` or `FAIL` (authentication endpoints only) |