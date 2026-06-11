---
title: gRPC Authority APIs
description: Typed gRPC authentication and authority backend APIs for Nauthilus
keywords: [API, gRPC, Protobuf, Authentication, AuthService, IdentityBackendService, Authority]
sidebar_position: 11
---

# gRPC Authority APIs

Nauthilus exposes typed protobuf APIs on the authority listener. The same listener can serve two use cases:

- external backchannel clients that call `nauthilus.auth.v1.AuthService`;
- Nauthilus edge instances that use `nauthilus.auth.v1.AuthService` and `nauthilus.identity.v1.IdentityBackendService` as a remote authority backend.

The AuthService reuses the same authentication pipeline as `/api/v1/auth/json` and `/api/v1/auth/cbor`: backend selection, policy evaluation, brute-force handling, Lua subject sources, post-actions, metrics, logging, cache behavior, and list-account semantics stay aligned.

The identity backend service is an internal authority surface for split edge/authority deployments. Browser clients and ordinary service clients should not call it directly.

## Listener Configuration

```yaml
runtime:
  servers:
    grpc:
      authority:
        enabled: true
        address: "127.0.0.1:9444"
        tls:
          enabled: false
          cert: ""
          key: ""
          client_ca: ""
          min_tls_version: "TLS1.2"
          require_client_cert: false
```

The default address is loopback-only. Plaintext gRPC is only accepted on loopback addresses. Use TLS and usually mTLS before exposing the listener to another host or container network.

`min_tls_version` accepts `TLS1.2` and `TLS1.3`; unset values default to `TLS1.2`. The gRPC listener always advertises HTTP/2 through ALPN and does not expose configurable cipher suites.

Timeouts are shared with HTTP authentication:

```yaml
runtime:
  timeouts:
    redis_read: 1s
    redis_write: 2s
    ldap_search: 3s
    ldap_bind: 3s
    ldap_modify: 5s
    lua_backend: 5s
    lua_script: 30s
```

## Caller Authentication

The gRPC listener uses the backchannel caller-auth configuration:

```yaml
auth:
  backchannel:
    basic_auth:
      enabled: true
      username: "backchannel"
      password: "change-me"
    oidc_bearer:
      enabled: true
```

Clients send credentials through gRPC metadata:

```text
authorization: Basic <base64(username:password)>
authorization: Bearer <access-token>
```

Caller-auth failures are transport errors such as `Unauthenticated` or `PermissionDenied`. User authentication failures are domain decisions inside successful RPC responses.

Policy-localized status messages use gRPC metadata. A client can send language preference metadata:

```text
accept-language: de-DE,de;q=0.9,en;q=0.8
```

If an auth policy selected `response_message.from: i18n`, Nauthilus resolves the key at the gRPC response boundary. A policy-selected `response_language` takes precedence over incoming `accept-language`. The response field `status_message` carries the rendered text, and Nauthilus sends response metadata when localization selected a language:

```text
content-language: de
```

## AuthService

```proto
package nauthilus.auth.v1;

service AuthService {
  rpc Authenticate(AuthRequest) returns (AuthResponse);
  rpc LookupIdentity(LookupIdentityRequest) returns (AuthResponse);
  rpc ListAccounts(ListAccountsRequest) returns (ListAccountsResponse);
}
```

### Authenticate

`Authenticate` mirrors the JSON and CBOR auth request model. `username` and `password` are required for normal password authentication. Optional request fields carry the same protocol, client, TLS, OIDC, and login-attempt metadata as the REST request fields.

Authentication failures return `decision=AUTH_DECISION_FAIL` with `ok=false`. Temporary backend or policy failures return `decision=AUTH_DECISION_TEMPFAIL`. Unexpected server errors are reported as gRPC transport errors.

### LookupIdentity

`LookupIdentity` resolves identity data without a password check. It is used by flows that already have a trusted session or need account and attribute materialization after another authority operation. In split edge/authority deployments it lets the edge resolve user attributes without local LDAP or Lua backend access.

### ListAccounts

`ListAccounts` is the gRPC equivalent of `mode=list-accounts`. It does not emulate HTTP query parameters.

### AuthResponse

```proto
enum AuthDecision {
  AUTH_DECISION_UNSPECIFIED = 0;
  AUTH_DECISION_OK = 1;
  AUTH_DECISION_FAIL = 2;
  AUTH_DECISION_TEMPFAIL = 3;
}

message AuthResponse {
  bool ok = 1;
  AuthDecision decision = 2;
  string session = 3;
  string account_field = 4;
  string totp_secret_field = 5;
  uint32 backend = 6;
  map<string, nauthilus.common.v1.AttributeValues> attributes = 7;
  string status_message = 8;
  string error = 9;
  nauthilus.common.v1.BackendRef backend_ref = 10;
}
```

`backend_ref` is present when the authority wants the caller to continue later operations against the same authority-side backend selection. The edge stores it as an opaque handle and sends it back for MFA, WebAuthn, and identity follow-up operations.

### ListAccountsResponse

```proto
message ListAccountsResponse {
  repeated string accounts = 1;
  string session = 2;
}
```

## IdentityBackendService

```proto
package nauthilus.identity.v1;

service IdentityBackendService {
  rpc ResolveUser(ResolveUserRequest) returns (UserSnapshotResponse);
  rpc GetMFAState(GetMFAStateRequest) returns (MFAStateResponse);
  rpc BeginTOTPRegistration(BeginTOTPRegistrationRequest) returns (BeginTOTPRegistrationResponse);
  rpc FinishTOTPRegistration(FinishTOTPRegistrationRequest) returns (MFAWriteResponse);
  rpc VerifyTOTP(VerifyTOTPRequest) returns (VerifyTOTPResponse);
  rpc DeleteTOTP(DeleteTOTPRequest) returns (MFAWriteResponse);
  rpc GenerateRecoveryCodes(GenerateRecoveryCodesRequest) returns (GenerateRecoveryCodesResponse);
  rpc UseRecoveryCode(UseRecoveryCodeRequest) returns (UseRecoveryCodeResponse);
  rpc DeleteRecoveryCodes(DeleteRecoveryCodesRequest) returns (MFAWriteResponse);
  rpc GetWebAuthnCredentials(GetWebAuthnCredentialsRequest) returns (WebAuthnCredentialsResponse);
  rpc SaveWebAuthnCredential(SaveWebAuthnCredentialRequest) returns (MFAWriteResponse);
  rpc UpdateWebAuthnCredential(UpdateWebAuthnCredentialRequest) returns (MFAWriteResponse);
  rpc DeleteWebAuthnCredential(DeleteWebAuthnCredentialRequest) returns (MFAWriteResponse);
}
```

This service exposes persistent identity and MFA data operations to trusted edge instances. It never returns TOTP secrets except during a fresh registration response, and it returns recovery codes only once when a new set is generated.

| RPC | Purpose |
| --- | --- |
| `ResolveUser` | Resolve released identity data, groups, attributes, MFA state, and an updated backend reference. |
| `GetMFAState` | Read public MFA state and optional public WebAuthn credential descriptors. |
| `BeginTOTPRegistration` | Create pending TOTP setup material with an idempotency key. |
| `FinishTOTPRegistration` | Verify the setup code and persist the TOTP secret on the authority side. |
| `VerifyTOTP` | Verify a TOTP code against authority-owned state. |
| `DeleteTOTP` | Remove TOTP state. |
| `GenerateRecoveryCodes` | Generate and persist a fresh recovery-code set. |
| `UseRecoveryCode` | Consume one recovery code and return the remaining count. |
| `DeleteRecoveryCodes` | Remove all recovery codes for the user. |
| `GetWebAuthnCredentials` | Read public WebAuthn credentials for ceremony setup. |
| `SaveWebAuthnCredential` | Persist a new WebAuthn credential after registration. |
| `UpdateWebAuthnCredential` | Update a credential, including sign-count changes after login. |
| `DeleteWebAuthnCredential` | Delete a credential by credential id. |

### Request Context

Identity backend requests include a `RequestContext`. It carries transport-neutral metadata from the edge:

- username and protocol metadata;
- client IP, port, hostname, and user-agent fields;
- TLS client certificate fields when available;
- OIDC client id and SAML entity id;
- login-attempt counter;
- arbitrary safe metadata attributes;
- `edge_instance`, `edge_request_id`, and `requested_language`.

The authority uses this context for logging, policy decisions, backend-reference validation, and localized safe messages.

### User Snapshot

`ResolveUser` returns a `UserSnapshot`:

| Field | Meaning |
| --- | --- |
| `username` | Resolved username. |
| `account` | Account value selected by the authority. |
| `unique_user_id` | Stable user id for IdP subject materialization. |
| `display_name` | Released display name. |
| `attributes` | Released attributes requested by the edge and allowed by policy. |
| `groups` | Released group names. |
| `group_dns` | Released group DNs. |
| `backend` | Updated backend reference. |
| `mfa` | Public MFA state. |

The `AttributeRequest` inside `ResolveUserRequest` lets the edge request specific attributes, standard identity fields, group names, group DNs, and missing-attribute diagnostics.

### MFA State

`MFAState` contains public state only:

| Field | Meaning |
| --- | --- |
| `has_totp` | Whether a TOTP secret exists. |
| `recovery_code_count` | Number of remaining recovery codes. |
| `has_webauthn` | Whether at least one WebAuthn credential exists. |
| `webauthn_credentials` | Public WebAuthn credential descriptors. |
| `preferred_method` | Authority-selected preferred MFA method. |

`WebAuthnCredential` contains credential id, public key, sign count, transports, backup flags, attestation type, display name, last-used timestamp, and raw JSON. It does not contain private key material.

## Backend References

```proto
message BackendRef {
  string type = 1;
  string name = 2;
  string protocol = 3;
  string authority = 4;
  string opaque_token = 5;
}
```

The opaque token is a handle to authority Redis state. It is not a serialized backend credential. The authority validates it on every follow-up operation.

Backend references bind to the authority-side backend, username, operation family, caller identity, and edge metadata. Missing, expired, malformed, or wrong-purpose references fail closed. Edges must not reconstruct backend state locally.

## Operation Status

Identity backend responses use a safe domain status:

```proto
enum OperationResult {
  OPERATION_RESULT_UNSPECIFIED = 0;
  OPERATION_RESULT_OK = 1;
  OPERATION_RESULT_FAIL = 2;
  OPERATION_RESULT_TEMPFAIL = 3;
  OPERATION_RESULT_DENIED = 4;
  OPERATION_RESULT_NOT_FOUND = 5;
  OPERATION_RESULT_CONFLICT = 6;
}

message OperationStatus {
  OperationResult result = 1;
  string error_code = 2;
  string safe_message = 3;
  string edge_request_id = 4;
  string authority_request_id = 5;
  repeated ErrorDetail details = 6;
}
```

Transport errors mean the RPC itself could not be accepted or completed. `OperationStatus` describes an accepted authority operation and is safe to expose to logs or user-facing error mapping when appropriate.

## Authority Scope Matrix

When caller auth uses OIDC bearer tokens, the authority checks scopes independently from the edge's local `allowed_operations` list.

| Scope | Typical RPCs |
| --- | --- |
| `nauthilus:authenticate` | `AuthService.Authenticate` |
| `nauthilus:lookup_identity` | `AuthService.LookupIdentity`, `IdentityBackendService.ResolveUser` |
| `nauthilus:list_accounts` | `AuthService.ListAccounts` |
| `nauthilus:mfa_read` | `GetMFAState`, MFA state included in `ResolveUser` |
| `nauthilus:mfa_verify` | `VerifyTOTP`, `UseRecoveryCode` |
| `nauthilus:mfa_write` | `BeginTOTPRegistration`, `FinishTOTPRegistration`, `DeleteTOTP`, `GenerateRecoveryCodes`, `DeleteRecoveryCodes` |
| `nauthilus:webauthn_read` | `GetWebAuthnCredentials`, WebAuthn credentials included in `GetMFAState` |
| `nauthilus:webauthn_write` | `SaveWebAuthnCredential`, `UpdateWebAuthnCredential`, `DeleteWebAuthnCredential` |
| `nauthilus:attribute_read` | Attribute release through `ResolveUser` |

Grant only the scopes the caller needs. For a split edge, keep the local remote backend `allowed_operations` list aligned with the authority scopes.

## grpcurl Examples

Plaintext loopback listener with Basic backchannel authentication:

```bash
grpcurl \
  -plaintext \
  -H "authorization: Basic $(printf 'backchannel:change-me' | base64)" \
  -d '{
    "username": "alice@example.test",
    "password": "secret",
    "clientIp": "198.51.100.10",
    "protocol": "imap",
    "method": "plain",
    "authLoginAttempt": 1
  }' \
  127.0.0.1:9444 \
  nauthilus.auth.v1.AuthService/Authenticate
```

Lookup identity:

```bash
grpcurl \
  -plaintext \
  -H "authorization: Bearer ${ACCESS_TOKEN}" \
  -d '{
    "username": "alice@example.test",
    "clientIp": "198.51.100.10",
    "protocol": "oidc"
  }' \
  127.0.0.1:9444 \
  nauthilus.auth.v1.AuthService/LookupIdentity
```

List accounts:

```bash
grpcurl \
  -plaintext \
  -H "authorization: Bearer ${ACCESS_TOKEN}" \
  -d '{
    "username": "alice@example.test",
    "clientIp": "198.51.100.10",
    "protocol": "account-provider"
  }' \
  127.0.0.1:9444 \
  nauthilus.auth.v1.AuthService/ListAccounts
```

## Related Documentation

- [Split Identity Proxy Configuration](configuration/identity-proxy.md)
- [Remote Authority Backend](configuration/database-backends/remote.md)
- [Building a Distributed Identity Proxy](guides/distributed-identity-proxy.md)
