---
sidebar_position: 1
description: Identity configuration in config v2
keywords: [Identity Provider, OIDC, SAML2, MFA]
---

# Identity

Browser-facing identity settings now live entirely below `identity`.

## Main Structure

```yaml
identity:
  session: {}
  frontend: {}
  mfa: {}
  oidc: {}
  saml: {}
```

This replaces the older split where IdP-related options were spread across `idp` and `server.frontend`.

## Sections

- `identity.session`: remember-me/session behavior
- `identity.frontend`: templates, assets, links, localization, security headers
- `identity.mfa`: TOTP and WebAuthn settings
- `identity.oidc`: native OpenID Connect provider
- `identity.saml`: native SAML IdP

## Example

```yaml
identity:
  session:
    remember_me_ttl: 720h
  frontend:
    enabled: true
    assets:
      html_static_content_path: "/etc/nauthilus/static"
      language_resources: "/etc/nauthilus/resources"
    localization:
      languages:
        - "en"
        - "de"
      default_language: "en"
    links:
      terms_of_service_url: "https://example.com/tos"
      privacy_policy_url: "https://example.com/privacy"
      password_forgotten_url: "https://example.com/forgot-password"
  mfa:
    totp:
      issuer: "Nauthilus"
      skew: 1
    webauthn:
      rp_display_name: "Nauthilus"
      rp_id: "idp.example.com"
      rp_origins:
        - "https://idp.example.com"
  oidc:
    enabled: true
    issuer: "https://idp.example.com"
  saml:
    enabled: true
    entity_id: "https://idp.example.com/saml"
```

## Related Pages

- [OIDC](oidc.md)
- [SAML](saml2.md)
- [Reference](reference.md)
- [Templates](templates.md)
