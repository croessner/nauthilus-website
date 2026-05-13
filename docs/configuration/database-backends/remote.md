---
title: Remote Authority Backend
description: Configure an edge Nauthilus instance to use a remote authority as its authentication and identity backend
keywords: [Configuration, Remote Backend, Authority, gRPC, Identity Proxy, MFA, WebAuthn]
sidebar_position: 7
---

# Remote Authority Backend

The remote authority backend lets one Nauthilus instance act as an edge IdP while another Nauthilus instance owns the persistent identity backend. The edge keeps browser-facing IdP state, sessions, OIDC/SAML protocol state, and authority caller-token cache state in its own Redis. The authority keeps LDAP, Lua, test-backend, MFA, WebAuthn, backend-reference, idempotency, caller-token, and backend-cache state in its own Redis.

Use this backend when the edge instance must not contain LDAP bind credentials, Lua backend credentials, MFA secrets, recovery-code hashes, or direct access to the authority's backend Redis.

## Backend Order

A remote-only edge uses `remote` in `auth.backends.order`:

```yaml
auth:
  backends:
    order:
      - remote
    remote:
      default:
        authority: "primary"
        mode: "nauthilus"
        timeout: 5s
        allowed_operations:
          - auth
          - lookup_identity
          - list_accounts
          - mfa_read
          - mfa_verify
          - mfa_write
          - webauthn_read
          - webauthn_write
          - attribute_read
```

Named remote backends use the same order syntax as named LDAP and Lua backends:

```yaml
auth:
  backends:
    order:
      - remote(primary)
      - remote(dr)
    remote:
      primary:
        authority: "primary"
        mode: "nauthilus"
        allowed_operations: [auth, lookup_identity, list_accounts]
      dr:
        authority: "dr"
        mode: "nauthilus"
        allowed_operations: [auth, lookup_identity, list_accounts]
```

`remote` without a name resolves to `auth.backends.remote.default`.

## Fields

| Path | Required | Default | Description |
| --- | --- | --- | --- |
| `auth.backends.remote.<name>.authority` | yes | none | Name of the outbound authority client under `runtime.clients.grpc.nauthilus_authorities`. |
| `auth.backends.remote.<name>.mode` | no | `nauthilus` | Remote backend implementation. The current supported value is `nauthilus`. |
| `auth.backends.remote.<name>.timeout` | no | `5s` | Per-operation timeout for authority RPCs. Must be greater than zero and at most one minute. |
| `auth.backends.remote.<name>.allowed_operations` | yes | none | Local defense-in-depth list of remote operations that this edge backend may call. |

## Allowed Operations

| Operation | Purpose |
| --- | --- |
| `auth` | Password authentication through authority `Authenticate`. |
| `lookup_identity` | No-password identity lookup through authority `LookupIdentity` or identity `ResolveUser`. |
| `list_accounts` | Account listing through authority `ListAccounts`. |
| `mfa_read` | Read MFA state and WebAuthn public credential data. |
| `mfa_verify` | Verify TOTP or consume recovery codes. |
| `mfa_write` | Create/delete TOTP state and create/delete recovery codes. |
| `webauthn_read` | Read WebAuthn public credential descriptors. |
| `webauthn_write` | Save, update, or delete WebAuthn credentials. |
| `attribute_read` | Read requested identity attributes for OIDC or SAML claim materialization. |

The edge enforces `allowed_operations` before calling the authority. The authority still enforces caller authentication, scopes, mTLS identity, backend-reference validity, and operation permissions independently. Do not treat `allowed_operations` as the only security boundary.

## Validation Rules

Configuration validation fails when:

- `authority` is missing;
- `authority` references an unknown `runtime.clients.grpc.nauthilus_authorities.<name>`;
- `mode` is not `nauthilus`;
- `allowed_operations` is empty;
- `allowed_operations` contains an unsupported operation;
- `auth.backends.order` references `remote(<name>)` without a matching `auth.backends.remote.<name>` entry.

## Edge Credentials

A remote-only edge should not configure local LDAP or Lua backend credentials. Keep `auth.backends.ldap` and `auth.backends.lua.backend` absent unless the edge intentionally has a local fallback. For a strict split deployment, local fallback backends are usually the wrong operational model because they reintroduce backend credentials and data access into the edge tier.

The authority instance uses normal local backends:

```yaml
auth:
  backends:
    order:
      - ldap
```

or:

```yaml
auth:
  backends:
    order:
      - lua
```

The authority can also run its own public IdP endpoints when desired, but that is separate from the split edge profile.

## Backend References

Successful authority operations can return an opaque `backend_ref`. The edge stores that reference in its encrypted session and uses it for follow-up MFA, WebAuthn, and identity operations. The reference is not self-contained. The authority stores the real payload in authority Redis and validates it on every follow-up call.

Backend references bind to:

- the service principal;
- the mTLS client identity when present;
- the edge cluster;
- the username;
- the selected authority-side backend;
- the allowed operation family;
- the reference expiry.

If a backend reference is missing, expired, malformed, or not valid for the requested operation, the authority rejects the call. The edge must fail closed rather than silently falling back to local backend data.

## Edge-Owned And Authority-Owned State

| State | Owner |
| --- | --- |
| Browser sessions | Edge Redis |
| OIDC authorization-code/device-code flow state | Edge Redis |
| SAML request and response flow state | Edge Redis |
| Edge authority caller-token cache | Edge Redis |
| LDAP/Lua/test backend credentials and data | Authority |
| Authority caller access tokens | Authority Redis |
| Backend-reference payloads | Authority Redis |
| MFA secrets and recovery-code hashes | Authority backend/Redis |
| WebAuthn persistent credentials | Authority backend/Redis |
| Backend cache/idempotency outcomes | Authority Redis |

Keep these state domains separate in production network policy.
