---
title: exchange Package
description: Complete standard runtime exchange key, builder, normalization, and snapshot reference
keywords: [pluginapi exchange, RuntimeDelta, DecisionSources, FeatureMarker, HIBPResult]
sidebar_position: 13
---

# `exchange` Package

```go
import "github.com/croessner/nauthilus/v4/pluginapi/v1/exchange"
```

The package defines a conventional runtime keyspace shared by native and compatible plugin features. Builders return JSON/runtime-compatible maps and `pluginapi.RuntimeDelta` values; readers create defensive views for analytics and cross-plugin consumption.

## Runtime key constants

| Constant | Exact value | Intended value |
| --- | --- | --- |
| `Prefix` | `plugin.exchange.` | Top-level standard exchange prefix. |
| `KeyDecisionSources` | `plugin.exchange.decision_sources` | Explicit source names, accepted by `StringList`. |
| `KeyFeaturePrefix` | `plugin.exchange.feature.` | Prefix followed by a feature name and containing a marker map. |
| `KeyGeoIP` | `plugin.exchange.geoip` | GeoIP/ASN enrichment map. |
| `KeyGeoIPReputation` | `plugin.exchange.geoip_reputation` | Reputation score/decision map. |
| `KeyFailedLoginHotspot` | `plugin.exchange.failed_login_hotspot` | Failed-login hotspot map. |
| `KeyAccountProtection` | `plugin.exchange.account_protection` | Account-protection state map. |
| `KeyGlobalPattern` | `plugin.exchange.global_pattern` | Global pattern counters/map. |
| `KeyDynamicResponse` | `plugin.exchange.dynamic_response` | Dynamic-response diagnostics map. |
| `KeyHaveIBeenPwned` | `plugin.exchange.haveibeenpwnd` | Secret-safe HIBP result map. |

These constants define conventions, not capability gates. Runtime delta validation still applies, and another component can overwrite/delete keys later.

## Feature name constants

| Constant | Exact value |
| --- | --- |
| `FeatureBlocklist` | `blocklist` |
| `FeatureRBL` | `rbl` |
| `FeatureBruteForce` | `brute_force` |
| `FeatureGeoIPPolicy` | `geoip_policyd` |
| `FeatureFailedLoginHotspot` | `failed_login_hotspot` |
| `FeatureAccountProtection` | `account_protection` |
| `FeatureGeoIPReputation` | `geoip_reputation` |
| `FeatureGlobalPattern` | `global_pattern` |
| `FeatureDynamicResponse` | `dynamic_response` |
| `FeatureHaveIBeenPwned` | `haveibeenpwnd` |

The package uses this table order when it enumerates standard feature-marker sources. Unknown feature names follow in lexical order.

## Field constants

| Constant | Exact value | Meaning |
| --- | --- | --- |
| `FieldTriggered` | `triggered` | Marker contributed to the decision. |
| `FieldDecision` | `decision` | Bounded hint such as `suspicious`. |
| `FieldSource` | `source` | Low-cardinality producer/data-source name. |
| `FieldReason` | `reason` | Optional bounded reason. |
| `FieldHashInfo` | `hash_info` | HIBP short prefix/count information used by analytics. It must remain secret-safe. |
| `FieldLeaked` | `leaked` | HIBP leak boolean. |
| `FieldCount` | `count` | Non-negative HIBP leak count. |

## `FeatureMarker`

```go
type FeatureMarker struct {
    Triggered bool
    Decision  string
    Source    string
    Reason    string
}
```

`Triggered` is included in a built value only when true. `Decision`, `Source`, and `Reason` are trimmed and included only when non-empty. Builders do not enforce length/cardinality or a decision enum.

## Feature builders

### `FeatureKey`

```go
func FeatureKey(name string) string
```

Returns `KeyFeaturePrefix + strings.TrimSpace(name)`. Empty input therefore returns the prefix itself; use `FeatureRuntimeDelta` when you want empty names rejected.

### `FeatureMarkerValue`

```go
func FeatureMarkerValue(marker FeatureMarker) map[string]any
```

Returns a new map containing the non-zero marker fields under the field constants above. False/blank fields are omitted; the result can be empty.

### `FeatureRuntimeDelta`

```go
func FeatureRuntimeDelta(name string, marker FeatureMarker) pluginapi.RuntimeDelta
```

Trims `name`. Empty returns a zero delta. Otherwise it builds the marker map and returns a delta only when that map is non-empty; the key is `plugin.exchange.feature.<name>`. It does not validate the feature name against the predefined constants.

## `HIBPResult`

```go
type HIBPResult struct {
    HashInfo string
    Leaked   *bool
    Count    *uint64
}
```

`HashInfo` is trimmed and omitted when empty. Pointer fields distinguish absent from explicit false/zero. The type name does not make arbitrary `HashInfo` content safe: never put a full password hash or password-derived secret in it.

## HIBP builders

### `HIBPValue`

```go
func HIBPValue(result HIBPResult) map[string]any
```

Returns a new map. It includes non-empty trimmed `HashInfo`, and includes `Leaked`/`Count` whenever their pointers are non-nil, including false and zero.

### `HIBPRuntimeDelta`

```go
func HIBPRuntimeDelta(result HIBPResult) pluginapi.RuntimeDelta
```

Stores the non-empty `HIBPValue` under `KeyHaveIBeenPwned`; an entirely empty value yields a zero delta.

## GeoIP builders

### `GeoIPValue`

```go
func GeoIPValue(fields map[string]any) map[string]any
```

Returns a defensive copy using the package's supported-container clone rules described below. It does not prescribe or validate field names/types.

### `GeoIPRuntimeDelta`

```go
func GeoIPRuntimeDelta(fields map[string]any) pluginapi.RuntimeDelta
```

Stores a non-empty copied map at `KeyGeoIP`; empty input yields a zero delta.

### `GeoIPReputationValue`

```go
func GeoIPReputationValue(fields map[string]any) map[string]any
```

Defensive-copy equivalent for reputation data.

### `GeoIPReputationRuntimeDelta`

```go
func GeoIPReputationRuntimeDelta(fields map[string]any) pluginapi.RuntimeDelta
```

Stores a non-empty copied map at `KeyGeoIPReputation`; empty input yields a zero delta.

## `Snapshot`

```go
type Snapshot struct {
    // unexported values and fact indexes
}
```

`Snapshot` has no exported fields. Its zero value is safe for reads: missing values produce nil/empty outputs.

### `NewSnapshot`

```go
func NewSnapshot(runtime pluginapi.RuntimeContext, facts []pluginapi.PolicyFact) Snapshot
```

Calls `runtime.Snapshot()` when non-nil, otherwise uses an empty map, then delegates to `NewSnapshotFromValues`.

### `NewSnapshotFromValues`

```go
func NewSnapshotFromValues(values map[string]any, facts []pluginapi.PolicyFact) Snapshot
```

Copies supported runtime containers and indexes recognized policy facts by feature namespace. It recognizes:

```text
lua.plugin.<namespace>.<field...>
plugin.<producer>.<namespace>.<field...>
```

For the native form, `<producer>` is skipped; namespace is the next segment. Attributes with too few segments or another prefix are ignored. Deeper field segments are rejoined with dots. If facts repeat the same namespace/field, the later fact wins.

### `Snapshot.Value`

```go
func (s Snapshot) Value(key string) any
```

Returns a clone of the raw runtime value at `key`; a missing key returns nil. No prefix restriction is applied.

### `Snapshot.Map`

```go
func (s Snapshot) Map(key string) map[string]any
```

Converts/copies a map-like runtime value through `MapValue`; unsupported or missing values return nil.

### `Snapshot.HIBPHashInfo`

```go
func (s Snapshot) HIBPHashInfo() string
```

Reads `FieldHashInfo` from the `KeyHaveIBeenPwned` map and converts it through `StringValue`. No policy-fact fallback is used.

### `Snapshot.GeoIPReputation`

```go
func (s Snapshot) GeoIPReputation() map[string]any
```

Returns only an explicitly supplied runtime `KeyGeoIPReputation` map for historical analytics. There is no policy-fact fallback: facts indexed under namespace `geoip_reputation` are ignored. An absent value returns `nil`.

### `Snapshot.DecisionSources`

```go
func (s Snapshot) DecisionSources() []string
```

Returns deterministic, first-seen, exact-string-deduplicated source names in this collection order:

1. explicit `KeyDecisionSources` normalized by `StringList`;
2. triggered feature-marker keys, known features in the constant order above, then unknown features lexically;
3. implied exchange sources:
   - `KeyGeoIP["rejected"]` -> `geoip_policyd`;
   - `KeyFailedLoginHotspot["triggered"]` -> `failed_login_hotspot`;
   - `KeyAccountProtection["active"]` -> `account_protection`;
   - case-insensitive trimmed `KeyGeoIPReputation["decision"] == "suspicious"` -> `geoip_reputation`;
4. implied policy-fact sources:
   - `blocklist.matched` -> `blocklist`;
   - `geoip.rejected` -> `geoip_policyd`;
   - `failed_login_hotspot.triggered`;
   - `account_protection.active`.

A `geoip_reputation` policy fact no longer implies a decision source; only the explicit runtime exchange map above does.

Feature markers add their feature name only when `triggered` is truthy. Dedupe preserves the first occurrence and is case-sensitive. Blank source names are skipped.

### `Snapshot.DecisionSourcesString`

```go
func (s Snapshot) DecisionSourcesString() string
```

Joins `DecisionSources()` with commas and no spaces. Empty sources produce `""`. Do not use this unbounded analytics field as a metric label without an explicit finite allowlist.

## Conversion functions

### `MapValue`

```go
func MapValue(value any) map[string]any
```

Accepted inputs:

- `map[string]any`: cloned with supported-container rules;
- `map[string]string`: converted to `map[string]any`;
- `map[string]bool`: converted to `map[string]any`;
- nil or anything else: nil.

### `StringValue`

```go
func StringValue(value any) string
```

Nil becomes `""`; strings are returned unchanged; `fmt.Stringer` uses `String`; everything else uses `fmt.Sprint`. It does not trim, bound, redact, or reject container values.

### `StringList`

```go
func StringList(value any) []string
```

| Input | Result |
| --- | --- |
| `[]string` | Trim each item, drop blanks, preserve order and duplicates. |
| `[]any` | Convert each item with `StringValue`, trim/drop blanks, preserve order and duplicates. |
| `map[string]any` | Select keys whose value is `Truthy`, trim/drop blank keys, sort lexically. |
| `map[string]bool` | Select true keys, trim/drop blanks, sort lexically. |
| other/nil | nil. |

### `Truthy`

```go
func Truthy(value any) bool
```

Returns true only for boolean `true` or a string equal to `true` after trimming and case-folding. Boolean false and string `false` return false. Numbers, non-boolean strings, and all other types return false; non-zero numbers are **not** truthy.

## Copy boundary

The package recursively copies `map[string]any`, `[]any`, and `[]string`. It converts top-level `map[string]string` and `map[string]bool` in `MapValue`. Other nested reference-shaped values are returned as-is by the generic clone path. Therefore `NewSnapshotFromValues` is not a universal deep-copy function for arbitrary custom maps/slices/pointers. Runtime values obtained from the host's normalized `RuntimeContext` are the intended safe input; callers supplying raw values must restrict them to supported JSON-like containers or make their own deep copy.
