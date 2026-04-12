---
sidebar_position: 2
description: Native OIDC (Authorization Code + Device Code + Client Credentials) endpoints and configuration
keywords: [Identity Provider, OIDC, Authorization Code, Device Code, Client Credentials]
---

# OIDC (Authorization Code + Device Code + Client Credentials)

Nauthilus provides a built-in OpenID Connect (OIDC) Identity Provider implementing the Authorization Code grant, the Device Authorization Grant (RFC 8628), and the Client Credentials grant.

## Authentication Flow

The following diagram shows the typical OIDC Authorization Code flow, including optional MFA and consent steps.

```mermaid
sequenceDiagram
    participant User
    participant RP as Relying Party (Client)
    participant Nauthilus as Nauthilus IdP
    participant Backend as User Database (LDAP/Lua)

    RP->>User: Redirect to /oidc/authorize
    User->>Nauthilus: GET /oidc/authorize
    Note over Nauthilus: Check session
    alt No Session
        Nauthilus->>User: Redirect to /login
        User->>Nauthilus: GET /login
        Nauthilus-->>User: Show Login Page
        User->>Nauthilus: POST /login (username, password)
        Nauthilus->>Backend: Verify Credentials
        Backend-->>Nauthilus: OK
        Note over Nauthilus: Check MFA requirement
        alt MFA Required (TOTP/WebAuthn)
            Nauthilus->>User: Redirect to /login/mfa
            User->>Nauthilus: GET /login/mfa
            Nauthilus-->>User: Show MFA Selection/Entry
            User->>Nauthilus: POST /login/mfa/... (code/assertion)
            Nauthilus->>Backend: Verify MFA
            Backend-->>Nauthilus: OK
        end
        Note over Nauthilus: Create Session
    end
    Note over Nauthilus: Consent Required?
    alt Consent needed
        Nauthilus-->>User: Show Consent Page
        User->>Nauthilus: POST /oidc/consent
    end
    Nauthilus->>User: Redirect to RP (code)
    User->>RP: GET /callback?code=...
    RP->>Nauthilus: POST /oidc/token (code, client_id, client_secret)
    Nauthilus-->>RP: Access Token, ID Token, Refresh Token
```

This page covers endpoints, discovery, client authentication, logout variants, and all configuration options.

## Endpoints

- Discovery: `GET /.well-known/openid-configuration`
- Authorization: `GET /oidc/authorize`
- Token: `POST /oidc/token` (authorization_code, refresh_token, urn:ietf:params:oauth:grant-type:device_code)
- Token (optional legacy mode): `GET /oidc/token` when `idp.oidc.token_endpoint_allow_get: true`
- Introspection: `POST /oidc/introspect`
- UserInfo: `GET /oidc/userinfo`
- JWKS: `GET /oidc/jwks`
- Logout: `GET /oidc/logout`
- Device Authorization: `POST /oidc/device`
- Device Verification: `GET /oidc/device/verify`

## Discovery document

Example fields returned by `/.well-known/openid-configuration`:

```json
{
  "issuer": "https://idp.example.com",
  "authorization_endpoint": "https://idp.example.com/oidc/authorize",
  "token_endpoint": "https://idp.example.com/oidc/token",
  "introspection_endpoint": "https://idp.example.com/oidc/introspect",
  "userinfo_endpoint": "https://idp.example.com/oidc/userinfo",
  "jwks_uri": "https://idp.example.com/oidc/jwks",
  "end_session_endpoint": "https://idp.example.com/oidc/logout",
  "frontchannel_logout_supported": true,
  "frontchannel_logout_session_supported": false,
  "backchannel_logout_supported": true,
  "backchannel_logout_session_supported": false,
  "response_types_supported": ["code"],
  "subject_types_supported": ["public"],
  "id_token_signing_alg_values_supported": ["RS256","EdDSA"],
  "code_challenge_methods_supported": ["S256"],
  "scopes_supported": ["openid","profile","email","groups","offline_access"],
  "token_endpoint_auth_methods_supported": ["client_secret_basic","client_secret_post"],
  "introspection_endpoint_auth_methods_supported": ["client_secret_basic","client_secret_post"],
  "claims_supported": ["sub","name","email","email_verified","preferred_username","given_name","family_name","groups"]
}
```

Notes:
- Only `response_type=code` is supported.
- Front-/Back-channel logout are supported; session variants may be no-ops depending on client support.

## Client authentication

- `client_secret_basic` and `client_secret_post` are supported at the token and introspection endpoints.
- `private_key_jwt` is supported per-client via `token_endpoint_auth_method: private_key_jwt` plus client public key configuration.
- `allow_refresh_token_combined_client_auth` can be enabled per client for refresh-token interoperability when third-party clients send both Basic auth and body credentials.
  - Public clients: allows duplicate body `client_id` with empty body `client_secret`.
  - Confidential clients: requires exact Basic/body credential match and a non-empty body `client_secret`.
  - Default remains strict (`false`).

## PKCE policy (`authorization_code`)

- Nauthilus supports PKCE only with `S256`.
- `code_challenge_method=plain` is rejected.
- Public clients must use PKCE in the Authorization Code flow.
- A client is treated as public when either:
  - no `client_secret` is configured, or
  - `token_endpoint_auth_method: none` is configured.
- For those public clients:
  - `/oidc/authorize` requires `code_challenge` and `code_challenge_method=S256`.
  - `/oidc/token` requires a valid `code_verifier`.
- Confidential clients can also use PKCE and it is recommended.

## Access tokens

- Access tokens can be JWT or opaque (configurable default and per client override).
- Default lifetimes can be overridden per client.

## Configuration

Top-level section: `idp.oidc`

```yaml
idp:
  oidc:
    enabled: true
    issuer: "https://idp.example.com"

    # Signing keys (inline or via files). One or more keys can be configured; mark the active one.
    signing_keys:
      - id: "2026-01-rs256"
        key_file: "/etc/nauthilus/keys/oidc-2026-01-rs256.pem"
        algorithm: "RS256"
        active: true
      - id: "2026-02-eddsa"
        key_file: "/etc/nauthilus/keys/oidc-2026-02-eddsa.pem"
        algorithm: "EdDSA"
        active: false

    # Optional key rotation
    auto_key_rotation: false
    key_rotation_interval: 168h   # 7 days
    key_max_age: 720h             # 30 days

    # Supported values advertised in the discovery document
    scopes_supported: ["openid","profile","email","groups","offline_access"]
    response_types_supported: ["code"]
    subject_types_supported: ["public"]
    id_token_signing_alg_values_supported: ["RS256","EdDSA"]
    code_challenge_methods_supported: ["S256"] # only S256 is supported
    token_endpoint_auth_methods_supported: ["client_secret_basic","client_secret_post"]
    claims_supported: ["sub","name","email","email_verified","preferred_username","given_name","family_name","groups"]
    front_channel_logout_supported: true
    front_channel_logout_session_supported: false
    back_channel_logout_supported: true
    back_channel_logout_session_supported: false

    # Custom scopes map to claims (server-wide declarations)
    custom_scopes:
      - name: "tenant"
        description: "Tenant information"
        description_de: "Mandanteninformationen"
        description_de_at: "Mandanteninformationen (AT)"
        claims:
          - name: tenant_id
            type: string
          - name: tenant_name
            type: string

    # Token defaults
    access_token_type: "jwt"      # or "opaque"
    default_access_token_lifetime: 3600s
    default_refresh_token_lifetime: 4320h
    consent_ttl: 720h
    consent_mode: all_or_nothing  # or granular_optional
    token_endpoint_allow_get: false

    # Device Code Flow (RFC 8628)
    device_code_expiry: 600s
    device_code_polling_interval: 5
    device_code_user_code_length: 8

    # Clients
    clients:
      - name: "Example Web App"
        client_id: "example-web"
        client_secret: "change-me"
        redirect_uris: ["https://app.example.com/callback"]
        scopes: ["openid","profile","email","offline_access"]
        grant_types: ["authorization_code"]
        require_mfa: ["webauthn"]
        supported_mfa: ["totp", "webauthn", "recovery_codes"]
        skip_consent: false
        delayed_response: false
        access_token_lifetime: 7200s
        access_token_type: "jwt"
        refresh_token_lifetime: 4320h
        consent_ttl: 720h
        consent_mode: all_or_nothing
        required_scopes: ["openid", "profile"]
        optional_scopes: ["email", "groups"]
        token_endpoint_auth_method: "client_secret_basic"
        allow_refresh_token_combined_client_auth: false
        # For private_key_jwt authentication:
        # client_public_key_file: "/etc/nauthilus/keys/client-pub.pem"
        # client_public_key_algorithm: "RS256"
        id_token_claims:
          mappings:
            - claim: name
              attribute: cn
            - claim: email
              attribute: mail
            - claim: email_verified
              attribute: mailVerified
              type: bool
        access_token_claims:
          mappings:
            - claim: tenant_id
              attribute: tenantId
              type: string
        post_logout_redirect_uris: ["https://app.example.com/logout-callback"]
        backchannel_logout_uri: "https://app.example.com/backchannel-logout"
        frontchannel_logout_uri: "https://app.example.com/frontchannel-logout"
        frontchannel_logout_session_required: true
        logout_redirect_uri: "https://app.example.com/"
```

### Settings reference

- `enabled` (bool): Enable/disable the OIDC provider
- `issuer` (string): External issuer base URL used in discovery/JWKS
- `signing_keys` (list): One or more keys (inline `key` or `key_file`), with `id`, `algorithm` (default `RS256`) and `active`
- `auto_key_rotation` (bool), `key_rotation_interval` (duration), `key_max_age` (duration)
- `custom_scopes` (list): Named custom scopes mapping to `claims`
- Supported-values arrays used for discovery: `scopes_supported`, `response_types_supported`, `subject_types_supported`, `id_token_signing_alg_values_supported`, `code_challenge_methods_supported`, `token_endpoint_auth_methods_supported`, `claims_supported`
- Logout discovery toggles: `front_channel_logout_supported`, `front_channel_logout_session_supported`, `back_channel_logout_supported`, `back_channel_logout_session_supported`
- Token defaults: `access_token_type`, `default_access_token_lifetime`, `default_refresh_token_lifetime`
- Consent defaults: `consent_ttl`, `consent_mode`
- `token_endpoint_allow_get` (bool, default `false`): accepts GET requests on `/oidc/token` in addition to POST
- Device Code Flow: `device_code_expiry` (duration), `device_code_polling_interval` (int, seconds), `device_code_user_code_length` (int)
- `clients` (list of OIDCClient):
  - `name`, `client_id`, `client_secret`, `redirect_uris`
  - `scopes`, `grant_types` (list, default: `["authorization_code"]`)
  - `require_mfa`, `supported_mfa` (method sets: `totp`, `webauthn`, `recovery_codes`)
  - `skip_consent`, `delayed_response`
  - `access_token_lifetime`, `access_token_type`, `refresh_token_lifetime`
  - `consent_ttl`, `consent_mode`
  - `required_scopes`, `optional_scopes`
  - `token_endpoint_auth_method`
  - `client_public_key` or `client_public_key_file`, `client_public_key_algorithm` (for `private_key_jwt` auth)
  - `id_token_claims` with `mappings[]` (`claim`, `attribute`, `type`)
  - `access_token_claims` with `mappings[]` (`claim`, `attribute`, `type`)
  - `post_logout_redirect_uris`, `backchannel_logout_uri`, `frontchannel_logout_uri`, `frontchannel_logout_session_required`, `logout_redirect_uri`

Validation notes:
- If both `require_mfa` and `supported_mfa` are configured, `require_mfa` must be a subset of `supported_mfa`.
- `optional_scopes` must not include `openid`.
- `code_challenge_methods_supported` currently accepts only `S256`.
- Public clients (`client_secret` omitted or `token_endpoint_auth_method: none`) must use PKCE for `authorization_code`.

## Device Authorization Grant (RFC 8628)

Nauthilus supports the Device Authorization Grant for input-constrained devices (smart TVs, CLI tools, IoT devices).

### Flow

1. The device requests a device code via `POST /oidc/device` with `client_id` and `scope`.
2. The user visits the verification URL and enters the user code shown on the device.
3. The user authenticates and authorizes the device.
4. The device polls `POST /oidc/token` with `grant_type=urn:ietf:params:oauth:grant-type:device_code` until the user completes authorization.

### Configuration

Device code settings are configured under `idp.oidc`:

```yaml
idp:
  oidc:
    device_code_expiry: 600s         # How long a device code is valid (default: 600s)
    device_code_polling_interval: 5  # Minimum polling interval in seconds (default: 5)
    device_code_user_code_length: 8  # Length of the user code (default: 8)
```

Clients must include `urn:ietf:params:oauth:grant-type:device_code` in their `grant_types` to use this flow:

```yaml
    clients:
      - name: "CLI Tool"
        client_id: "cli-tool"
        client_secret: "cli-secret"
        grant_types: ["authorization_code", "urn:ietf:params:oauth:grant-type:device_code"]
        scopes: ["openid", "profile", "email"]
```

## Client Credentials Flow

Nauthilus also supports the `client_credentials` grant for machine-to-machine access.

Client configuration example:

```yaml
idp:
  oidc:
    clients:
      - name: "Backchannel API Client"
        client_id: "api-client"
        client_secret: "super-secret"
        grant_types: ["client_credentials"]
        scopes:
          - nauthilus:authenticate
          - nauthilus:admin
```

Token request example (`client_secret_basic`):

```bash
curl -u api-client:super-secret \
  -d 'grant_type=client_credentials&scope=nauthilus:authenticate nauthilus:admin' \
  https://idp.example.com/oidc/token
```

`private_key_jwt` is also supported for `client_credentials`:

```yaml
idp:
  oidc:
    clients:
      - name: "Backchannel API Client (JWT)"
        client_id: "api-client-jwt"
        grant_types: ["client_credentials"]
        token_endpoint_auth_method: "private_key_jwt"
        client_public_key_file: "/etc/nauthilus/oidc/api-client-jwt.pub.pem"
        client_public_key_algorithm: "RS256"
        scopes: ["nauthilus:authenticate", "nauthilus:admin"]
```

Token request example (`private_key_jwt`):

```bash
curl -X POST https://idp.example.com/oidc/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials&scope=nauthilus:authenticate nauthilus:admin&client_id=api-client-jwt&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=<signed-jwt>'
```

Notes:
- `id_token` is not returned for `client_credentials`.
- For `private_key_jwt`, the signed `client_assertion` must include:
  - `iss` = `client_id`
  - `sub` = `client_id`
  - `aud` contains the token endpoint URL (for example `https://idp.example.com/oidc/token`)
  - valid `exp` in the future
- Use `server.oidc_auth.enabled: true` to accept these Bearer tokens on `/api/v1/*`.

## Using custom scopes and claims

Custom scopes allow you to expose additional claims in ID tokens, access tokens, and the UserInfo response based on attributes coming from your user backend (LDAP or Lua).

How it fits together:
- Server-wide you declare `idp.oidc.custom_scopes[]` with a `name` and a list of `claims { name, type }`.
- Clients can also define their own `custom_scopes[]` to **override** or extend the server-wide custom scopes. This allows client-specific claim exposure.
- For consent UI text, each custom scope uses `description` as the default and can define localized variants via `description_<language>` and `description_<language>_<region>` (for example `description_de`, `description_de_at`).
- Per client you map claim names to backend attributes using `id_token_claims.mappings[]` and `access_token_claims.mappings[]`.
- At runtime, only claims for scopes requested by the client are included.

### Implied Scopes (Compatibility)

For compatibility scenarios, clients can define `implied_scopes`. These scopes are automatically added to the effective scope set even when they are not explicitly requested by the incoming authorization request.

```yaml
idp:
  oidc:
    clients:
      - client_id: "opencloud-desktop"
        scopes:
          - openid
          - profile
          - email
          - roles
        implied_scopes:
          - roles
```

Behavior:
- Requested scopes are filtered against the configured `scopes` allow list.
- `implied_scopes` are appended afterward in stable order and deduplicated.
- Implied scopes not present in the client's `scopes` allow list are ignored.
- The resulting effective scope set is used for consent evaluation, claim filtering, and token issuance.

### Localization lookup behavior:
- The effective language is taken from the URL `:languageTag` when present, otherwise from the user session language.
- Nauthilus normalizes tags to lowercase and `_` separators (`de-AT` -> `de_at`).
- Resolution order for custom scope description is:
  - `description_<full tag>` (for example `description_de_at`)
  - `description_<base language>` (for example `description_de`)
  - `description` (fallback/default)

Example (end-to-end):

```yaml
idp:
  oidc:
    custom_scopes:
      - name: tenant
        description: "Expose the user's tenant"
        claims:
          - name: tenant
            type: string
    clients:
      - client_id: demo
        client_secret: s3cr3t
        redirect_uris: ["https://app.example/callback"]
        scopes: ["openid", "profile", "email", "tenant"]
        id_token_claims:
          mappings:
            - claim: tenant
              attribute: tenant
              type: string
```

Backend attribute source:
- LDAP: ensure the LDAP search populates an attribute key `tenant` (e.g., from `departmentNumber` or a custom attribute). The key must appear in the session attribute map. Alternatively, use the `groups` resolution strategy in LDAP to resolve user group memberships dynamically.
- Lua: in your backend plugin, set `attributes["tenant"] = "acme"` in the result. Or set groups natively using `backend_result:groups({"acme"})` and `backend_result:group_dns({"cn=acme,ou=groups"})`.

Mapping Groups or Group DNs:
Instead of mapping custom attributes via `attribute: "..."`, you can map resolved group lists directly using `from: "groups"` or `from: "group_dns"`.

```yaml
        id_token_claims:
          mappings:
            - claim: "groups"
              from: "groups"
              type: "string_array"
            - claim: "group_dns"
              from: "group_dns"
              type: "string_array"
```

Client request:
- The RP includes the scope in the authorization request, e.g. `scope=openid profile email tenant`.

Resulting ID token excerpt:

```json
{
  "sub": "1234567890",
  "preferred_username": "alice",
  "tenant": "acme"
}
```

Notes:
- Standard claims (e.g., `email_verified`, `phone_number_verified`, `address`, `updated_at`, `groups`) are also gated by their respective scopes (`email`, `phone`, `address`, `profile`, `groups`).
- Custom claims are only included when their scope was requested.

## Built-in `nauthilus:*` scopes

Nauthilus defines a set of reserved scopes prefixed with `nauthilus:`. These scopes control access to internal features and the backchannel API. They are **not** standard OIDC scopes and are specific to Nauthilus.

| Scope | Purpose |
|---|---|
| `nauthilus:authenticate` | Base scope required for all backchannel API access (`/api/v1/*`). Every OIDC Bearer token used against the API must include this scope. |
| `nauthilus:admin` | Grants full administrative access to the backchannel API, including brute-force listing and metrics endpoints. |
| `nauthilus:security` | Grants access to security-related features such as Prometheus metrics and brute-force listing. Can be used as an alternative to `nauthilus:admin` for read-only security operations. |
| `nauthilus:list_accounts` | Grants access to the list-accounts mode on the backchannel API. Required when using the account listing endpoint. |
| `nauthilus:mfa:manage` | Grants access to MFA registration and management pages. This scope is included in the default `scopes_supported` set and allows users to enroll or manage TOTP and WebAuthn credentials. |

### Usage

These scopes are used with OIDC Bearer token authentication on the backchannel API (`server.oidc_auth.enabled: true`). A client using the `client_credentials` grant type requests the required scopes:

```yaml
server:
  oidc_auth:
    enabled: true

idp:
  oidc:
    clients:
      - name: "API Client"
        client_id: "api-client"
        client_secret: "super-secret"
        grant_types: ["client_credentials"]
        scopes: ["nauthilus:authenticate", "nauthilus:admin"]
```

The middleware validates the token and checks for the required scopes:

- All `/api/v1/*` requests require `nauthilus:authenticate`.
- Brute-force listing and metrics require `nauthilus:security` or `nauthilus:admin`.
- The list-accounts mode requires `nauthilus:list_accounts`.

The `nauthilus:mfa:manage` scope is also relevant for interactive sessions (Authorization Code flow) where users manage their MFA credentials.

### Lua custom hooks

When using Lua custom hooks with OIDC authentication, the `scopes` field on each hook restricts access to tokens carrying the listed scopes. You can use any combination of `nauthilus:*` scopes or custom scopes:

```yaml
lua:
  custom_hooks:
    - http_location: /api/v1/custom/example
      http_method: GET
      script_path: /etc/nauthilus/lua/hooks/example.lua
      scopes:
        - "nauthilus:admin"
```

See also: [Lua custom hooks](../database-backends/lua.md)

### Lua request fields for IdP policies

For Lua features/filters/actions that run during IdP-backed requests, Nauthilus now provides additional IdP-related fields on the `request` object:

- `request.grant_type`
- `request.oidc_cid`
- `request.oidc_client_name`
- `request.redirect_uri`
- `request.mfa_completed`
- `request.mfa_method`
- `request.requested_scopes`
- `request.user_groups`
- `request.allowed_client_scopes`
- `request.allowed_client_grant_types`

Behavior notes:
- These fields are populated from active IdP flow/session context where available.
- For non-IdP requests, values may be empty strings, `false`, or empty tables.
- `request.allowed_client_scopes` and `request.allowed_client_grant_types` are derived from the configured OIDC client.

Example policy plugin:
- `server/lua-plugins.d/filters/idp_policy.lua`
- `server/lua-plugins.d/filters/README.md` (explains all IdP-specific fields and policy examples)

## Headers and logging

- The server can propagate an OIDC Client ID header for logs/filters via `server::default_http_request_header::oidc_cid`.

## Metrics

- Prometheus counters/gauges are exposed for OIDC logins, tokens issued, consent, and MFA operations.
