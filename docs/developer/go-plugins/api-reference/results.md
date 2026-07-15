---
title: Common Results
description: Status, logging, policy facts, patches, response mutation, and backend result values
keywords: [StatusMessage, PolicyFact, ResponseMutation, BackendResult, BackendServerRef]
sidebar_position: 4
---

# Common Results

These values are shared by several extension points. Public presence does not imply identical production semantics in every result type.

## `StatusMessage`

```go
type StatusMessage struct {
    Code        string
    MessageKey  string
    DefaultText string
    Temporary   bool
}
```

| Field | Meaning and current evaluation |
| --- | --- |
| `Code` | Stable plugin-defined machine code. The current adapter preserves it in backend internal additional attributes, but most other paths do not consume it. |
| `MessageKey` | Host translation/message-catalog key. Current source, backend, obligation, and MFA adapters can apply it as the runtime status key. |
| `DefaultText` | Protocol-neutral fallback status text. Current adapters can apply it as the runtime status message. Never include secrets. |
| `Temporary` | Temporary-failure hint. Currently drives temporary failure for `BackendResult` and `AccountListResult`; it is ignored on environment, subject, obligation, and typed MFA result statuses. |

`nil` means no status update. Result types with a separate `Temporary` field use their own semantics. In particular, `ObligationResult.Temporary` is evaluated; `PostActionEnqueueResult.Temporary` currently is not.

## `LogField`

```go
type LogField struct {
    Key   string
    Value any
}
```

One structured result/logger field. The public type does not validate key or value. Result logs are emitted through host-controlled logging, but plugin authors remain responsible for redaction and cardinality. [`PublicPolicyFactLogField`](./policy.md#publicpolicyfactlogfield) creates the intentionally public policy-fact naming form.

## `PolicyFact`

```go
type PolicyFact struct {
    Attribute string
    Value     any
}
```

`Attribute` is a registered fact ID such as `plugin.environment.customer_risk.suspicious`; `Value` must match the declared type and runtime-compatible value shapes.

Production validation differs by producer:

- environment facts are checked against the active registry, operation, type, and `pre_auth` stage;
- subject facts are checked the same way at `subject_analysis`;
- obligation facts are checked at `auth_decision`;
- backend and account-list facts are currently only normalized for a non-empty ID and a runtime-compatible value before the core records them; they do not receive equivalent registry/stage/type enforcement in that adapter path.

Do not rely on the weaker backend path: emit registered, correctly typed facts everywhere. `AttributeDefinition.Details` is retained by the registry, but `PolicyFact` has no details field, so native v1 plugins cannot emit per-fact detail values.

## `AttributePatch`

```go
type AttributePatch struct {
    Set    map[string][]string
    Delete []string
}
```

Describes backend/subject attribute changes. Deletes are applied before sets;
later sources/effects win. Current subject and backend patch adapters skip empty
keys but do not otherwise apply `ValidateBackendAttributeName` to every patch
key. `BackendResult.Attributes` has the same weak key handling. Identity field
names and `AccountField` are validated more strictly. Plugins should use
printable ASCII attribute names without spaces even where the adapter currently
accepts more.

## `ResponseHeaderMutation`

```go
type ResponseHeaderMutation struct {
    Set    map[string][]string
    Delete []string
}
```

Describes safe response-header deletes and sets. Deletes are applied first. The current response-mutation adapter is active only for subject and obligation results, and is a no-op for gRPC or when the response is already written. Forbidden/invalid headers are silently skipped in this mutation path. Later sources/effects win.

## `ResponseMutation`

```go
type ResponseMutation struct {
    Headers      ResponseHeaderMutation
    StatusHeader bool
}
```

`Headers` carries the operations above. `StatusHeader` asks the host to emit the host-managed authentication status header; it is the only supported Auth-Status channel. Post-actions cannot mutate a response.

## `BackendServerRef`

```go
type BackendServerRef struct {
    Name      string
    Protocol  string
    Authority string
    Address   string
    Port      string
}
```

A value-only backend selection returned by backends or subject sources. `Name`, `Protocol`, and `Authority` identify the target; `Address` and `Port` carry its endpoint. All fields can be empty, and the current result adapter does not robustly revalidate every combination. Prefer refs obtained from a host `BackendServerCandidate.Ref()` instead of constructing unchecked values.

## `BackendServerCandidate`

```go
type BackendServerCandidate struct {
    Name      string
    Protocol  string
    Authority string
    Address   string
    Port      int
    HAProxyV2 bool
    Alive     bool
}
```

| Field | Meaning and current population |
| --- | --- |
| `Name` | Candidate name; currently often empty in the production monitor adapter. |
| `Protocol` | Backend protocol; populated. |
| `Authority` | Optional routing authority; currently often empty. |
| `Address` | Monitored backend address; populated. |
| `Port` | Monitored backend TCP port; populated. |
| `HAProxyV2` | Whether the target expects HAProxy protocol v2; populated. |
| `Alive` | Current health observation. The production candidate adapter currently emits `true` for listed candidates. |

Candidates are immutable snapshots. They can become stale after `List` returns.

### `BackendServerCandidate.Ref`

```go
func (c BackendServerCandidate) Ref() BackendServerRef
```

Copies `Name`, `Protocol`, `Authority`, and `Address`. It converts a positive `Port` to decimal text; zero or negative ports become `""`. `HAProxyV2` and `Alive` are intentionally not present in the returned ref.

## `BackendResultPatch`

```go
type BackendResultPatch struct {
    SelectedBackend *BackendServerRef
    Attributes      AttributePatch
    Authenticated   *bool
    UserFound       *bool
    Account         string
    AccountField    string
}
```

| Field | Effect |
| --- | --- |
| `SelectedBackend` | Replaces the selected backend when non-nil. |
| `Attributes` | Applies explicit backend attribute deletes/sets. |
| `Authenticated` | Overrides authentication state when non-nil; pointer distinguishes false from no change. |
| `UserFound` | Overrides user-found state when non-nil. |
| `Account` | Replaces the account when non-empty. |
| `AccountField` | Names the account source field; must be printable ASCII without spaces when applied. |

This patch appears in `SubjectResult`. `SubjectResult.SelectedBackend` and `BackendAttributes` are additional result channels; avoid contradictory values.

## `BackendIdentityResult`

```go
type BackendIdentityResult struct {
    UniqueUserIDField       string
    DisplayNameField        string
    TOTPSecretField         string
    TOTPRecoveryField       string
    Groups                  []string
    GroupDistinguishedNames []string
}
```

The four `...Field` values name entries in `BackendResult.Attributes` used for unique ID, display name, TOTP secret, and TOTP recovery data. They are field names, not the values themselves, and are validated as backend attribute names. `Groups` and `GroupDistinguishedNames` carry resolved group values and DNs. All fields are evaluated by current authentication/identity mapping where the corresponding path needs them.

If `Account` is non-empty while `AccountField` is empty, the current adapter
defaults the field name to `account` and materializes the account value under
that attribute when it is not already present.

## `BackendResult`

```go
type BackendResult struct {
    Status        *StatusMessage
    Attributes    map[string][]string
    Facts         []PolicyFact
    Identity      BackendIdentityResult
    Account       string
    AccountField  string
    BackendServer *BackendServerRef
    Authenticated bool
    UserFound     bool
}
```

| Field | Meaning and current evaluation |
| --- | --- |
| `Status` | Applies status text/key; code is retained internally; `Temporary` can force temporary failure. |
| `Attributes` | Complete returned backend attribute values. Empty names are skipped; other names are currently not passed through `ValidateBackendAttributeName`. |
| `Facts` | Backend-stage facts; currently normalized but not subjected to the full registry/stage/type checks used by source facts. |
| `Identity` | Identity field mapping and group metadata. |
| `Account` | Resolved account value. |
| `AccountField` | Attribute name from which the account originated; validated when non-empty. Defaults to `account` when `Account` is set and the field is empty. |
| `BackendServer` | Backend target used by the plugin. |
| `Authenticated` | Password/identity verification outcome. |
| `UserFound` | Whether the subject exists. |

Returned errors and recovered panics are classified as temporary plugin/backend failures. A result can be partly applied before a later fact validation error on source/obligation paths; therefore validate all output before returning it.
