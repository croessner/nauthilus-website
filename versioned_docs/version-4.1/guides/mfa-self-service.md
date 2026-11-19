---
title: MFA Self-Service Portal
description: User and operator flow for signing in, enrolling, and managing TOTP, WebAuthn, and recovery codes
keywords: [MFA, 2FA, Self-Service, TOTP, WebAuthn, Recovery Codes, Sessions]
sidebar_position: 8
---

# MFA Self-Service Portal

The integrated self-service portal lets a user authenticate and manage their own MFA factors. The entry route is:

```text
/mfa/register/home
/mfa/register/home/{languageTag}
```

The localized route keeps the selected language throughout login, enrollment, device management, and recovery-code
pages. Do not send users directly to `/login`: a normal login page requires a valid OIDC, SAML, device, or internal
self-service flow.

## User journey

```mermaid
sequenceDiagram
  participant U as User browser
  participant N as Nauthilus frontend
  participant S as Typed Redis session stores
  participant B as Selected identity backend

  U->>N: GET /mfa/register/home/de
  N->>S: Create or resume bounded self-service login flow
  N-->>U: 302 /login/de?flow=opaque-ticket
  U->>N: POST username and password
  N->>B: Authenticate through the selected backend
  B-->>N: Identity and backend reference
  N->>S: Rotate browser session; consume login flow
  N-->>U: 303 /mfa/register/home/de
  N-->>U: 302 /login/mfa?flow=opaque-ticket when a factor is enrolled
  U->>N: Complete TOTP, WebAuthn, or recovery-code challenge
  N-->>U: Portal home
  U->>N: Enroll or manage a factor
  N->>S: Require self-service-scoped fresh MFA for sensitive mutations
  N-->>U: Portal result or MFA step-up
```

An anonymous portal entry creates a fresh canonical session anchor and a typed internal login flow with a bounded
lifetime. A successful primary login rotates the browser envelope, publishes the authenticated identity and selected
backend reference server-side, consumes the one-shot login flow, and redirects to the protected portal. The browser
cookie is an authenticated opaque reference; it does not contain identity, factors, credentials, continuation targets,
or ceremony state.

A password alone does not open the portal for a user who already has a factor. When the authenticated session has no
fresh self-service assurance (scope `self-service`, level 1 or higher) and the selected backend reports at least one
enrolled TOTP, WebAuthn, or recovery-code factor, the portal home starts a step-up and redirects to
`/login/mfa?flow=opaque-ticket`. The challenge offers every enrolled method. After a successful challenge the user
returns to the portal home. Users without any enrolled factor reach the portal directly after the password login so
they can enroll their first factor. If factor availability cannot be read from the backend, the portal answers `503`.

## Available operations

| Area | User operation | Main routes |
| --- | --- | --- |
| TOTP | Enroll a TOTP secret; delete the current TOTP factor. | `GET/POST /mfa/totp/register`, `DELETE /mfa/totp` |
| WebAuthn | Register a passkey/security key; list, rename, or delete credentials. | `/mfa/webauthn/register*`, `GET /mfa/webauthn/devices`, `POST .../name`, `DELETE .../device/{id}` |
| Recovery codes | Enroll, save, or replace recovery codes. | `/mfa/recovery/register*`, `POST /mfa/recovery/generate` |

Every route also has a localized `/{languageTag}` form. The UI carries opaque flow and ceremony tickets in local query
parameters where required. Operators and applications must not create, rewrite, persist, or interpret those values.

Recovery codes are one-time credentials. Replacement invalidates the old set. At least one TOTP or WebAuthn factor
must remain active before recovery codes can be generated. Users should save new codes through the supplied page before
continuing; the server never exposes stored recovery-code hashes.

## Enrollment started by an application

OIDC clients and SAML service providers can require factor enrollment with `require_mfa`. After successful login or
step-up, Nauthilus checks each required method and sends the user through the missing registrations in order:

```text
/mfa/totp/register
/mfa/webauthn/register
/mfa/recovery/register
/mfa/register/continue
```

`require_mfa` is enrollment policy. `supported_mfa` controls methods offered for a challenge, while
`required_mfa_level` controls the strength of the fresh proof. A registered high-assurance factor does not satisfy an
assurance gate until the user actually completes it, and a strong proof does not invent another required enrollment.

See [MFA Assurance Policy](../configuration/idp/mfa-assurance.md) for the configuration model.

## Step-up for sensitive portal changes

Sensitive portal mutations do not reuse an arbitrary fresh OIDC or SAML proof. Nauthilus requires assurance with the
exact `self-service` scope and at least level 1.

When that proof is absent or stale, Nauthilus stores one typed operation bound to the current session and identity, then
redirects the browser to `/login/mfa?flow=opaque-ticket`. The challenge offers only factors proven available from the
selected backend. Successful TOTP, WebAuthn, or recovery verification commits self-service-scoped assurance and returns
to the bound mutation surface.

The stored operation contains only bounded server-owned data needed to finish the action. For example, a WebAuthn
rename binds the credential reference and new device name to the step-up record and uses
`/mfa/self-service/continue` after assurance. A user-controlled return URL is never accepted.

## Code verification attempt budget

TOTP and recovery-code verification share one Redis-backed budget of ten admitted attempts per stable identity in a
fixed five-minute window. Each attempt is reserved atomically before the code is checked, including attempts that
succeed. Switching IP addresses, methods, or browser challenges does not reset the budget.

- An exhausted budget returns HTTP `429` without invoking the verifier.
- If the budget storage is unavailable, Nauthilus returns HTTP `503` without invoking the verifier.

The identity authority enforces the same budget before its direct TOTP and recovery-code operations. In split
deployments the edge and the authority each keep their own identity-bound reservation; when both resolve to the same
Redis key, one verification consumes both reservations. WebAuthn assertions do not use this budget.

## Retry behavior

Retry semantics depend on the operation:

- An invalid TOTP enrollment code keeps the pending secret and operation available for a corrected code. It does not
  create a second backend enrollment.
- Repeating a successful TOTP enrollment submission resumes the required-MFA chain idempotently instead of registering
  the factor twice.
- A wrong TOTP or recovery-code challenge renders a new bounded form and preserves the typed step-up binding for another
  attempt. The browser must use the newly issued CSRF token.
- WebAuthn assertions and attestations are single-use. A missing, expired, kind-mismatched, or binding-mismatched
  ceremony fails closed. Restart with the matching begin route; never replay the rejected browser payload.
- Optional WebAuthn registration from the portal is bound to the authenticated self-service session. Deleting or
  renaming a device refreshes the cached device list, and a stale concurrent update of the same credential is rejected
  instead of overwriting newer state.
- A completed step-up ticket is single-use. Replaying it, changing its operation, or presenting it from another session
  fails closed.
- A backend mutation uses a server-generated operation identity. If the outcome is uncertain, reconcile the selected
  backend before asking the user to repeat the mutation.

## Expired and missing sessions

The portal entry is restartable; protected continuations are not.

- Visiting `/mfa/register/home[/languageTag]` without a usable session starts a new bounded self-service login flow and
  redirects to the matching localized login page.
- Visiting another protected self-service route without a live authenticated canonical session returns `401` with the
  `self_service_session_expired` page. The user must sign in again through the portal entry.
- An expired or invalid flow/step-up/ceremony ticket is not reconstructed from browser input. Start again from the
  nearest safe entry point.
- Login completion rotates the browser session. The pre-authentication cookie and consumed flow cannot be reused.
- Logout and session revocation invalidate the server-side anchor and its indexed child records.

The portal's restart message may tell the user to reopen 2FA self-service from their application. Applications should
link to the portal home, not preserve a prior `flow` or `ceremony` query string.

## Distributed identity deployments

In split edge/authority mode, the edge hosts the browser flow while the authority owns credential persistence. The
session keeps the final subject, factor identity, backend name, and opaque backend reference selected during
authentication. Enrollment and self-service mutations must use that same authority and backend; they must not select a
new backend from browser input.

The edge and authority must run compatible canonical session, API, and artifact generations. Avoid mixed rolling
traffic between binaries that disagree on the envelope or typed store contract. Legacy browser-session records and
retired WebAuthn ceremony cookies are not fallback inputs.

## Operator verification

Exercise the real browser path through the deployment's reverse proxy:

1. Open the localized portal home without cookies and verify a same-origin redirect to localized `/login` with an
   opaque flow ticket.
2. Authenticate and verify session rotation, a `303` back to the portal, and the authenticated account view.
3. Enroll TOTP with one wrong code followed by the correct code; confirm the secret remains retryable and is stored once.
4. Register WebAuthn, then prove that replaying the finish request fails and a fresh begin succeeds.
5. Generate and save recovery codes, use one for a step-up, and verify that it cannot be reused.
6. Trigger a sensitive delete, rename, or replacement without fresh self-service assurance and verify the bound MFA
   selection/return path.
7. Expire or revoke the session, confirm protected routes return the explicit expired-session page, then restart from
   portal home.
8. In split mode, prove that every mutation reaches the originally selected authority/backend and survives neither
   cross-session nor cross-account ticket reuse.

Do not log passwords, TOTP secrets/codes, recovery codes, WebAuthn challenges/assertions, credential IDs, cookies, or
opaque flow handles. Use bounded route/result classes and server-side correlation instead.
