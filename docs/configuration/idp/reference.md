---
sidebar_position: 4
description: Complete reference of IdP (OIDC, SAML2, WebAuthn) settings
keywords: [Identity Provider, Configuration Reference, OIDC, SAML2, WebAuthn]
---

# IdP Configuration Reference

This page lists all new configuration settings introduced with the native Identity Provider. See the OIDC and SAML2 pages for narrative explanations and examples.

## Top-level `idp` section

```yaml
idp:
  terms_of_service_url: string
  privacy_policy_url: string
  webauthn:
    rp_display_name: string   # default: "Nauthilus"
    rp_id: string             # default: "localhost"
    rp_origins: [string]      # default: ["https://localhost"]
  oidc: { ... }
  saml2: { ... }
```

### `idp.terms_of_service_url`
- URL to Terms of Service page shown in the frontend

### `idp.privacy_policy_url`
- URL to Privacy Policy page shown in the frontend

### `idp.webauthn`
- `rp_display_name` (string) default: "Nauthilus"
- `rp_id` (string) default: "localhost"
- `rp_origins` ([]string) default: ["https://localhost"]

## `idp.oidc` (OIDCConfig)

- `enabled` (bool)
- `issuer` (string) required when enabled

### Signing keys
- `signing_keys` (list): entries with
  - `id` (string)
  - `key` (string, PEM) or `key_file` (string, path)
  - `active` (bool)

### Rotation
- `auto_key_rotation` (bool)
- `key_rotation_interval` (duration)
- `key_max_age` (duration)

### Discovery advertised arrays
- `scopes_supported` ([]string)
- `response_types_supported` ([]string)
- `subject_types_supported` ([]string)
- `id_token_signing_alg_values_supported` ([]string)
- `token_endpoint_auth_methods_supported` ([]string)
- `claims_supported` ([]string)

### Custom scopes
- `custom_scopes` (list):
  - `name` (string)
  - `description` (string)
  - `claims` ([]string)

### Token defaults
- `access_token_type` (string: `jwt` or `opaque`)
- `default_access_token_lifetime` (duration)
- `default_refresh_token_lifetime` (duration)
### Device Code Flow (RFC 8628)
- `device_code_expiry` (duration, default: 600s)
- `device_code_polling_interval` (int, seconds, default: 5)
- `device_code_user_code_length` (int, default: 8)
### Clients (`idp.oidc.clients[]`)
- `name` (string)
- `client_id` (string), `client_secret` (string)
- `redirect_uris` ([]string)
- `scopes` ([]string)
- `grant_types` ([]string, default: `["authorization_code"]`)
- `skip_consent` (bool)
- `delayed_response` (bool)
- `remember_me_ttl` (duration)
- `access_token_lifetime` (duration)
- `access_token_type` (string)
- `refresh_token_lifetime` (duration)
- `token_endpoint_auth_method` (string)
- `client_public_key` (string PEM) or `client_public_key_file` (string path) — for `private_key_jwt` authentication
- `client_public_key_algorithm` (string, default: `RS256`)
- `id_token_claims` (IdTokenClaims):
  - `mappings` (list): entries with `claim` (string), `attribute` (string), `type` (string, optional)
- `access_token_claims` (AccessTokenClaims):
  - `mappings` (list): entries with `claim` (string), `attribute` (string), `type` (string, optional)
- `post_logout_redirect_uris` ([]string)
- `backchannel_logout_uri` (string)
- `frontchannel_logout_uri` (string)
- `frontchannel_logout_session_required` (bool)
- `logout_redirect_uri` (string)

## `idp.saml2` (SAML2Config)

- `enabled` (bool)
- `entity_id` (string)
- `cert` (string PEM) or `cert_file` (string path)
- `key` (string PEM) or `key_file` (string path)
- `signature_method` (string, default: `rsa-sha256`)
- `default_expire_time` (duration, default: 1h)
- `name_id_format` (string, default: `urn:oasis:names:tc:SAML:2.0:nameid-format:persistent`)

### Service Providers (`idp.saml2.service_providers[]`)
- `name` (string): Human-readable name
- `entity_id` (string, required)
- `acs_url` (string, required)
- `slo_url` (string, optional)
- `cert` (string PEM) or `cert_file` (string path): SP certificate for signature verification
- `allowed_attributes` ([]string): Restrict released attributes; empty = all allowed
- `delayed_response` (bool)
- `remember_me_ttl` (duration)
- `logout_redirect_uri` (string)
- `allow_mfa_manage` (bool, default: `false`): Allow users to manage MFA credentials (TOTP/WebAuthn) when authenticated via this SP

## Built-in `nauthilus:*` scopes

See [OIDC — Built-in nauthilus:* scopes](./oidc.md#built-in-nauthilus-scopes) for the full reference of reserved scopes used for backchannel API access and MFA management.

## Related server settings

- `server::default_http_request_header::oidc_cid` (string): Header name used to propagate the OIDC Client ID to downstreams/logs/filters.
- Frontend defaults:
  - `server::frontend::totp_issuer` default: "Nauthilus"
  - `server::frontend::totp_skew` default: 1

## Metrics

Key metrics exported (names may evolve):
- `idp_logins_total{client}`
- `idp_tokens_issued_total{client}`
- `idp_consent_total{client,action}`
- `idp_mfa_operations_total{type,action}`
