---
sidebar_position: 2
description: Native OIDC configuration in config v2
keywords: [Identity Provider, OIDC, Authorization Code, Device Code, Client Credentials]
---

# OIDC

Nauthilus provides a built-in OpenID Connect provider with:

- Authorization Code
- Device Authorization
- Client Credentials

The current configuration root is:

- `identity.oidc`

## Endpoints

- `GET /.well-known/openid-configuration`
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
        required_scopes:
          - "openid"
        optional_scopes:
          - "profile"
          - "email"
```

## PKCE

- only `S256` is supported
- public clients must use PKCE
- public means no `client_secret` or `token_endpoint_auth_method: none`

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
