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
    authenticator_attachment: string  # optional: platform|cross-platform
    resident_key: string              # default: discouraged
    user_verification: string         # default: preferred
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
- `authenticator_attachment` (string) optional: `platform` or `cross-platform`
- `resident_key` (string) default: `discouraged`; values: `discouraged`, `preferred`, `required`
- `user_verification` (string) default: `preferred`; values: `discouraged`, `preferred`, `required`

Behavior:
- `authenticator_attachment` controls authenticator preference during registration:
  - `platform`: prefer built-in authenticators (e.g. Touch ID, Windows Hello)
  - `cross-platform`: prefer roaming keys (e.g. USB/NFC security keys)
  - unset: no attachment preference is sent; browser/platform decides
- `resident_key` controls discoverable credential behavior:
  - `required`: discoverable credentials required (`requireResidentKey=true`)
  - `preferred` or `discouraged`: discoverable credentials not strictly required
- `user_verification` controls whether biometric/PIN verification is requested or required during WebAuthn ceremonies.
- Values are matched case-insensitively.
- If `rp_id` is omitted or set to `localhost`, Nauthilus tries to derive a better RP ID from `idp.oidc.issuer` host.
- In development mode, localhost origins are appended automatically to support local testing.

## `idp.oidc` (OIDCConfig)

- `enabled` (bool)
- `issuer` (string) required when enabled

### Signing keys
- `signing_keys` (list): entries with
  - `id` (string)
  - `key` (string, PEM) or `key_file` (string, path)
  - `algorithm` (string, optional, default: `RS256`)
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
- `front_channel_logout_supported` (bool, default: `true`)
- `front_channel_logout_session_supported` (bool, default: `false`)
- `back_channel_logout_supported` (bool, default: `true`)
- `back_channel_logout_session_supported` (bool, default: `false`)

### Custom scopes
- `custom_scopes` (list):
  - `name` (string)
  - `description` (string, required default/fallback text)
  - `description_<language>` (string, optional localized text)
  - `description_<language>_<region>` (string, optional localized text with region; use `_`, not `-`)
  - `claims` (list of objects):
    - `name` (string)
    - `type` (string)

Localization behavior for custom scope descriptions:
- Nauthilus first tries an exact locale key like `description_de_at`.
- Then it falls back to base language like `description_de`.
- If no localized key matches, it uses `description`.

### Token defaults
- `access_token_type` (string: `jwt` or `opaque`)
- `default_access_token_lifetime` (duration)
- `default_refresh_token_lifetime` (duration)
- `consent_ttl` (duration, default: internal default)
- `consent_mode` (string: `all_or_nothing` or `granular_optional`, default: `all_or_nothing`)
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
- `require_mfa` ([]string: `totp`, `webauthn`, `recovery_codes`)
- `supported_mfa` ([]string: `totp`, `webauthn`, `recovery_codes`)
- `skip_consent` (bool)
- `delayed_response` (bool)
- `remember_me_ttl` (duration)
- `access_token_lifetime` (duration)
- `access_token_type` (string)
- `refresh_token_lifetime` (duration)
- `consent_ttl` (duration, client-specific override)
- `consent_mode` (string, client-specific override)
- `required_scopes` ([]string)
- `optional_scopes` ([]string, `openid` is not allowed here)
- `token_endpoint_auth_method` (string: `client_secret_basic`, `client_secret_post`, `private_key_jwt`, `none`)
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
- `signature_method` (string, default: `http://www.w3.org/2001/04/xmldsig-more#rsa-sha256`): XMLDSig algorithm identifier URI, not an HTTP endpoint URL. Currently only this value is supported.
- `default_expire_time` (duration, default: 1h)
- `name_id_format` (string, default: `urn:oasis:names:tc:SAML:2.0:nameid-format:persistent`)

### Service Providers (`idp.saml2.service_providers[]`)
- `name` (string): Human-readable name
- `entity_id` (string, required)
- `acs_url` (string, required)
- `slo_url` (string, optional)
- `cert` (string PEM) or `cert_file` (string path): SP certificate for signature verification
- `allowed_attributes` ([]string): Restrict released attributes; empty = all allowed
- `require_mfa` ([]string: `totp`, `webauthn`, `recovery_codes`)
- `supported_mfa` ([]string: `totp`, `webauthn`, `recovery_codes`)
- `delayed_response` (bool)
- `remember_me_ttl` (duration)
- `logout_redirect_uri` (string)

Validation note:
- If both `require_mfa` and `supported_mfa` are configured, `require_mfa` must be a subset of `supported_mfa`.

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
