---
sidebar_position: 1
description: Native Identity Provider (OIDC + SAML2) overview and migration from Hydra/OAuth2
keywords: [Identity Provider, OIDC, SAML2, Migration]
---

# Identity Provider (IdP)

As of Nauthilus 1.12, Ory Hydra and the legacy OAuth2 integration have been removed. Nauthilus now ships a native Identity Provider with:

- OpenID Connect (OIDC) using the Authorization Code grant
- SAML 2.0 IdP

This section documents configuration, endpoints and migration notes.

> Migration note
>
> If you previously used Hydra: remove all oauth2/hydra settings from your configuration and add the new `idp.*` sections described here. Update reverse proxy routes to `/idp/oidc/*` and `/idp/saml/*`.

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
  oidc: { ... }
  saml2: { ... }
```

- For detailed OIDC configuration, see [OIDC](oidc.md).
- For detailed SAML2 configuration, see [SAML2](saml2.md).
- For customizing the user interface, see [Templates](templates.md).
- For a complete reference of all new IdP settings, see [Reference](reference.md).

## Related

- [OIDC (Authorization Code)](oidc.md)
- [SAML2](saml2.md)
- [Templates & Customization](templates.md)
- [Reference (all IdP settings)](reference.md)
- Release notes 1.12 (breaking changes)