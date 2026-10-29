---
title: Extension Points
description: Init tasks, source scheduling, environment and subject sources, obligations, and post-actions
keywords: [EnvironmentSource, SubjectSource, ObligationTarget, PostActionTarget, InitTask]
sidebar_position: 5
---

# Extension Points

## `AbortPolicy`

```go
type AbortPolicy string
```

| Constant | Value | Intended public meaning | Current production behavior |
| --- | --- | --- | --- |
| `AbortPolicyNone` | `"none"` | Leave later sources eligible. | Descriptor is validated/stored, but policy is ignored. |
| `AbortPolicySource` | `"source"` | Stop later sources in this extension plan. | Currently ignored. |
| `AbortPolicyRequest` | `"request"` | Stop request-time extension processing. | Currently ignored. |

Today an `EnvironmentResult` with `Abort: true` stops later environment levels regardless of descriptor policy. `SubjectResult` has no `Abort` field, so `SubjectSource` abort policy has no result signal to evaluate.

## `SourceDescriptor`

```go
type SourceDescriptor struct {
    Timeout     time.Duration
    Name        string
    Requires    []string
    After       []string
    Priority    int
    AbortPolicy AbortPolicy
}
```

| Field | Meaning, validation, and production status |
| --- | --- |
| `Timeout` | Per-call bound. Non-negative; zero means the host/default path supplies no source-specific deadline. Evaluated. |
| `Name` | Required plugin-local component name matching `[a-z0-9][a-z0-9_]{0,62}`. Qualified as `<module>.<name>`. Evaluated. |
| `Requires` | Intended hard dependencies, local names or qualified native Go source names. Lua sources are unsupported. Evaluated as hard dependencies. |
| `After` | Intended ordering hints. Current scheduler concatenates this with `Requires` and treats entries identically as hard dependencies. A missing `After` target therefore blocks planning rather than acting as a soft preference. |
| `Priority` | Public scheduling hint. Validated/stored/discovered but currently ignored by the runtime scheduler. |
| `AbortPolicy` | One of the constants above. Validated/stored/discovered but currently ignored. |

Dependency graphs must be acyclic and names must resolve in the applicable native source plan. Sources at the same dependency level can run independently; do not rely on registration order for same-level effects.

## `InitContext`

```go
type InitContext struct {
    Host   Host
    Config ConfigView
}
```

`Host` is the runtime host facade and `Config` is the configured module subtree. Both are populated when the host starts a registered init task.

## `InitTask`

```go
type InitTask interface {
    Name() string
    Start(context.Context, InitContext) error
    Stop(context.Context) error
}
```

`Name` must be a valid unique local component name. Tasks start in registration order after all applicable module `Start` methods. They stop in reverse order before module shutdown. A task start error is fatal even when its module is optional. `Stop` must be idempotent; the module-level stop timeout is currently not applied to task stops. All calls are panic-protected.

## Environment sources

### `EnvironmentRequest`

```go
type EnvironmentRequest struct {
    Snapshot    RequestSnapshot
    Runtime     RuntimeContext
    Credentials CredentialProvider
}
```

`Snapshot` and `Runtime` are populated at pre-auth time. `Credentials` is usable only for modules authorized for `CapabilityCredentials`; otherwise it is nil/unavailable. Prefer environment signals that do not need credentials.

### `EnvironmentResult`

```go
type EnvironmentResult struct {
    Status       *StatusMessage
    Logs         []LogField
    Facts        []PolicyFact
    RuntimeDelta RuntimeDelta
    Triggered    bool
    Abort        bool
}
```

| Field | Current evaluation |
| --- | --- |
| `Status` | Text/key are applied; `Code` and `Temporary` are not meaningful on this adapter path. |
| `Logs` | Emitted through host logging subject to plugin redaction responsibility. |
| `Facts` | Fully validated against active registry, current operation, declared type, and `pre_auth` stage. |
| `RuntimeDelta` | Validated and applied for later eligible components. |
| `Triggered` | Marks the source as having produced an applicable environment signal. |
| `Abort` | Stops later environment plan levels today, independent of `SourceDescriptor.AbortPolicy`. |

Status/log/runtime application can happen before a later returned fact fails validation. Return internally consistent output and prevalidate facts.

### `EnvironmentSource`

```go
type EnvironmentSource interface {
    Descriptor() SourceDescriptor
    Evaluate(context.Context, EnvironmentRequest) (EnvironmentResult, error)
}
```

`Descriptor` is read during registration/planning. `Evaluate` is invoked at pre-auth time with the descriptor timeout. Errors and panics become classified plugin failures; honor cancellation.

## Subject sources

### `SubjectRequest`

```go
type SubjectRequest struct {
    Snapshot      RequestSnapshot
    Runtime       RuntimeContext
    BackendResult BackendResult
    Credentials   CredentialProvider
}
```

`BackendResult` is a value copy of the current backend outcome. It is not mutable host state. `Credentials` remains capability-gated.

`BackendResult.Facts` carries the completed public Lua and native plugin provider output collected earlier in the same
admitted Decision Service session, for example GeoIP facts from an environment provider. Only facts whose source is `lua`
or `plugin` are projected; caller, token, transport, and host-only facts are excluded. Before a provider is scheduled
again, its declared output is removed from the carried evidence, so a skipped or failed refresh never reuses an earlier
value. Consume this projection instead of assuming that an environment provider wrote a runtime map as a side effect.
The backend selection is retained across every selected subject provider of the checkpoint.

### `SubjectResult`

```go
type SubjectResult struct {
    Status             *StatusMessage
    SelectedBackend    *BackendServerRef
    BackendResultPatch *BackendResultPatch
    Logs               []LogField
    Facts              []PolicyFact
    BackendAttributes  AttributePatch
    Response           ResponseMutation
    RuntimeDelta       RuntimeDelta
    Rejected           bool
}
```

| Field | Current evaluation |
| --- | --- |
| `Status` | Text/key are applied; status `Temporary` is ignored. |
| `SelectedBackend` | Replaces current selected backend. Prefer a candidate-derived ref. |
| `BackendResultPatch` | Applies explicit backend result/state changes. |
| `Logs` | Emitted by the host. |
| `Facts` | Fully validated for active registry, operation, type, and `subject_analysis`. |
| `BackendAttributes` | Deletes/sets backend attributes; general patch keys currently have only weak validation. |
| `Response` | Applies safe HTTP response changes; no-op for gRPC or already-written responses. |
| `RuntimeDelta` | Validated and applied. |
| `Rejected` | Rejects the subject/request at this stage. |

There is no abort field. `SourceDescriptor.AbortPolicy` is therefore currently irrelevant for subject result control flow. Later source results overwrite earlier patches where they target the same state.

### `SubjectSource`

```go
type SubjectSource interface {
    Descriptor() SourceDescriptor
    Evaluate(context.Context, SubjectRequest) (SubjectResult, error)
}
```

The lifecycle, deadline, error, and panic rules match `EnvironmentSource`.

## Obligations

### `ObligationRequest`

```go
type ObligationRequest struct {
    // unexported host-assigned execution identity
    BackendOutcome BackendOutcomeView
    Snapshot       RequestSnapshot
    Runtime        RuntimeContext
    Credentials    CredentialProvider
    Args           ArgsView
    Facts          []PolicyFact
}

func (r ObligationRequest) ExecutionIdentity() ExecutionIdentityView
```

`Credentials` exposes the submitted request password under the same `credentials` capability that gates environment sources, subject sources, backends, and post-actions; there is no obligation-specific capability. The host projects the password only when the module called `RequireCapability(CapabilityCredentials)` in `Register` and the operator listed `credentials` in `allow_capabilities`. On host-built requests the field is always a non-nil provider; without the grant `Password(ctx)` returns `nil, false` and the provider holds no password material. With the grant the password is request-scoped: it becomes unavailable when the request context ends, so read it synchronously inside `Execute` and never retain the `Secret`. A grant issued to one module is never visible to another.

A typical use is a pre-auth obligation that runs on a brute-force or RBL deny and checks whether the submitted password is the account's known-good password before choosing a response. `RequestSnapshot.Account` is best effort in `pre_auth`: with brute-force protection enabled it is commonly empty, so key such lookups by `RequestSnapshot.Username` and treat `Account` only as a hint.

The host renders its credential provider and secret values as a fixed redaction marker in `fmt`, `slog`, and plugin log fields, and JSON encoding yields no secret bytes. Never put password bytes, derived hashes, or comparison inputs into log fields, facts, runtime deltas, status text, span attributes, or errors.

`Args` is the configured effect-argument subtree; `Facts` are the facts available to the final decision/effect. Both are read-only views/copies.
`BackendOutcome` and `ExecutionIdentity()` are described below under [Host-captured request views](#host-captured-request-views).

### `ObligationResult`

```go
type ObligationResult struct {
    Status       *StatusMessage
    Logs         []LogField
    Facts        []PolicyFact
    Response     ResponseMutation
    RuntimeDelta RuntimeDelta
    Applied      bool
    Temporary    bool
}
```

| Field | Current evaluation |
| --- | --- |
| `Status` | Text/key are applied; `Status.Temporary` is ignored. |
| `Logs` | Emitted through host logging. |
| `Facts` | Fully validated at `auth_decision`. |
| `Response` | Applies safe response mutation on eligible HTTP paths. |
| `RuntimeDelta` | Validated and applied. |
| `Applied` | Reports that the selected obligation was applied. |
| `Temporary` | Requests temporary-failure handling for this synchronous effect. Evaluated independently of `Status.Temporary`. |

### `ObligationTarget`

```go
type ObligationTarget interface {
    Name() string
    Execute(context.Context, ObligationRequest) (ObligationResult, error)
}
```

`Name` is a valid unique local component name. `Execute` runs synchronously in the request path; it must honor cancellation and its operational bounds. Errors/panics fail the effect rather than being converted to a normal result.

An obligation target may additionally implement [`CallbackAdmission`](#callback-admission-limits) to declare
host-enforced rate and concurrency bounds.

## Post-actions

### `PostActionRequest`

```go
type PostActionRequest struct {
    // unexported host-assigned execution identity
    BackendOutcome BackendOutcomeView
    Snapshot       RequestSnapshot
    Runtime        RuntimeContext
    Credentials    CredentialProvider
    PasswordHash   string
    Args           ArgsView
    Facts          []PolicyFact
}

func (r PostActionRequest) ExecutionIdentity() ExecutionIdentityView
```

| Field | Meaning and security note |
| --- | --- |
| `Snapshot` | Final request snapshot available to the enqueue decision. |
| `Runtime` | Read-only runtime values. |
| `Credentials` | Capability-gated provider. Use only synchronously inside `Enqueue`; never retain or pass to detached work. |
| `BackendOutcome` | Immutable host-captured credential evidence; see [Host-captured request views](#host-captured-request-views). |
| `PasswordHash` | Host-generated password-derived value. It is set only when a password was present **and** the module requested and the operator allowed the `password_hash` capability; otherwise it is empty. `credentials` does not imply it, and `password_hash` grants no raw credential access. It is the lowercase 64-character SHA-256 digest of `nonce || NUL || password` in every runtime mode. Treat it as sensitive, never log/trace/store/expose it, and validate the full digest before deriving any shortened integration-specific representation. |
| `Args` | Read-only post-action arguments. |
| `Facts` | Facts available at the post-decision stage. |

### `PostActionEnqueueResult`

```go
type PostActionEnqueueResult struct {
    Status       *StatusMessage
    Logs         []LogField
    RuntimeDelta RuntimeDelta
    QueuedID     string
    Enqueued     bool
    Temporary    bool
}
```

Every field is public surface. Current production evaluation is intentionally narrower:

| Field | Current status |
| --- | --- |
| `Status` | Currently ignored. |
| `Logs` | Currently ignored. |
| `RuntimeDelta` | Validated and applied; the only currently evaluated field. |
| `QueuedID` | Currently ignored. |
| `Enqueued` | Currently ignored. |
| `Temporary` | Currently ignored. |

The target itself must arrange durable/supervised work before returning; the result does not cause the host to enqueue arbitrary work automatically.

### `PostActionTarget`

```go
type PostActionTarget interface {
    Name() string
    Enqueue(context.Context, PostActionRequest) (PostActionEnqueueResult, error)
}
```

`Name` follows component-name validation. `Enqueue` is called after decision processing to accept or skip follow-up work. Keep it bounded; use `Host.Go` or a plugin-owned lifecycle-managed queue for detached processing, and copy only non-secret values. Errors and panics are classified plugin failures.

## Callback admission limits

```go
type CallbackAdmissionLimits struct {
    RequestsPerSecond int
    MaxConcurrency    int
}

type CallbackAdmission interface {
    AdmissionLimits() (requestsPerSecond, maxConcurrency int)
}

type BoundedPostActionTarget interface {
    PostActionTarget
    AdmissionLimits() (requestsPerSecond, maxConcurrency int)
}

type PostActionAdmissionLimits = CallbackAdmissionLimits
```

An `ObligationTarget` or `PostActionTarget` that also implements `AdmissionLimits()` declares optional host-enforced
bounds. The registrar reads them once during registration and freezes them; `RequestsPerSecond` must be 1 to 10000 and
`MaxConcurrency` 1 to 1024, otherwise registration fails. The host enforces the limits before invoking the callback with
a token bucket whose burst equals the per-second rate plus a concurrency ceiling. Limits apply per registered component
within one runtime generation. Exhaustion returns a temporary callback failure without invoking plugin code; for a
detached post-action it cannot rewrite an already finalized authentication response. `PostActionAdmissionLimits`
remains a source-compatible alias.

## Host-captured request views

### `ExecutionIdentityView`

```go
func (v ExecutionIdentityView) Module() string
func (v ExecutionIdentityView) Component() string
func (v ExecutionIdentityView) ExtensionPoint() string
func (v ExecutionIdentityView) Operation() string
func (v ExecutionIdentityView) Target() DecisionTargetSelector
```

`ObligationRequest`, `PostActionRequest`, and `DecisionEffectRequest` expose an immutable `ExecutionIdentity()` with the
configured module instance, registered component, callback extension point, selected operation, and exact target. The
host derives it from the captured registry generation; facts, arguments, and returned plugin values never supply it, and
authentication adapters overwrite any identity in an incoming internal request. The constructors
(`NewExecutionIdentityView`, `NewObligationRequest`, `NewPostActionRequest`) serve host adapters and tests; building a
local value grants no registration or execution authority.

### `BackendOutcomeView`

```go
const (
    BackendOutcomeAuthenticated  BackendOutcomeStatus = "authenticated"
    BackendOutcomeBadCredentials BackendOutcomeStatus = "bad_credentials"
)

func (v BackendOutcomeView) Observed() bool
func (v BackendOutcomeView) EventID() string
func (v BackendOutcomeView) Account() string
func (v BackendOutcomeView) Status() BackendOutcomeStatus
func (v BackendOutcomeView) ObservedAt() time.Time
```

`ObligationRequest.BackendOutcome` and `PostActionRequest.BackendOutcome` carry independent credential evidence captured
by the host before subject patches and the final Policy decision: a stable host event ID (at most 128 bytes), the
backend-normalized account, the UTC capture time, and the closed status. Later runtime flags cannot rewrite it. The zero
value (`Observed() == false`) means no independent backend result was observed; lookup-only requests never create it.
Do not interpret missing evidence as bad credentials.
