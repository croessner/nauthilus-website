---
sidebar_position: 1
description: Native Identity Provider (OIDC + SAML2) overview and migration notes
keywords: [Identity Provider, OIDC, SAML2, Migration]
---

# Identity Provider (IdP)

As of Nauthilus 1.12, Nauthilus ships a native Identity Provider with:

- OpenID Connect (OIDC) using the Authorization Code, Device Authorization, and Client Credentials grants
- SAML 2.0 IdP

This section documents configuration, endpoints and migration notes.

> Migration note
>
> Remove old OAuth2-specific settings from your configuration and add the new `idp.*` sections described here. Route OIDC/SAML traffic to the native endpoints (`/oidc/*`, `/saml/*`) plus shared frontend paths such as `/login`, `/logout`, and `/mfa/*`.

## Components

- OIDC endpoints: discovery, authorize, token, userinfo, introspection, JWKS, logout
- SAML2 endpoints: metadata, SSO, SLO
- Integrated consent UI and multi-factor authentication (TOTP, WebAuthn)

## Configuration overview

Top-level IdP section in the main configuration file:

```yaml
idp:
  terms_of_service_url: "https://example.com/tos"
  privacy_policy_url: "https://example.com/privacy"
  webauthn:
    rp_display_name: "Nauthilus"
    rp_id: "localhost"
    rp_origins: ["https://localhost"]
    authenticator_attachment: "platform"
    resident_key: "preferred"
    user_verification: "preferred"
  oidc: { ... }
  saml2: { ... }
```

- For detailed OIDC configuration, see [OIDC](oidc.md).
- For detailed SAML2 configuration, see [SAML2](saml2.md).
- For customizing the user interface, see [Templates](templates.md).
- For a complete reference of all new IdP settings, see [Reference](reference.md).

## Related

- [OIDC (Authorization Code + Device Code + Client Credentials)](oidc.md)
- [SAML2](saml2.md)
- [Templates & Customization](templates.md)
- [Reference (all IdP settings)](reference.md)
- Release notes 1.12 (breaking changes)
