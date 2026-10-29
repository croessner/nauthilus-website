---
title: Runtime and Request Values
description: Complete RequestSnapshot, TLS, runtime context, credential, and secret reference
keywords: [RequestSnapshot, RuntimeContext, RuntimeDelta, CredentialProvider, Secret]
sidebar_position: 3
---

# Runtime and Request Values

The root API passes copied, value-oriented request data to plugins. Struct fields are public surface; whether they are populated depends on the adapter and invocation point. Empty strings, zero values, empty collections, and `nil` interfaces must always be handled.

## `IDPInfo`

```go
type IDPInfo struct {
    RequestedScopes         []string
    UserGroups              []string
    AllowedClientScopes     []string
    AllowedClientGrantTypes []string
    GrantType               string
    ClientID                string
    ClientName              string
    RedirectURI             string
    MFAMethod               string
    MFACompleted            bool
}
```

| Field | Meaning |
| --- | --- |
| `RequestedScopes` | Scopes requested by the current identity-provider flow. |
| `UserGroups` | Groups known for the subject at this stage. |
| `AllowedClientScopes` | Scopes configured for the resolved client. |
| `AllowedClientGrantTypes` | Grant types configured for the resolved client. |
| `GrantType` | Current OAuth/OIDC grant type. |
| `ClientID` | Resolved identity-provider client ID. |
| `ClientName` | Resolved display name of that client. |
| `RedirectURI` | Current validated redirect URI when applicable. Treat as sensitive/high-cardinality. |
| `MFAMethod` | Current MFA method identifier. |
| `MFACompleted` | Whether MFA has completed in the current flow. |

These values are populated only on relevant IdP paths and only when known at the extension stage. The custom-hook adapter currently leaves all `IDP` fields empty.

## `RequestDiagnostics`

```go
type RequestDiagnostics struct {
    StatusMessage     string
    BruteForceName    string
    EnvironmentName   string
    LatencyMillis     int64
    BruteForceCounter uint
    HTTPStatus        int
}
```

| Field | Meaning |
| --- | --- |
| `StatusMessage` | Current host status text, if one exists. It may be user-visible and must not be treated as a stable code. |
| `BruteForceName` | Name of the applicable brute-force rule/check. |
| `EnvironmentName` | Environment source/check diagnostic name. |
| `LatencyMillis` | Bounded current request latency in milliseconds. |
| `BruteForceCounter` | Current brute-force counter. |
| `HTTPStatus` | Current HTTP status when an HTTP-facing path has one. |

All fields are public surface. Population is adapter- and stage-dependent; custom hooks currently leave the complete struct at zero values.

## `RequestSnapshot`

```go
type RequestSnapshot struct {
    Headers           map[string][]string
    IDP               IDPInfo
    Session           string
    ExternalSessionID string
    Service           string
    Protocol          string
    Method            string
    Username          string
    Account           string
    AccountField      string
    UniqueUserID      string
    DisplayName       string
    ClientIP          string
    ClientPort        string
    ClientNet         string
    ClientHost        string
    ClientID          string
    UserAgent         string
    LocalIP           string
    LocalPort         string
    OIDCCID           string
    SAMLEntityID      string
    AuthLoginAttempt  uint
    TLS               TLSInfo
    Diagnostics       RequestDiagnostics
    Runtime           RuntimeFlags
    HealthCheck       bool
}
```

### Field reference

| Field | Meaning and production population |
| --- | --- |
| `Headers` | Copied request headers. Authorization, proxy-authorization, cookie, and configured password-bearing headers are removed rather than replaced. Never assume every adapter has headers. |
| `IDP` | Safe IdP inputs described above. Broadly populated on IdP flows; empty for custom hooks today. |
| `Session` | Host request/session correlation ID. Sensitive even though exposed. Auth and hook adapters populate it when available. |
| `ExternalSessionID` | External correlation/session ID; broad auth adapter may populate it, hook adapter does not. |
| `Service` | Nauthilus service name. The hook adapter sets exactly `custom_hook`. |
| `Protocol` | Protocol identifier. The hook adapter sets exactly `http`. |
| `Method` | Current operation/method; hook adapter also supplies the actual HTTP method separately in `HookRequest.Method`. |
| `Username` | Current login/subject string. Hook adapter uses the bearer subject when one was authenticated. |
| `Account` | Resolved account value, if known; hook adapter leaves empty. |
| `AccountField` | Backend attribute name that supplied `Account`; must be printable ASCII when returned by a backend. Hook adapter leaves empty. |
| `UniqueUserID` | Resolved stable subject identifier, if known; hook adapter leaves empty. |
| `DisplayName` | Resolved display name, if known; hook adapter leaves empty. |
| `ClientIP` | Client address string. Hook adapter derives it from the HTTP request. Validate before network decisions. |
| `ClientPort` | Client source port string. Hook adapter derives it from the HTTP request. |
| `ClientNet` | Host-scoped client network string; hook adapter currently leaves empty. |
| `ClientHost` | Resolved/observed client host string. Hook adapter can populate it. |
| `ClientID` | General client identifier from the auth state; not the same field as `IDP.ClientID`. Hook adapter leaves empty. |
| `UserAgent` | Copied user-agent string. Attacker-controlled and high-cardinality. |
| `LocalIP` | Local listener address, if the adapter supplies it; hook adapter leaves empty. |
| `LocalPort` | Local listener port, if supplied; hook adapter leaves empty. |
| `OIDCCID` | OIDC client correlation ID. Hook bearer authentication derives it from `client_id`, then `azp`, then `sub` when available. |
| `SAMLEntityID` | SAML entity ID on applicable paths; hook adapter leaves empty. |
| `AuthLoginAttempt` | Current authentication attempt counter; hook adapter leaves zero. |
| `TLS` | Normalized TLS data. Auth adapter broadly supplies it; hook adapter currently leaves it zero. |
| `Diagnostics` | Current bounded outcome metadata; hook adapter leaves zero. |
| `Runtime` | Copied host-derived flags. Hook adapter currently sets only `Authenticated` when its authentication path succeeds. |
| `HealthCheck` | Whether this is a health-check path; hook adapter currently leaves false. |

The normal authentication adapter broadly fills fields from the host request
state. `Runtime.LocalRequest` is currently an alias of the internal no-auth
condition. Both `EnvironmentStageExpected` and `SubjectStageExpected` are
currently derived only from configured Lua sources, not from the native Go
source plans.

### Ownership and security

Maps and slices are request-local copies at the production boundary. Mutating them neither updates Nauthilus nor constitutes a supported result channel. Treat the snapshot as immutable. It contains no password, but many fields remain sensitive or attacker-controlled; do not copy it wholesale into logs, traces, metrics, runtime deltas, policy facts, or hook responses.

## `TLSLegacyInfo`

```go
type TLSLegacyInfo struct {
    State            string
    SessionID        string
    ClientVerify     string
    ClientDN         string
    ClientCommonName string
    Issuer           string
    ClientNotBefore  string
    ClientNotAfter   string
    SubjectDN        string
    IssuerDN         string
    ClientSubjectDN  string
    ClientIssuerDN   string
    Protocol         string
    CipherSuite      string
    Serial           string
    Fingerprint      string
}
```

These fields preserve safe value copies of the legacy `ssl_*` request vocabulary: TLS state, session identifier, client verification result, client/subject/issuer distinguished names, client common name, validity bounds, negotiated protocol and cipher, certificate serial, and fingerprint. Values are strings because this is a compatibility view; plugins must not infer cryptographic verification from text alone.

## `TLSInfo`

```go
type TLSInfo struct {
    Legacy         TLSLegacyInfo
    ServerName     string
    CipherSuite    string
    PeerCommonName string
    PeerIssuer     string
    Version        string
    VerifiedChains int
    Enabled        bool
    Mutual         bool
}
```

| Field | Meaning and current adapter note |
| --- | --- |
| `Legacy` | Legacy compatibility values above. |
| `ServerName` | Accepted server-name value. The current auth adapter derives this from the legacy subject-DN field rather than a Go TLS `ServerName`. |
| `CipherSuite` | Normalized negotiated cipher identifier. |
| `PeerCommonName` | Normalized peer common name. |
| `PeerIssuer` | Normalized peer issuer. |
| `Version` | Normalized TLS version. |
| `VerifiedChains` | Count-like verification signal. Current adapter produces `1` only for legacy verification text `SUCCESS`, otherwise `0`; it is not the literal number of Go verified chains. |
| `Enabled` | TLS was accepted/enabled for the request. |
| `Mutual` | Mutual/client-certificate TLS condition. |

No certificate or private-key material crosses the API.

## `RuntimeFlags`

```go
type RuntimeFlags struct {
    Debug                    bool
    LocalRequest             bool
    NoAuth                   bool
    UserFound                bool
    Authenticated            bool
    Authorized               bool
    Repeating                bool
    RWP                      bool
    EnvironmentRejected      bool
    EnvironmentStageExpected bool
    SubjectStageExpected     bool
}
```

| Field | Meaning |
| --- | --- |
| `Debug` | Host debug mode applies. |
| `LocalRequest` | Current implementation mirrors `NoAuth`; do not interpret it as a separately verified socket origin. |
| `NoAuth` | Host no-auth condition. |
| `UserFound` | A backend/user lookup found the subject. |
| `Authenticated` | Credentials/session authentication succeeded at this stage. |
| `Authorized` | Authorization succeeded at this stage. |
| `Repeating` | Host repeating-request condition. |
| `RWP` | Host RWP runtime flag. |
| `EnvironmentRejected` | Pre-auth environment processing rejected the request. |
| `EnvironmentStageExpected` | Host believes an environment stage is configured; currently reflects Lua configuration only, not native sources. |
| `SubjectStageExpected` | Host believes subject-stage processing is expected; currently reflects Lua configuration only, not native sources. |

These are observations, not authority to mutate the request.

## `RuntimeContext`

```go
type RuntimeContext interface {
    Get(string) (any, bool)
    Snapshot() map[string]any
}
```

`Get` returns one isolated runtime value and presence. `Snapshot` returns all values as a copy suitable for read-only processing. Values are restricted/normalized by host adapters; do not store pointers, secrets, unbounded objects, or mutable service handles. Use the standard [`exchange` package](./exchange.md) when components need an interoperable keyspace.

## `RuntimeDelta`

```go
type RuntimeDelta struct {
    Set    map[string]any
    Delete []string
}
```

`Delete` removes keys and `Set` writes normalized values for later eligible components. Validation rejects unsupported value shapes. Within one application, deletion is applied before setting; later components can overwrite earlier values. A delta never mutates the input `RuntimeContext` object directly.

Accepted values are `nil`, booleans, strings, finite signed/unsigned integer and
floating-point scalars, string-keyed maps, slices, and arrays, recursively.
Pointers and structs such as `time.Time` or `netip.Addr` are rejected. The
current normalizer imposes no maximum key length, number of entries, slice
length, aggregate byte size, or recursion depth, and it does not detect cyclic
map/slice graphs. Trusted plugin code must therefore return small, acyclic,
explicitly bounded value graphs.

The current runtime evaluates deltas from environment, subject, obligation, and post-action results. For post-actions, `RuntimeDelta` is the **only** result field currently evaluated.

## `CredentialProvider`

```go
type CredentialProvider interface {
    Password(context.Context) (Secret, bool)
}
```

`Password` returns a request-scoped `Secret` and a presence boolean. A useful provider is supplied only after both plugin `RequireCapability(CapabilityCredentials)` and operator permission succeed. Call it during the request method and honor cancellation.

Post-action requests capture a `context.WithoutCancel`-style request context for their credential provider. Although a retained provider can therefore remain technically callable later with another live context, retaining it is outside the contract and risks extending secret lifetime. Access credentials only inside `Enqueue` and never pass them to detached work.

## `Secret`

```go
type Secret interface {
    WithBytes(func([]byte) error) error
    IsZero() bool
}
```

`WithBytes` exposes secret bytes only for the callback duration and returns either the callback/host error. The byte slice is borrowed: do not retain it, convert it to a long-lived string, place it in an error, or send it to a worker. `IsZero` reports absent/empty material without exposing bytes. A nil `Secret` must also be handled.
