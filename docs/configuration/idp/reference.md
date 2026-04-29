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

## Frontend Assets

Use `identity.frontend.assets` for template and language-resource paths.

## OIDC and SAML

See:

- [OIDC](oidc.md)
- [SAML](saml2.md)
