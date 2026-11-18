---
title: Server Internals
description: Developer notes on how the CSRF middleware, the IdP MFA flow, the browser session contract, MFA cache invalidation, and the backchannel authentication state machine work
keywords: [Nauthilus, Developer, Internals, CSRF, MFA, WebAuthn, Browser Session, FSM, ADR]
sidebar_position: 1
---

# Server Internals

These notes describe how parts of the Nauthilus server work on the inside. They are written for developers who change
those parts, and for reviewers and operators who need the exact behavior when they debug a regression. Paths such as
`server/...` name files in the Nauthilus source repository; they are not links on this site, because they point at
source code.

| Document | What it covers |
| --- | --- |
| [CSRF Middleware API](./csrf-middleware.md) | The `server/middleware/csrf` package: the double-submit cookie with one-time-pad token masking, origin validation, the options, and the replaceable interfaces. |
| [IDP MFA Flow Developer Notes](./idp-mfa-flow.md) | How the frontend handlers move through first factor, MFA, required-MFA registration, and WebAuthn continuation. A debugging aid for regressions where the browser is sent back to `/login`, `/login/webauthn`, or `/mfa/*/register` although an OIDC or SAML flow should resume. |
| [Browser Session Contract Inventory](./browser-session-contract.md) | The canonical opaque browser envelope, the owner of every legacy session field, and how legacy Redis data is treated after the cutover. |
| [MFA Writes and Cached Identity State](./mfa-cache-consistency.md) | Which caches are invalidated after TOTP, recovery-code, and WebAuthn writes, and how the consumption of a recovery code stays single-use. |
| [Auth Backchannel FSM ADR](./auth-backchannel-fsm-adr.md) | The accepted decision on the marker vocabulary and the transition matrix of the backchannel authentication state machine. |

## Related pages

- [Redis Keyspace Reference](../data-stores/redis-keyspace.md#311-browser-sessions-and-flows) lists the Redis keys of
  browser sessions and flows.
- [Canonical Browser Session Migration](../../guides/browser-session-migration.md) explains the cutover from the
  operator's side.
- [MFA Self-Service Portal](../../guides/mfa-self-service.md) and
  [MFA Assurance Policy](../../configuration/idp/mfa-assurance.md) describe the MFA behavior that the flow notes
  implement.
- [Policy Configuration](../../configuration/auth-policy.md) describes the policy material that selects the markers of
  the backchannel state machine.
