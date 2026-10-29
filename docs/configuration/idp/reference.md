---
sidebar_position: 4
description: Current identity section reference
keywords: [Identity Provider, Configuration Reference, OIDC, SAML2, WebAuthn]
---

# Identity Reference

The current identity tree is:

```yaml
identity:
  session:
    remember_me_ttl: duration
  frontend:
    enabled: bool
    encryption_secret: string
    assets:
      html_static_content_path: string
      language_resources: string
    localization:
      languages: [string]
      default_language: string
    links:
      terms_of_service_url: string
      privacy_policy_url: string
      password_forgotten_url: string
    security_headers:
      enabled: bool
  mfa:
    totp:
      issuer: string
      skew: int
    webauthn:
      rp_display_name: string
      rp_id: string
      rp_origins: [string]
      authenticator_attachment: string
      resident_key: string
      user_verification: string
  mfa_policy:
    levels:
      recovery_codes: int
      totp: int
      webauthn: int
  oidc: { ... }
  saml: { ... }
```

## Important Migrations

| Old path | Current path |
|---|---|
| `idp.remember_me_ttl` | `identity.session.remember_me_ttl` |
| `server.frontend.enabled` | `identity.frontend.enabled` |
| `server.frontend.html_static_content_path` | `identity.frontend.assets.html_static_content_path` |
| `server.frontend.language_resources` | `identity.frontend.assets.language_resources` |
| `server.frontend.languages` | `identity.frontend.localization.languages` |
| `server.frontend.default_language` | `identity.frontend.localization.default_language` |
| `server.frontend.totp_issuer` | `identity.mfa.totp.issuer` |
| `server.frontend.totp_skew` | `identity.mfa.totp.skew` |
| `idp.webauthn` | `identity.mfa.webauthn` |
| `idp.oidc` | `identity.oidc` |
| `idp.saml2` | `identity.saml` |

## WebAuthn

`identity.mfa.webauthn` controls the Relying Party configuration used during registration and login ceremonies.

## MFA Assurance

`identity.mfa_policy.levels` defines the global method-to-assurance mapping. The built-in levels are
`recovery_codes: 1`, `totp: 2`, and `webauthn: 3`.

OIDC clients and SAML service providers support these related fields:

| Field | Meaning |
| --- | --- |
| `require_mfa` | Methods that must be registered before issuing a successful response. |
| `supported_mfa` | Methods eligible for challenges and registration. An empty list permits all available methods. |
| `required_mfa_level` | Minimum level of the fresh MFA proof for browser SSO. |
| `mfa_policy.levels` | Per-client or per-service-provider overrides merged over the global mapping. |

See [MFA Assurance Policy](mfa-assurance.md) for evaluation order, validation, and examples.

## Frontend Assets

Use `identity.frontend.assets` for template and language-resource paths.

## OIDC and SAML

Selected OIDC keys that are easy to miss:

| Path | Default | Meaning |
| --- | --- | --- |
| `identity.oidc.clients[].allow_backchannel_introspection` | `false` | Lets a static confidential client introspect other clients' `nauthilus:backchannel` service tokens. See [Token Introspection Authorization](oidc.md#token-introspection-authorization). |
| `identity.oidc.clients[].token_introspection.resources` | `[]` | RFC 8707 resource indicators owned by a static confidential resource-server client. See [Resource Servers and Resource Indicators](oidc.md#resource-servers-and-resource-indicators). |
| `identity.oidc.clients[].token_introspection.clients` | `[]` | Static clients whose plain user access tokens the resource server may introspect and which may request its resources. |
| `identity.oidc.clients[].token_introspection.dynamic_client_profiles` | `[]` | Dynamic client registration profiles (`mail-client-v1`) treated like `clients`. |
| `identity.oidc.dynamic_client_registration.access_token_type` | `opaque` | `opaque` or `jwt` access tokens for dynamic clients. |
| `identity.oidc.dynamic_client_registration.skip_consent` | `false` | Waives the consent page for all dynamic clients; `prompt=consent` still forces it. |
| `identity.oidc.dynamic_client_registration.delayed_response` | `false` | Delayed login-failure presentation for all dynamic clients, like the per-client option of static clients. |
| `identity.oidc.dynamic_client_registration.require_mfa` | `[]` | MFA methods every dynamic client user must have registered before authorization. |
| `identity.oidc.dynamic_client_registration.supported_mfa` | `[]` | MFA methods usable by dynamic clients; empty permits all. |
| `identity.oidc.dynamic_client_registration.default_scopes` | `[]` | Scopes registered when a client omits both `scope` and `grant_types`. |
| `identity.oidc.dynamic_client_registration.implied_scopes` | `[]` | Registered scopes added to every authorization of a dynamic client. |
| `identity.oidc.dynamic_client_registration.id_token_claims.mappings` | `[]` | ID-token claim mappings applied to all dynamic clients. |
| `identity.oidc.dynamic_client_registration.access_token_claims.mappings` | `[]` | Access-token claim mappings applied to all dynamic clients. |

See:

- [MFA Assurance Policy](mfa-assurance.md)
- [OIDC](oidc.md)
- [Operating OIDC Dynamic Client Registration](../../guides/oidc-dynamic-client-registration.md)
- [SAML](saml2.md)
