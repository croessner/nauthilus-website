---
sidebar_position: 2
description: Native OIDC and restricted dynamic client registration configuration in config v2
keywords: [Identity Provider, OIDC, Authorization Code, Device Code, Client Credentials, Dynamic Client Registration]
---

# OIDC

Nauthilus provides a built-in OpenID Connect provider with:

- Authorization Code
- Device Authorization
- Client Credentials
- restricted RFC 7591 Dynamic Client Registration for public native mail clients

The current configuration root is:

- `identity.oidc`

## Endpoints

- `GET /.well-known/openid-configuration`
- `POST /oidc/register` when restricted Dynamic Client Registration is enabled
- `GET /oidc/authorize`
- `POST /oidc/token`
- `POST /oidc/introspect`
- `GET /oidc/userinfo`
- `GET /oidc/jwks`
- `GET /oidc/logout`
- `POST /oidc/device`
- `GET /oidc/device/verify`

Optional legacy GET support for `/oidc/token` is controlled by:

- `identity.oidc.tokens.token_endpoint_allow_get`

## Client Authentication Metadata

OIDC discovery publishes token and introspection client-auth metadata separately:

| Metadata | Values |
| --- | --- |
| `token_endpoint_auth_methods_supported` | Configured through `identity.oidc.token_endpoint_auth_methods_supported`; defaults to `client_secret_post`, `client_secret_basic`, `private_key_jwt`, and `none`. |
| `token_endpoint_auth_signing_alg_values_supported` | `RS256` and `EdDSA` when `private_key_jwt` is advertised for the token endpoint. |
| `introspection_endpoint_auth_methods_supported` | `client_secret_post`, `client_secret_basic`, and `private_key_jwt`. |
| `introspection_endpoint_auth_signing_alg_values_supported` | `RS256` and `EdDSA`. |

The introspection endpoint intentionally does not advertise or accept `none` client authentication.

For `private_key_jwt`, the JWT `aud` claim must be the exact endpoint URL. Use `issuer + "/oidc/token"` for token requests and `issuer + "/oidc/introspect"` for introspection requests. A token-endpoint assertion is not reusable for introspection.

## CORS for Discovery

OIDC discovery endpoints are often fetched directly by browser-based clients. Configure cross-origin behavior under `runtime.servers.http.cors`, not directly below `runtime.http`:

```yaml
runtime:
  servers:
    http:
      cors:
        enabled: true
        policies:
          - name: "oidc_discovery"
            enabled: true
            path_prefixes:
              - "/.well-known/"
            allow_origins:
              - "https://app.example.com"
            allow_methods:
              - "GET"
              - "OPTIONS"
            allow_headers:
              - "Authorization"
              - "Content-Type"
            expose_headers: []
            allow_credentials: false
            max_age: 600
```

Policies are evaluated in order. The first enabled policy whose `path_prefixes` entry matches the request path controls the response.

If Nauthilus is behind a reverse proxy or identity sidecar that filters response headers, forward at least `Vary` and the `Access-Control-*` response headers. Otherwise the browser can report a missing `Access-Control-Allow-Origin` header even though Nauthilus emitted it.

## Example

```yaml
identity:
  oidc:
    enabled: true
    issuer: "https://idp.example.com"
    signing_keys:
      - id: "main"
        key_file: "/etc/nauthilus/keys/oidc.pem"
        algorithm: "RS256"
        active: true
    custom_scopes:
      - name: "tenant"
        description: "Tenant information"
        claims:
          - name: "tenant_id"
            type: "string"
    scopes_supported:
      - "openid"
      - "profile"
      - "email"
      - "groups"
      - "offline_access"
    response_types_supported:
      - "code"
    subject_types_supported:
      - "public"
    id_token_signing_alg_values_supported:
      - "RS256"
    token_endpoint_auth_methods_supported:
      - "client_secret_basic"
      - "client_secret_post"
      - "private_key_jwt"
      - "none"
    code_challenge_methods_supported:
      - "S256"
    claims_supported:
      - "sub"
      - "name"
      - "email"
      - "preferred_username"
      - "groups"
    consent:
      ttl: 720h
      mode: "all_or_nothing"
    tokens:
      default_access_token_lifetime: 1h
      default_refresh_token_lifetime: 720h
      revoke_refresh_token: true
      token_endpoint_allow_get: false
    logout:
      front_channel_supported: true
      front_channel_session_supported: false
      back_channel_supported: true
      back_channel_session_supported: false
    device_flow:
      code_expiry: 10m
      polling_interval: 5
      user_code_length: 8
    clients:
      - name: "Example Web App"
        client_id: "example-web"
        client_secret: "change-me"
        redirect_uris:
          - "https://app.example.com/callback"
        scopes:
          - "openid"
          - "profile"
          - "email"
          - "offline_access"
        grant_types:
          - "authorization_code"
        token_endpoint_auth_method: "client_secret_basic"
        require_pkce: true
        required_scopes:
          - "openid"
        optional_scopes:
          - "profile"
          - "email"
        require_mfa:
          - "totp"
        supported_mfa:
          - "totp"
          - "webauthn"
        required_mfa_level: 2
```

## Restricted Native Dynamic Client Registration

Nauthilus can expose an anonymous `POST /oidc/register` endpoint for public native mail clients. This is a constrained
RFC 7591 profile named `mail-client-v1`, not a general-purpose registration service. It permits only Authorization Code
with PKCE `S256`, literal IPv4 or IPv6 loopback redirects, public client authentication, RS256 ID tokens, and short-lived
opaque access tokens.

The feature is disabled by default. A minimal policy is:

```yaml
identity:
  oidc:
    enabled: true
    issuer: "https://idp.example.com"
    auto_key_rotation: true
    custom_scopes:
      - name: "mail:imap"
        description: "Access IMAP mail"
        claims:
          - name: "mail_access"
            type: "string"
      - name: "mail:smtp"
        description: "Submit mail through SMTP"
        claims:
          - name: "mail_submit"
            type: "string"
    dynamic_client_registration:
      enabled: true
      required_scopes: ["openid"]
      optional_scopes: ["offline_access", "mail:imap", "mail:smtp"]
      allow_refresh_tokens: true
      source_hmac_key: "${NAUTHILUS_DCR_SOURCE_HMAC_KEY}"
```

Every required or optional scope must also be present in `scopes_supported` or `custom_scopes`. The mail scope names and
their resource-server meaning are deployment-owned; Nauthilus does not assign IMAP or SMTP semantics automatically.

When enabled, discovery publishes `registration_endpoint`. Registration responses never contain a client secret,
registration access token, or registration management URI. RFC 7592 client management is outside this profile.

See [Operating OIDC Dynamic Client Registration](../../guides/oidc-dynamic-client-registration.md) for the complete
configuration reference, registration examples, lifecycle behavior, monitoring, revocation, and troubleshooting.

## PKCE

- only `S256` is supported
- public clients must use PKCE
- public means no `client_secret` or `token_endpoint_auth_method: none`
- confidential clients can require PKCE by setting `require_pkce: true`

## Client Types and Grant Boundaries

Nauthilus enforces the security properties of each client type at configuration and request time:

- `client_credentials` requires confidential client authentication. A public client configured for this grant is
  rejected during configuration validation.
- A `client_credentials` request must not request `openid`. Service tokens do not represent an end user and do not
  receive an ID token or UserInfo claims; such a request fails with `invalid_scope`.
- Confidential device-authorization clients must authenticate before Nauthilus allocates device-flow state.
- When a request selects `private_key_jwt`, a failed assertion does not fall back to a client secret.
- Public Authorization Code clients must use PKCE with `S256`.
- Confidential Authorization Code clients with `require_pkce: true` must also use PKCE with `S256`.

Client Credentials access tokens are bound to the Nauthilus backchannel resource. JWT tokens carry the issuer-owned
claims `token_type=access_token` and `aud=nauthilus:backchannel`; opaque tokens resolve to the same claims during server
validation. Backchannel authorization rejects ID tokens and access tokens for another audience.

Do not include `openid` in the scope list of a machine-to-machine client:

```yaml
identity:
  oidc:
    clients:
      - name: "Operations Client"
        client_id: "operations-client"
        client_secret: "change-me"
        grant_types:
          - "client_credentials"
        token_endpoint_auth_method: "client_secret_basic"
        scopes:
          - "nauthilus:authenticate"
          - "nauthilus:admin"
          - "nauthilus:security"
```

## Redirect URI Validation

The rules in this section apply to static `identity.oidc.clients[]`. Exact matching is the default, with controlled
exceptions for native clients and explicitly configured wildcard patterns:

- A trailing `*` is allowed only at the end of a configured URI and not after a query string.
- Wildcard matching preserves parsed scheme, host, port, and path-segment boundaries. A prefix for
  `https://app.example/callback/*` cannot match another host or `/callback-evil`.
- Query and fragment components of the requested URI are ignored only while evaluating a permitted trailing wildcard.
- A configured `*` matches HTTP and HTTPS redirect URIs and is strongly discouraged in production.
- HTTP loopback redirects for `127.0.0.1`, `localhost`, and `::1` may use a dynamic port.
- Wildcards are disabled for requested URIs with user-info or unsafe path traversal segments, including encoded forms.
- `post_logout_redirect_uri` is always checked exactly against `post_logout_redirect_uris`.

Prefer exact redirect URIs. Use a loopback exception only for native applications, and keep wildcard patterns within a
dedicated callback path.

Dynamic `mail-client-v1` registrations use a separate, narrower redirect policy. They reject `localhost`, HTTPS,
private-use schemes, wildcards, query strings, fragments, userinfo, encoded paths, and path traversal. Only
`http://127.0.0.1/<path>` and `http://[::1]/<path>` are accepted, with an optional numeric port that may change during
authorization.

## Token and Claim Boundaries

UserInfo requires an access token whose granted scopes contain `openid`. ID tokens are identity assertions, not API
credentials, and introspection reports them as inactive. Successful access-token introspection includes
`token_type: "Bearer"`.

Custom ID-token and access-token claim mappings cannot override issuer-owned protocol and security claims such as
`iss`, `sub`, `aud`, `exp`, `iat`, `scope`, `client_id`, `nonce`, `auth_time`, or `token_type`. Keep application claims in
distinct names instead of relying on collisions with standard claims.

OIDC back-channel logout calls do not follow HTTP redirects. Configure `backchannel_logout_uri` as the final endpoint;
a `3xx` response is a failed delivery.

## MFA Assurance

Each browser client may configure `require_mfa`, `supported_mfa`, `required_mfa_level`, and local
`mfa_policy.levels`. Enrollment, offered challenges, and the strength of the current proof are evaluated separately.
See [MFA Assurance Policy](mfa-assurance.md) for the complete model.

## Backchannel Bearer Access

If you want to use OIDC-issued Bearer tokens for `/api/v1/*` backchannel calls, enable:

```yaml
auth:
  backchannel:
    oidc_bearer:
      enabled: true
```

Related request-header propagation for subject sources/logging lives at:

- `auth.request.headers.oidc_cid`

Clients that validate opaque OIDC bearer tokens through `/oidc/introspect` can authenticate with client secrets or `private_key_jwt`. For `private_key_jwt`, use the introspection endpoint URL as the client-assertion audience.

Every Bearer-authenticated backchannel request also needs `nauthilus:authenticate`, even when the route has an
additional administrative scope. See [REST API](../../rest-api.md#oidc-bearer-access-for-apiv1) for the route matrix and
Basic-authentication behavior.

## Built-in Scope Families

The reserved `nauthilus:*` scopes are used for backchannel administration, authority RPCs, and MFA/WebAuthn operations. They are granted through `identity.oidc.clients[].scopes` like any other allowed scope.

| Scope | Purpose |
| --- | --- |
| `nauthilus:admin` | Full administrative access to backchannel API surfaces that accept admin bearer tokens. |
| `nauthilus:security` | Security-related backchannel access such as brute-force and metrics controls. |
| `nauthilus:authenticate` | Password authentication through backchannel or gRPC authority APIs. |
| `nauthilus:lookup_identity` | Trusted identity lookup and remote user resolution. |
| `nauthilus:list_accounts` | Account listing. |
| `nauthilus:mfa_read` | Read public MFA state. |
| `nauthilus:mfa_verify` | Verify TOTP or recovery-code material. |
| `nauthilus:mfa_write` | Register, update, or delete TOTP and recovery-code state. |
| `nauthilus:webauthn_read` | Read public WebAuthn credential descriptors. |
| `nauthilus:webauthn_write` | Save, update, or delete WebAuthn credentials. |
| `nauthilus:attribute_read` | Release identity attributes to a trusted authority caller. |

For split edge/authority deployments, configure the edge service-principal client with only the scopes needed by its remote backend `allowed_operations`.
