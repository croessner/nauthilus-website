---
title: Backends and MFA
description: Password backend, account list, TOTP, recovery code, WebAuthn, and public MFA state APIs
keywords: [Backend, TOTPBackend, RecoveryCodeBackend, WebAuthnBackend, PublicMFAStateBackend]
sidebar_position: 6
---

# Backends and MFA

All optional typed backend interfaces on this page are connected to current production IdP, API, backchannel, gRPC, or WebAuthn flows. They are not placeholder declarations. If a selected backend does not implement the interface required by an operation, the host maps it to an unknown/unsupported backend outcome. Returned errors and recovered panics become temporary backend failures.

## Password and account backend

### `BackendAuthRequest`

```go
type BackendAuthRequest struct {
    Snapshot    RequestSnapshot
    Runtime     RuntimeContext
    Credentials CredentialProvider
    Username    string
}
```

`Snapshot` and `Runtime` describe the current authentication request. `Credentials` supplies the password only when the module obtained `CapabilityCredentials`; a password backend should require that capability during registration. `Username` is the host-selected lookup/login string and can differ from later `BackendResult.Account`.

### `AccountListRequest`

```go
type AccountListRequest struct {
    Snapshot RequestSnapshot
    Runtime  RuntimeContext
    Username string
}
```

Carries request state and the account-list lookup subject. It intentionally has no credential provider.

### `AccountListResult`

```go
type AccountListResult struct {
    Status   *StatusMessage
    Accounts []string
    Facts    []PolicyFact
}
```

`Accounts` is the returned account set/list. `Status` text/key are applied and `Status.Temporary` can force temporary failure. `Facts` are recorded, but current account-list adapter validation is weaker than source fact validation: it normalizes non-empty IDs and compatible values without equivalent registry/stage/type enforcement.

### `Backend`

```go
type Backend interface {
    Name() string
    VerifyPassword(context.Context, BackendAuthRequest) (BackendResult, error)
    ListAccounts(context.Context, AccountListRequest) (AccountListResult, error)
}
```

`Name` must be a unique valid local component name. `VerifyPassword` returns the complete [backend result](./results.md#backendresult). `ListAccounts` implements account-provider operations. Both run synchronously, are panic-protected, and must honor cancellation. The host invokes only registered backends.

## TOTP

### Request and result structs

| Type and fields | Meaning |
| --- | --- |
| `TOTPBeginRequest { Snapshot, Runtime, IdempotencyKey, Username }` | Starts registration. `IdempotencyKey` lets the backend make retries safe; `Username` is the subject. |
| `TOTPBeginResult { Status, BackendServer, ExpiresAt, PendingRegistrationID, OTPAuthURL }` | Returns status, serving backend, expiry, opaque pending ID, and `otpauth:` enrollment URL. Treat the URL and pending ID as secrets. |
| `TOTPFinishRequest { Snapshot, Runtime, IdempotencyKey, Username, PendingRegistrationID, Code }` | Completes registration with the opaque pending ID and user code. `Code` is secret authentication material. |
| `TOTPFinishResult { Status, BackendServer, Verified }` | Reports serving backend and whether completion/code verification succeeded. |
| `TOTPVerifyRequest { Snapshot, Runtime, Username, Code }` | Verifies one TOTP code. |
| `TOTPVerifyResult { Status, BackendServer, Verified }` | Reports serving backend and verification outcome. |
| `TOTPDeleteRequest { Snapshot, Runtime, IdempotencyKey, Username }` | Deletes TOTP state idempotently. |

`ExpiresAt` is a `time.Time`; zero means no declared expiry. All `Snapshot` and `Runtime` fields have the common semantics. Current typed-MFA adapters apply status text/key but ignore `Status.Temporary`.

### `TOTPBackend`

```go
type TOTPBackend interface {
    BeginTOTP(context.Context, TOTPBeginRequest) (TOTPBeginResult, error)
    FinishTOTP(context.Context, TOTPFinishRequest) (TOTPFinishResult, error)
    VerifyTOTP(context.Context, TOTPVerifyRequest) (TOTPVerifyResult, error)
    DeleteTOTP(context.Context, TOTPDeleteRequest) error
}
```

Implement this optional interface on the same object registered as `Backend`. The host routes TOTP operations to it. Writes on selected-edge/non-owning paths can be rejected by the host; preserve idempotency and backend affinity using the supplied key and returned server ref.

## Recovery codes

### Request and result structs

| Type and fields | Meaning |
| --- | --- |
| `RecoveryCodeGenerateRequest { Snapshot, Runtime, IdempotencyKey, Username, Count }` | Requests `Count` new recovery codes. Enforce a safe backend-specific non-zero maximum. |
| `RecoveryCodeGenerateResult { Status, BackendServer, Codes }` | Returns serving backend and newly generated one-time codes. `Codes` are credentials and must be shown/stored only through the intended secure flow. |
| `RecoveryCodeUseRequest { Snapshot, Runtime, IdempotencyKey, Username, Code }` | Atomically attempts to consume one code. |
| `RecoveryCodeUseResult { Status, BackendServer, Valid, Remaining }` | Reports whether consumption succeeded and remaining count. Use non-negative `Remaining`; no additional public validation guarantees it. |
| `RecoveryCodeDeleteRequest { Snapshot, Runtime, IdempotencyKey, Username }` | Idempotently removes all recovery codes. |

All named fields are public struct fields. Current typed-MFA status handling applies text/key and ignores `Status.Temporary`.

### `RecoveryCodeBackend`

```go
type RecoveryCodeBackend interface {
    GenerateRecoveryCodes(context.Context, RecoveryCodeGenerateRequest) (RecoveryCodeGenerateResult, error)
    UseRecoveryCode(context.Context, RecoveryCodeUseRequest) (RecoveryCodeUseResult, error)
    DeleteRecoveryCodes(context.Context, RecoveryCodeDeleteRequest) error
}
```

`UseRecoveryCode` must be atomic so concurrent retries cannot consume one code twice. Treat returned codes and request codes as secrets. Selected-edge write restrictions also apply.

## WebAuthn

### `WebAuthnCredential`

```go
type WebAuthnCredential struct {
    LastUsed       time.Time
    ID             []byte
    PublicKey      []byte
    Transports     []string
    AAGUID         string
    Attestation    string
    Authenticator  string
    SignCount      uint32
    BackupState    bool
    BackupEligible bool
}
```

| Field | Meaning |
| --- | --- |
| `LastUsed` | Last successful use time; zero means unknown. |
| `ID` | Binary credential ID. Copy before retention. |
| `PublicKey` | Serialized credential public key. Public cryptographic material, but still account-sensitive. |
| `Transports` | WebAuthn transport identifiers. |
| `AAGUID` | Authenticator attestation GUID text. |
| `Attestation` | Attestation type/metadata text used by the host. |
| `Authenticator` | Authenticator name/type text. |
| `SignCount` | Signature counter. Updates must preserve anti-cloning semantics. |
| `BackupState` | Credential is currently backed up. |
| `BackupEligible` | Credential is eligible for backup/sync. |

The public API does not perform field-level WebAuthn validation. The plugin/backend must preserve IDs and keys exactly and enforce storage constraints.

### Request and result structs

| Type and fields | Meaning |
| --- | --- |
| `WebAuthnListRequest { Snapshot, Runtime, Username }` | Requests all usable credentials for a subject. |
| `WebAuthnListResult { Status, BackendServer, Credentials }` | Returns serving backend and credential values. |
| `WebAuthnSaveRequest { Snapshot, Runtime, Username, Credential }` | Persists one newly registered credential. |
| `WebAuthnUpdateRequest { Snapshot, Runtime, Username, OldCredential, NewCredential }` | Atomically replaces old state, commonly after signature-counter/backup-state changes. |
| `WebAuthnDeleteRequest { Snapshot, Runtime, Username, CredentialID }` | Deletes the credential with the binary ID. |

Every brace member above is an exported struct field. Byte slices and nested slices are request/result-local values; do not mutate inputs to signal host changes.

### `WebAuthnBackend`

```go
type WebAuthnBackend interface {
    ListWebAuthnCredentials(context.Context, WebAuthnListRequest) (WebAuthnListResult, error)
    SaveWebAuthnCredential(context.Context, WebAuthnSaveRequest) error
    UpdateWebAuthnCredential(context.Context, WebAuthnUpdateRequest) error
    DeleteWebAuthnCredential(context.Context, WebAuthnDeleteRequest) error
}
```

Implement on the registered backend object. The list result can influence login/registration flows; writes must be atomic and idempotent where the protocol can retry.

## Public MFA state

### `PublicMFAStateRequest`

```go
type PublicMFAStateRequest struct {
    Snapshot        RequestSnapshot
    Runtime         RuntimeContext
    Username        string
    IncludeWebAuthn bool
}
```

`IncludeWebAuthn` tells the backend whether public WebAuthn credential metadata is required; false permits a cheaper summary-only read. Do not return secret TOTP seeds or recovery code values.

### `PublicMFAStateResult`

```go
type PublicMFAStateResult struct {
    Status              *StatusMessage
    BackendServer       *BackendServerRef
    WebAuthnCredentials []WebAuthnCredential
    RecoveryCodeCount   int
    HasTOTP             bool
    HasWebAuthn         bool
}
```

| Field | Meaning |
| --- | --- |
| `Status` | Status text/key; typed-MFA adapter ignores `Temporary`. |
| `BackendServer` | Serving backend affinity. |
| `WebAuthnCredentials` | Public/account-safe credential metadata when requested. |
| `RecoveryCodeCount` | Count only, never code values. Use a non-negative value. |
| `HasTOTP` | TOTP is enrolled. |
| `HasWebAuthn` | At least one WebAuthn credential exists. |

### `PublicMFAStateBackend`

```go
type PublicMFAStateBackend interface {
    PublicMFAState(context.Context, PublicMFAStateRequest) (PublicMFAStateResult, error)
}
```

This read interface is used at public identity edges. “Public” means safe for that API purpose, not safe for unrestricted logs or analytics; MFA enrollment remains account-security metadata.
