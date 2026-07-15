---
title: Validation
description: Public validation errors, name grammars, selectors, builders, and metadata checks
keywords: [ValidateMetadata, ValidateComponentName, ErrInvalidName, debug selector]
sidebar_position: 10
---

# Validation

## Public validation errors

```go
var ErrUnsupportedAPIVersion = errors.New("unsupported plugin API version")
var ErrInvalidName = errors.New("invalid plugin name")
var ErrInvalidMetadata = errors.New("invalid plugin metadata")
```

Use `errors.Is` because public functions wrap these sentinels with context. Service-specific public errors are listed in [Host services](./services.md#public-service-errors).

## Name grammar

Module names, component names, and non-reserved debug-module names use the exact regular expression:

```text
^[a-z0-9][a-z0-9_]{0,62}$
```

This permits 1-63 lowercase ASCII letters, digits, and underscores, with a letter or digit first. It does not trim input. Dashes, dots, uppercase letters, whitespace, and non-ASCII characters are invalid.

Backend attribute names use `^[!-~]+$`: one or more printable ASCII bytes from `!` through `~`, excluding spaces and all controls/non-ASCII.

## Validation functions

### `ValidateAPIVersion`

```go
func ValidateAPIVersion(version string) error
```

Returns nil only for exact `APIVersion`; otherwise wraps `ErrUnsupportedAPIVersion` and reports actual/expected strings.

### `ValidateModuleName`

```go
func ValidateModuleName(name string) error
```

Applies the strict name grammar above and wraps `ErrInvalidName` on failure.

### `ValidateComponentName`

```go
func ValidateComponentName(name string) error
```

Applies the same strict grammar for plugin-local components, policy ID segments, and several bounded service labels.

### `ValidateDebugModuleName`

```go
func ValidateDebugModuleName(name string) error
```

Applies the strict name grammar, then rejects these reserved core names:

```text
account, action, all, auth, brute_force, cache, cookie, environment,
http, idp, jwt, ldap, ldappool, lua, none, plugin, policy, rbl,
statistics, subject, tolerate, webauthn, whitelist
```

The error wraps `ErrInvalidName`.

### `ValidateBackendAttributeName`

```go
func ValidateBackendAttributeName(name string) error
```

Requires non-empty printable ASCII without spaces (`^[!-~]+$`). It is used for backend attribute and identity/account field names. General `AttributePatch` handling is currently less strict, but plugins should apply this function consistently.

### `ValidateQualifiedComponentName`

```go
func ValidateQualifiedComponentName(name string) error
```

Requires exactly `<module>.<component>` with one dot and validates both segments with their respective functions. Empty segments or another dot in the component are rejected.

### `ValidatePluginDebugSelector`

```go
func ValidatePluginDebugSelector(selector string) error
```

Accepts exactly these shapes:

```text
plugin
plugin.<module>
plugin.<module>.<debug_module>
```

It validates module and debug-module segments, including the reserved-name rule. Input is not trimmed.

### `IsPluginDebugSelector`

```go
func IsPluginDebugSelector(value string) bool
```

Returns true for `plugin` or any string starting with `plugin.`. It is a namespace/prefix test, not full validation; for example, malformed deeper selectors can return true. Call `ValidatePluginDebugSelector` when syntax matters.

### `PluginDebugModuleSelector`

```go
func PluginDebugModuleSelector(module string) (string, error)
```

Validates `module` and returns `plugin.<module>`.

### `PluginDebugSubmoduleSelector`

```go
func PluginDebugSubmoduleSelector(module, name string) (string, error)
```

Validates the module and non-reserved debug-module name and returns `plugin.<module>.<name>`.

### `QualifiedComponentName`

```go
func QualifiedComponentName(module, component string) (string, error)
```

Validates both local segments and returns `<module>.<component>`. It does not consult the registry, so successful construction does not prove the component exists.

### `ValidateMetadata`

```go
func ValidateMetadata(metadata Metadata) error
```

Validates only:

1. `metadata.APIVersion` exactly matches `APIVersion`;
2. `strings.TrimSpace(metadata.Name)` is non-empty;
3. `strings.TrimSpace(metadata.Version)` is non-empty.

Failures wrap `ErrInvalidMetadata`; API mismatch also wraps `ErrUnsupportedAPIVersion`. It does **not** apply the module/component grammar to product `Name`, require SemVer, parse `DocsURL`, validate features/capabilities, or validate build metadata.

## Validation ownership

Public helpers cover reusable source-level grammars. Registration and individual host facades add further checks for descriptors, policy definitions, HTTP, Redis scripts, cache scope, metrics, hooks, LDAP enums, mail, and connection targets. Request-time outputs such as runtime values and policy facts are also adapter-validated. Compile-time success alone is therefore not proof that a declaration/result will be accepted.
