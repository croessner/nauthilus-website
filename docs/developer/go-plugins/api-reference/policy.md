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
    Name      string
    Category  DecisionFactCategory
    Kind      DecisionValueKind
    MaxLength int
    MaxItems  int
    MaxBytes  int
}
```

Categories are `subject`, `resource`, and `environment`. The host qualifies the local output with the configured
namespace and provider identity. Return only descriptor-declared names with matching kinds and bounds.

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

Policy record predicates select one field and apply configured `any` or `all` quantification. Missing, malformed, empty,
and schema-incompatible collections are distinct states; none is silently coerced into a vacuous permit.

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
    Targets    []DecisionTargetSelector
    Parameters []DecisionEffectParameterDescriptor
    Name       string
    Execution  DecisionEffectExecution
}
```

Execution is either `host_sync` (before response finalization) or `host_post_action` (accepted by the host supervisor
and executed asynchronously). Parameter kinds use the non-record value vocabulary; a parameter may be required,
non-empty, length/item/byte bounded, and restricted to an allowed string set.

`DecisionEffectRequest` provides the exact target, selected local effect, immutable parameters, redacted caller, and
visible fact views. It provides no retry, replay, lifecycle, scheduling, or decision-selection control.

Return one of `succeeded`, `failed`, or `outcome_unknown`, plus an optional safe failure class. Use
`outcome_unknown` only when an external dispatch may have happened but completion cannot be established. The host
attempts a selected effect ordinal at most once and does not provide automatic replay or an outcome query; external
reconciliation must use a provider-owned domain identifier.

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

The exact canonical provider identity is assigned by the host after module registration and Policy configuration. See
[Native Go Plugins](../index.md), [runtime and effects](../runtime-and-effects.md), and the
[reference plugins](../reference-plugins/index.md) for complete activation examples.
