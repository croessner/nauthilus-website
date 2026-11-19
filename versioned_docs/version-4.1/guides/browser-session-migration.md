---
title: Canonical Browser Session Migration
description: Roll out the v4 opaque browser envelope and typed Redis session stores without mixed runtimes
keywords: [Sessions, Redis, OIDC, SAML, MFA, Migration]
sidebar_position: 7
---

# Canonical Browser Session Migration

Nauthilus v4 has one browser-state authority: a versioned authenticated opaque envelope that references a server-side
session anchor. The cookie never contains identity, OIDC/SAML requests, MFA state, credentials, recovery material,
redirect targets, backend affinity, or WebAuthn ceremonies.

All browser business state is stored in typed Redis records owned by the anchor. There is no legacy dual-read,
dual-write, translation, backfill, or fallback path.

## State ownership

The typed store separates these record families:

- session anchor and authenticated identity;
- OIDC and SAML flows;
- internal MFA self-service login flows;
- required-MFA enrollments and dynamic step-up operations;
- WebAuthn ceremonies;
- TOTP and recovery-code operations;
- consent, logout, and protocol-session indexes.

Redis keys use a keyed digest of the session and record handles. Raw handles do not appear in keys. The shared keyed
session digest is the Redis Cluster hash tag, keeping an anchor and its coordinated children in one slot while each
owner remains separately versioned, bounded, and expiring.

Records use revision compare-and-swap, explicit expiry plus Redis PTTL, parent/session binding, and fail-closed orphan
handling. WebAuthn challenges and other one-shot operations are consumed atomically. Revocation publishes an anchor
tombstone before bounded child cleanup. Before a new browser flow is committed, index entries whose child record is
missing or expired are removed, so expired sibling flows do not block a new login.

Stale browser state is reported separately from storage failures. During login completion and MFA handling, a revision
conflict, a revoked record, a missing record, or a login completion whose parent flow disappeared answers HTTP
`409 Conflict`; the user restarts from the protocol or self-service entry point. HTTP `503` is reserved for
unavailable session storage. Monitor the two statuses separately: a `409` usually means a double submit, a second tab,
or an expired flow, not an outage.

## Removed compatibility surfaces

The following are not v4 browser-session APIs:

- legacy secure-cookie payloads or legacy `SessionKey*` fields;
- legacy browser/session reference adapters or hybrid stores;
- the retired session-cookie routes below `/api/v1/mfa/*`;
- retired WebAuthn ceremony cookies;
- old Redis flow records as authentication or continuation input.

The machine-oriented `/api/v1/mfa-backchannel/*` family is separate, scoped, cookie-free, and remains supported. The
interactive portal uses the canonical `/mfa/*` browser routes documented in
[MFA Self-Service Portal](mfa-self-service.md).

## Uniform replacement is mandatory

All replicas that can receive one browser journey must agree on the v4 envelope, typed stores, route set, and active
Policy generation. Do not alternate traffic between v3.1 and v4, or between partial v4 builds with different session
contracts.

Use this rollout sequence:

1. Validate the v4 configuration, Redis connectivity, frontend encryption secret, artifact snapshot, and Policy
   generation without serving browser traffic.
2. Drain or isolate the old browser-serving replicas.
3. Replace the complete browser-serving pool with one exact v4 build and configuration generation.
4. Confirm that no old binary can receive OIDC, SAML, login, MFA, self-service, consent, logout, or ceremony traffic.
5. Exercise fresh OIDC and SAML entries, parallel flows, MFA enrollment/step-up, logout, and session expiry.
6. Keep rollback as a uniform replacement. Never mix the old and new runtimes to preserve an in-flight browser flow.

Existing v3.1 browser sessions and flows are intentionally not migrated. Users restart at the appropriate protocol or
self-service entry point. Legacy, malformed, or unrecognized cookies are removed; missing or inconsistent canonical
records fail closed.

## Legacy Redis records

Old records are inert and may expire under their existing TTLs. Their presence is not a correctness problem, and the
request path must not scan or delete them.

After a verified no-mix rollout, operators may optionally use the fixed-allowlist cleanup tool from the exact Nauthilus
source release. It reports only aggregate counts and defaults to dry-run:

```bash
GOEXPERIMENT=runtimesecret go run ./contrib/session-keyspace-retirement \
  --redis-address 127.0.0.1:6379 \
  --base-prefix 'nauthilus:'
```

Deletion requires an explicit second run with `--apply`. Use it only after proving that no v3.1 binary serves traffic,
the base prefix is exact, current sessions are healthy, and rollback does not depend on the old runtime. The tool is
limited to the old `<base-prefix>idp:flow:` namespace and does not touch the current `browser-session` keyspace.

Cleanup is housekeeping, not a v4 startup step or migration prerequisite. Do not delete Redis data broadly.

## Verification matrix

| Boundary | Required evidence |
| --- | --- |
| Cookie | One bounded opaque v1 envelope; no identity, protocol, MFA, or ceremony material. |
| Entry routes | OIDC/SAML/self-service entries can create a new anchor; continuations reject a missing envelope. |
| Typed records | Parent/session/owner/revision/expiry mismatches fail closed; one-shot records cannot replay. |
| Parallel flows | OIDC and SAML child records coexist without overwriting each other. |
| MFA | Enrollment, step-up, self-service, recovery, and WebAuthn use typed state and safe restart points. |
| Route inventory | No `/api/v1/mfa/*` browser-management route; scoped `/api/v1/mfa-backchannel/*` remains cookie-free. |
| Rollout | Every browser-serving replica reports the same exact source/build and contract generation. |
| Legacy state | Old keys are ignored by runtime; any optional cleanup is dry-run-first and explicitly bounded. |

Treat any executable path that reads legacy browser state, writes both formats, or requires cleanup for correctness as a
release blocker.
