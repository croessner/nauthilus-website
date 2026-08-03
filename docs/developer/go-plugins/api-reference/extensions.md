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
    Snapshot RequestSnapshot
    Runtime  RuntimeContext
    Args     ArgsView
    Facts    []PolicyFact
}
```

`Args` is the configured effect-argument subtree; `Facts` are the facts available to the final decision/effect. Both are read-only views/copies.

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

## Post-actions

### `PostActionRequest`

```go
type PostActionRequest struct {
    Snapshot     RequestSnapshot
    Runtime      RuntimeContext
    Credentials  CredentialProvider
    PasswordHash string
    Args         ArgsView
    Facts        []PolicyFact
}
```

| Field | Meaning and security note |
| --- | --- |
| `Snapshot` | Final request snapshot available to the enqueue decision. |
| `Runtime` | Read-only runtime values. |
| `Credentials` | Capability-gated provider. Use only synchronously inside `Enqueue`; never retain or pass to detached work. |
| `PasswordHash` | Host-generated password-derived value, delivered to all post-action targets regardless of credentials capability. It is the lowercase 64-character SHA-256 digest of `nonce || NUL || password` in every runtime mode. Treat it as sensitive, never log/trace/store/expose it, and validate the full digest before deriving any shortened integration-specific representation. |
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
