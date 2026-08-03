---
title: MFA Assurance Policy
description: Configure MFA enrollment, challenge selection, and assurance levels for OIDC and SAML
keywords: [Identity Provider, MFA, Assurance, Step-up, OIDC, SAML2]
sidebar_position: 1.5
---

# MFA Assurance Policy

Nauthilus separates MFA enrollment from the strength of the MFA proof used for the current browser session. This lets
an application require a registered factor, restrict the factors it offers, and require a minimum assurance level
without conflating those decisions.

## The Three Policy Axes

| Setting | Scope | Meaning |
| --- | --- | --- |
| `require_mfa` | OIDC client or SAML service provider | Enrollment policy: factors that must be registered before a successful protocol response is issued. |
| `supported_mfa` | OIDC client or SAML service provider | Challenge-offer policy: registered methods that may be shown for login, registration, or step-up. |
| `required_mfa_level` | OIDC client or SAML service provider | Assurance policy: minimum level of the fresh MFA proof in the browser session. |

The supported method names are:

- `recovery_codes`
- `totp`
- `webauthn`

These settings answer different questions. Having WebAuthn registered does not satisfy `required_mfa_level: 3` until
the user has actually completed a method whose effective level is at least 3. Conversely, a strong current proof does
not bypass a `require_mfa` enrollment requirement for another factor.

When `supported_mfa` is empty, all registered and available methods remain eligible. When both `require_mfa` and
`supported_mfa` are configured, every required method must also be supported; invalid combinations are rejected during
configuration validation.

## Default Assurance Levels

The built-in mapping is:

```yaml
identity:
  mfa_policy:
    levels:
      recovery_codes: 1
      totp: 2
      webauthn: 3
```

You do not need to repeat this block to use the defaults. Configure `identity.mfa_policy.levels` only to change the
mapping.

Levels must be non-negative integers and the method name must be one of the three supported names. A client or service
provider with a positive `required_mfa_level` must allow at least one method whose effective level reaches the required
value; otherwise startup validation fails.

## Global and Local Policies

An OIDC client or SAML service provider can override individual method levels. Local entries merge over the global
mapping; omitted methods retain their global level.

```yaml
identity:
  mfa_policy:
    levels:
      recovery_codes: 1
      totp: 2
      webauthn: 3

  oidc:
    clients:
      - name: "Security Console"
        client_id: "security-console"
        client_secret: "change-me"
        redirect_uris:
          - "https://security.example.com/callback"
        scopes: ["openid", "profile"]
        grant_types: ["authorization_code"]
        token_endpoint_auth_method: "client_secret_basic"
        require_mfa: ["webauthn"]
        supported_mfa: ["webauthn"]
        required_mfa_level: 3

      - name: "Equal Rank Application"
        client_id: "equal-rank-app"
        client_secret: "change-me"
        redirect_uris:
          - "https://app.example.com/callback"
        scopes: ["openid", "profile"]
        grant_types: ["authorization_code"]
        token_endpoint_auth_method: "client_secret_basic"
        supported_mfa: ["totp", "webauthn"]
        required_mfa_level: 2
        mfa_policy:
          levels:
            webauthn: 2

  saml:
    service_providers:
      - name: "Operations Portal"
        entity_id: "https://ops.example.com/saml/metadata"
        acs_url: "https://ops.example.com/saml/acs"
        require_mfa: ["totp"]
        supported_mfa: ["totp", "webauthn"]
        required_mfa_level: 2
```

In this example, the Security Console requires an actual level-3 WebAuthn proof and requires WebAuthn enrollment. The
Equal Rank Application accepts either TOTP or WebAuthn because its local mapping ranks both at level 2. The SAML
Operations Portal requires TOTP enrollment but also permits a WebAuthn challenge.

## Browser SSO and Step-up

Nauthilus stores the completed MFA method, time, scope, and effective level with the browser session. On a later OIDC or
SAML request it evaluates the target application's effective policy:

1. Determine the registered methods allowed by `supported_mfa`.
2. If `required_mfa_level` is positive, require a fresh proof at or above that level.
3. If the proof is missing or too weak, present an eligible MFA challenge.
4. After assurance succeeds, enforce missing registrations from `require_mfa`.
5. Issue the OIDC or SAML response only after both gates succeed.

If `required_mfa_level` is zero or omitted, it imposes no numeric assurance threshold. Compatibility behavior allows a
fresh MFA-backed browser session to satisfy ordinary SSO even when a previous application named different enrollment
methods. Explicit freshness checks for security-sensitive self-service mutations remain separate and can still require
a new step-up.

### Example: Visible Step-up

Suppose application A accepts TOTP at level 2 and application B requires level 3. A user who completed TOTP for A must
see another challenge before entering B. Merely having WebAuthn registered is not enough; the user must complete an
eligible level-3 method.

## Delayed First-factor Responses

An OIDC client or SAML service provider may use `delayed_response: true` to avoid revealing the first-factor result until
after MFA. This setting changes when the password result is disclosed. It does not change `supported_mfa`, enrollment
requirements, the level mapping, or the required assurance level.

## Validation Checklist

- Use only `recovery_codes`, `totp`, and `webauthn` as policy keys and method names.
- Keep all levels and `required_mfa_level` values at or above zero.
- If `supported_mfa` is set, make `require_mfa` a subset of it.
- Ensure a positive required level is reachable by at least one supported method.
- Treat `require_mfa` as registration policy, not proof that the method was used in this session.
- Test transitions between applications with different levels, not only the initial login.

See [OIDC](oidc.md) and [SAML](saml2.md) for protocol-specific client and service-provider examples.
