---
title: Policy Declarations
description: Complete policy stage, operation, decision, type, category, detail, attribute, and fact log reference
keywords: [PolicyFact, AttributeDefinition, PolicyStage, PolicyOperation, PluginPolicyAttributeID]
sidebar_position: 9
---

# Policy Declarations

## Namespace constants

```go
const PluginPolicyAttributePrefix = "plugin"
const PublicPolicyFactLogPrefix = "policy_fact_"
```

`PluginPolicyAttributePrefix` is the first segment of native fact IDs. It is also the base plugin debug selector. `PublicPolicyFactLogPrefix` marks structured log keys deliberately reviewed for public policy values; it does not redact a value automatically.

## `PolicyStage`

```go
type PolicyStage string
```

| Constant | Value | Intended producer/checkpoint |
| --- | --- | --- |
| `PolicyStagePreAuth` | `"pre_auth"` | Environment checks before backend authentication. |
| `PolicyStageAuthBackend` | `"auth_backend"` | Backend/password result facts. |
| `PolicyStageSubjectAnalysis` | `"subject_analysis"` | Subject enrichment/rejection after backend evaluation. |
| `PolicyStageAccountProvider` | `"account_provider"` | Account-list provider facts. |
| `PolicyStageAuthDecision` | `"auth_decision"` | Final decision and obligation facts. |

An attribute definition must use one exact value. Current strict runtime validation is applied to environment (`pre_auth`), subject (`subject_analysis`), and obligation (`auth_decision`) facts. Backend/account-list adapters currently do not perform equivalent registry/stage validation.

## `PolicyOperation`

```go
type PolicyOperation string
```

| Constant | Value |
| --- | --- |
| `PolicyOperationAuthenticate` | `"authenticate"` |
| `PolicyOperationLookupIdentity` | `"lookup_identity"` |
| `PolicyOperationListAccounts` | `"list_accounts"` |

`AttributeDefinition.Operations` must be non-empty, contain only these values, and contain no duplicates. Strict fact paths reject a fact when the current report operation is not listed.

## `PolicyDecision`

```go
type PolicyDecision string
```

| Constant | Value | Public meaning |
| --- | --- | --- |
| `PolicyDecisionNeutral` | `"neutral"` | Continue without a permit/deny effect. |
| `PolicyDecisionDeny` | `"deny"` | Reject the operation. |
| `PolicyDecisionPermit` | `"permit"` | Permit where the stage supports it. |
| `PolicyDecisionTempFail` | `"tempfail"` | Temporary failure. |

This enum is public surface but is not referenced by another current `pluginapi/v1` request/result field and the production plugin adapters do not currently consume it. Extension outcomes use fields such as `Rejected`, `Temporary`, `Authenticated`, and policy-configured effects instead.

## `AttributeType`

```go
type AttributeType string
```

| Constant | Value | Expected fact value on strict native paths |
| --- | --- | --- |
| `AttributeTypeBool` | `"bool"` | `bool` |
| `AttributeTypeString` | `"string"` | `string` |
| `AttributeTypeStringList` | `"string_list"` | Runtime normalization produces `[]any` whose elements must all be strings. |
| `AttributeTypeNumber` | `"number"` | `int`, `int64`, `uint64`, or `float64`, converted to `float64`. Other Go numeric widths are not accepted by the type-specific step. |
| `AttributeTypeIP` | `"ip"` | Parseable IP string or `netip.Addr`. |
| `AttributeTypeCIDR` | `"cidr"` | Public declared type; current strict adapter has no additional CIDR-specific parsing beyond generic runtime normalization. |
| `AttributeTypeDateTime` | `"datetime"` | Public declared type; current strict adapter has no additional datetime-specific parsing beyond generic runtime normalization. |

All constants are valid for `DetailDefinition.Type` as well. Attribute registration validates only that the enum is known; use a stable JSON-compatible representation and test compiled policy behavior.

## `AttributeCategory`

```go
type AttributeCategory string
```

| Constant | Value | Meaning |
| --- | --- | --- |
| `AttributeCategoryEnvironment` | `"environment"` | Environment/context attribute. |
| `AttributeCategorySubject` | `"subject"` | Subject/account attribute. |
| `AttributeCategoryResource` | `"resource"` | Requested resource attribute. |

Registration accepts only these values.

## `DetailSensitivity`

```go
type DetailSensitivity string
```

| Constant | Value | Meaning |
| --- | --- | --- |
| `DetailSensitivityPublic` | `"public"` | Detail can be selected for reviewed public output. |
| `DetailSensitivityInternal` | `"internal"` | Internal diagnostic detail. |
| `DetailSensitivitySecret` | `"secret"` | Detail must never be exposed. |

An empty `DetailDefinition.Sensitivity` currently defaults to internal during registration. Any other unknown string is rejected.

## `DetailDefinition`

```go
type DetailDefinition struct {
    Type        AttributeType
    Sensitivity DetailSensitivity
    Purpose     string
    MaxLength   int
}
```

| Field | Meaning and validation |
| --- | --- |
| `Type` | Required known attribute type. |
| `Sensitivity` | Empty defaults to internal; otherwise one declared constant. |
| `Purpose` | Optional operator/developer explanation. No public grammar. |
| `MaxLength` | Declared output bound. The registration conversion stores it but does not reject zero/negative values itself. |

Detail definitions are stored and used by policy compilation/reporting. However, `pluginapi.PolicyFact` has only `Attribute` and `Value`; v1 native plugins currently cannot attach detail values to emitted facts.

## `AttributeDefinition`

```go
type AttributeDefinition struct {
    Details       map[string]DetailDefinition
    ID            string
    Description   string
    Stage         PolicyStage
    Operations    []PolicyOperation
    ProducerTypes []string
    ProducerCheck string
    Category      AttributeCategory
    Type          AttributeType
}
```

| Field | Meaning and registration behavior |
| --- | --- |
| `Details` | Optional named detail schema. Names are stored as supplied; each detail's type/sensitivity is validated. |
| `ID` | Required after trimming. Prefer `PluginPolicyAttributeID`; registration does not itself require the native namespace shape. Must be globally unique in the policy registry. |
| `Description` | Optional human-readable description. |
| `Stage` | Required supported stage. |
| `Operations` | Required, non-empty, unique supported operations. |
| `ProducerTypes` | Optional compatible compiled policy check types such as `plugin.environment`. Stored as a copy and used by compiler producer guards. Strings are not normalized by registration. |
| `ProducerCheck` | Optional exact compiled policy check name that must be active. This is a policy check name, not a plugin component ID. |
| `Category` | Required supported category. |
| `Type` | Required supported value type. |

`ProducerCheck` takes the specific-producer path during policy compilation; `ProducerTypes` supports compatible active check types. A stage-matching custom attribute can require that its producer check is referenced/available. Use the check names produced by the current policy compiler, not guessed component IDs.

## `PluginPolicyAttributeID`

```go
func PluginPolicyAttributeID(extension, moduleOrFeature, fact string) (string, error)
```

Validates all three arguments with `ValidateComponentName` and returns:

```text
plugin.<extension>.<moduleOrFeature>.<fact>
```

No argument is trimmed; invalid input returns an error wrapping `ErrInvalidName`. This function builds IDs only and does not register them.

## `PublicPolicyFactLogField`

```go
func PublicPolicyFactLogField(namespace, key string, value any) (LogField, error)
```

Validates `namespace` and `key` with `ValidateComponentName`, then returns:

```go
LogField{
    Key:   "policy_fact_" + namespace + "_" + key,
    Value: value,
}
```

The helper marks intent through naming only. It does not inspect, copy, truncate, normalize, or redact `value`. Use it only for low-cardinality values explicitly classified as public; never pass credentials, identifiers, IPs, session data, or unbounded text merely because the helper accepts `any`.
