---
title: Generic Policy Providers
description: DecisionFactProvider and DecisionEffectProvider contracts for native Go plugins
keywords: [DecisionFactProvider, DecisionEffectProvider, DecisionValue, Records, Policy]
sidebar_position: 9
---

# Generic Policy Providers

Nauthilus v4 native plugins extend the shared Decision Service through two additive interfaces:

```go
type DecisionFactProvider interface {
    Descriptor() DecisionFactProviderDescriptor
    Collect(context.Context, DecisionFactRequest) (DecisionFactResult, error)
}

type DecisionEffectProvider interface {
    Descriptor() DecisionEffectProviderDescriptor
    Execute(context.Context, DecisionEffectRequest) (DecisionEffectResult, error)
}
```

A fact provider contributes declared facts. It does not select decisions, schedule itself, or execute effects. An
effect provider runs only an effect already selected and invoked by the host. Registration advertises capability;
operator configuration and a prepared Policy generation activate exact bindings.

Register implementations through the optional `DecisionRegistrar` supplied to the plugin registration boundary:

```go
type DecisionRegistrar interface {
    RegisterDecisionFactProvider(DecisionFactProvider) error
    RegisterDecisionEffectProvider(DecisionEffectProvider) error
}
```

## Fact-provider descriptors

```go
type DecisionFactProviderDescriptor struct {
    Inputs    []DecisionFactInputDescriptor
    Targets   []DecisionTargetSelector
    Outputs   []DecisionFactOutputDescriptor
    Namespace string
    Name      string
    Timeout   time.Duration
}
```

`Namespace` and `Name` are canonical lowercase component identities. `Targets` is a non-empty exact list of
namespace/action selectors; wildcards are not accepted. `Outputs` declares every provider-local fact name, category,
kind, and applicable bound. `Timeout` must be positive and cannot exceed
`MaximumDecisionFactProviderTimeout` (10 minutes); configured execution may narrow it.

```go
type DecisionFactOutputDescriptor struct {
    RecordSchema *DecisionRecordSchemaDescriptor
    Name         string
    Category     DecisionFactCategory
    Kind         DecisionValueKind
    MaxLength    int
    MaxItems     int
    MaxBytes     int
}
```

Categories are `subject`, `resource`, and `environment`. The host qualifies the local output with the configured
namespace and provider identity. Return only descriptor-declared names with matching kinds and bounds.

### Record output schemas

```go
type DecisionRecordSchemaDescriptor struct {
    ID                string
    Version           string
    Fields            []DecisionRecordFieldDescriptor
    MinRecords        int
    MaxRecords        int
    MaxFields         int
    MaxAggregateBytes int
}

type DecisionRecordFieldDescriptor struct {
    Name               string
    ProviderVisibility []string
    Kind               DecisionValueKind
    MaxLength          int
    MaxItems           int
    MaxBytes           int
    Required           bool
    ExpressionVisible  bool
}
```

A `records` output may carry an optional closed record schema. `ID` is a canonical local name and `Version` is `v<n>`
with a positive 32-bit number. The schema needs at least one field, `MaxRecords > 0`, `0 <= MinRecords <= MaxRecords`,
`0 < MaxFields <= len(Fields)`, `MaxAggregateBytes > 0`, and no more required fields than `MaxFields`. Each field is a
bounded non-recursive leaf; `ProviderVisibility` lists exact native provider identities such as
`authn/plugin.reputation.assessment` that may read the field, and `ExpressionVisible` allows Policy expressions to use
it. Record metadata on a non-`records` output is rejected. Validate a descriptor with
`ValidateDecisionRecordSchemaDescriptor`.

The host captures this metadata deeply. It uses it only to extend the selected builtin authentication (`authn`) targets,
where operator-authored static schemas remain forbidden; field requiredness and expression/provider visibility survive
registration, candidate generation, and runtime binding. Generic targets can keep their catalog-owned `record_schema`
when an output omits record metadata.

### Exact input requirements

```go
type DecisionFactInputDescriptor struct {
    Fields   []DecisionFactInputFieldDescriptor
    ID       string
    Provider string
    Category DecisionFactCategory
    Kind     DecisionValueKind
}

type DecisionFactInputFieldDescriptor struct {
    Name string
    Kind DecisionValueKind
}
```

`Inputs` optionally declares the exact admitted fact IDs, categories, and kinds a provider consumes. A `records` input
must list the scalar record fields it reads, and only `records` inputs may list fields. When the input is produced by
another native provider, `Provider` names that exact upstream identity (`<namespace>/plugin.<module>.<component>`,
checked by `ValidateDecisionProviderReference`). The host freezes these declarations at registration and, for every
activated target, requires the input schema, visible fields of the declared kinds, the declared upstream producer, and an
explicit scheduler dependency on it. A missing fact, hidden or wrong-kind field, different owner, or missing dependency
rejects the candidate generation before any request is processed. Empty `Inputs` add no schema contract; they never
bypass normal admission or record-field filtering.

## Strict values and ordered records

`DecisionValue` is a deeply owned one-of value constructed with `NewDecisionValue`. Exactly one input member must be
active, including when a list, byte slice, or record list is intentionally empty.

| Kind | Constructor input | Notes |
| --- | --- | --- |
| `string` | `String *string` | Valid UTF-8; descriptor/schema length bound applies. |
| `boolean` | `Boolean *bool` | `false` is a present value. |
| `integer` | `Integer *int64` | Signed 64-bit integer. |
| `double` | `Double *float64` | NaN and infinity are rejected. |
| `strings` | `Strings []string` | Ordered valid UTF-8 list; non-nil empty differs from absent. |
| `bytes` | `Bytes []byte` | Owned bytes; non-nil empty differs from absent. |
| `timestamp` | `Timestamp *time.Time` | Normalized to UTC. |
| `records` | `Records *DecisionRecordList` | Ordered schema-bound records. |

Record lists are built with `NewDecisionRecordFieldValue`, `NewDecisionRecordField`, `NewDecisionRecord`, and
`NewDecisionRecordList`. Each record is a non-empty ordered field slice with unique canonical local field names.
Record fields can contain scalar, string-list, bytes, or timestamp values but never another record list. The target
schema supplies record count, field count, aggregate bytes, per-field kinds/bounds, required fields, visibility, and
predicate rules.

Policy record predicates evaluate one bounded `where` expression against each record and apply the configured `any`,
`all`, or `none` quantifier; every leaf inside `where` refers to the same record. A missing collection makes every
quantifier false, while a present empty collection makes `any` false and `all`/`none` true. Permit-sensitive schemas
should therefore set `min_records: 1`, and providers must supply complete schema-valid evidence. See
[Policy Configuration](../../../configuration/auth-policy.md#record-predicates).

## Fact collection

`DecisionFactRequest` exposes immutable copies of:

- `Target()` — the exact namespace/action selected by the host;
- `Caller()` — redacted principal, client ID, authentication kind, and normalized Policy scopes;
- `Facts()` — admitted host fact views visible to this provider.

`DecisionFactView` contains only the canonical fact ID, category, and strict value. It omits credentials, provenance
controls, scheduling controls, and mutable host state.

Return facts or one safe failure class:

```go
type DecisionFactResult struct {
    Facts      []DecisionFactOutput
    ErrorClass DecisionErrorClass
}
```

Failure classes are `invalid_input`, `unavailable`, `timeout`, and `internal`. Errors and result classes must not carry
dependency responses, credentials, raw requests, or unbounded text. Honor the context deadline and cancellation; do
not start detached work.

## Effect-provider descriptors

```go
type DecisionEffectProviderDescriptor struct {
    Effects   []DecisionEffectDescriptor
    Namespace string
    Name      string
}
```

Each effect declares a provider-local name, exact targets, execution boundary, and bounded typed parameters:

```go
type DecisionEffectDescriptor struct {
    Targets        []DecisionTargetSelector
    Parameters     []DecisionEffectParameterDescriptor
    Name           string
    Execution      DecisionEffectExecution
    ReplaySafety   DecisionEffectReplaySafety
    IdempotencyKey string
}
```

Execution is either `host_sync` (before response finalization) or `host_post_action` (accepted by the host supervisor
and executed asynchronously). Parameter kinds use the non-record value vocabulary; a parameter may be required,
non-empty, length/item/byte bounded, and restricted to an allowed string set.

### Replay safety

Every effect must declare `ReplaySafety` explicitly; there is no default for an omitted value.

| `ReplaySafety` | `IdempotencyKey` | Meaning |
| --- | --- | --- |
| `DecisionEffectReplayUnsafe` (`"unsafe"`) | must be empty | A caller must never repeat a request after an ambiguous outcome. |
| `DecisionEffectReplayIdempotent` (`"idempotent"`) | one exact fact ID | The provider deduplicates by that key across complete request retries. |

For an idempotent effect, the key must be admitted by every selected target schema as a required caller-owned string with
an explicit maximum length of at most 128 bytes. The host rejects an absent or empty key value before invoking the
provider. The provider owns deduplication and must retain it across retries. Lua generic effect providers are always
treated as `unsafe`.

### Execution

`DecisionEffectRequest` provides the exact target, selected local effect, immutable parameters, redacted caller,
visible fact views, and an immutable `ExecutionIdentity()` (module, component, extension point, selected operation,
and target) derived from the captured registry generation. It provides no retry, replay, lifecycle, scheduling, or
decision-selection control.

Return one of `succeeded`, `failed`, or `outcome_unknown`, plus an optional safe failure class. Use
`outcome_unknown` only when an external dispatch may have happened but completion cannot be established. The host
attempts a selected effect ordinal at most once and never retries internally. The public status then depends on the
declared replay safety of the attempted effects:

| Situation | Public status | `retryable` |
| --- | --- | --- |
| `outcome_unknown`, and this and every earlier attempted effect is `idempotent` | `effect_outcome_unknown_replay_safe` | `true`: repeat the complete identical request with the original idempotency values |
| `outcome_unknown` with an earlier or current `unsafe` effect | `effect_outcome_unknown` | `false` |
| an otherwise retryable later failure, cancellation, or acceptance rejection after a non-idempotent effect completed or was accepted | `effect_replay_unsafe` | `false` |
| any other failure | original status | original guidance |

Accepted asynchronous post-actions cannot change an already finalized response. External reconciliation of unsafe
effects must use a provider-owned domain identifier.

## Minimal provider shape

```go
type riskProvider struct{}

func (riskProvider) Descriptor() pluginapi.DecisionFactProviderDescriptor {
    return pluginapi.DecisionFactProviderDescriptor{
        Namespace: "mail.security",
        Name:      "risk",
        Targets: []pluginapi.DecisionTargetSelector{
            {Namespace: "authn", Action: "authenticate"},
        },
        Outputs: []pluginapi.DecisionFactOutputDescriptor{
            {
                Name: "risk.score",
                Category: pluginapi.DecisionFactCategoryEnvironment,
                Kind: pluginapi.DecisionValueKindString,
                MaxLength: 16,
            },
        },
        Timeout: time.Second,
    }
}
```

A minimal effect declaration must name its replay safety:

```go
pluginapi.DecisionEffectDescriptor{
    Name:         "notify",
    Targets:      []pluginapi.DecisionTargetSelector{{Namespace: "mail.security", Action: "accept-message"}},
    Execution:    pluginapi.DecisionEffectExecutionHostSync,
    ReplaySafety: pluginapi.DecisionEffectReplayUnsafe,
}
```

The exact canonical provider identity is assigned by the host after module registration and Policy configuration. See
[Native Go Plugins](../index.md), [runtime and effects](../runtime-and-effects.md), and the
[reference plugins](../reference-plugins/index.md) for complete activation examples.
