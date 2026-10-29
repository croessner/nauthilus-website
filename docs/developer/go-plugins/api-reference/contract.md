---
title: Core Contract
description: API version, metadata, plugin lifecycle, registration, configuration, host, and logging declarations
keywords: [APIVersion, Plugin, Registrar, RuntimePlugin, Host, ConfigView]
sidebar_position: 2
---

# Core Contract

Package import:

```go
import pluginapi "github.com/croessner/nauthilus/v4/pluginapi/v1"
```

## `APIVersion`

```go
const APIVersion = "nauthilus.plugin.v1"
```

The factory result must return this exact value in `Metadata.APIVersion`. `ValidateAPIVersion` and host metadata validation reject any other value. It does not relax Go shared-object ABI matching.

## `Capability`

```go
type Capability string
```

Capabilities are cooperative, host-controlled permissions requested during registration.

| Constant | Value | Current behavior |
| --- | --- | --- |
| `CapabilityCredentials` | `"credentials"` | Required before a module receives a usable request `CredentialProvider`; the operator must also allow it. |
| `CapabilityPasswordHash` | `"password_hash"` | Required before a detached post-action receives `PostActionRequest.PasswordHash`. It grants no raw credential access, and `credentials` does not imply it. The operator must also allow it. |
| `CapabilityMail` | `"mail"` | Declares mail intent. The current `Host.Mail` facade does **not** independently enforce that it was requested, so artifact trust and operator review remain essential. |

`Metadata.Capabilities` is discovery metadata only. It does not grant a capability. Call `Registrar.RequireCapability`. If an operator omits `allow_capabilities`, the current loader treats `credentials`, `password_hash`, and `mail` as sensitive and denies them by default; unknown capability strings can be self-requested but have no defined host effect.

## `Feature`

```go
type Feature string
```

`Feature` is an open discovery label in `Metadata.Features`. There are no predefined constants and no authorization or automatic registration semantics.

## `BuildInfo`

```go
type BuildInfo struct {
    ArtifactIdentity string
    BuildTags        []string
    GoVersion        string
    GitCommit        string
    BuildTime        string
}
```

| Field | Meaning and validation |
| --- | --- |
| `ArtifactIdentity` | Diagnostic native build identity. Set it to `pluginapi.NativeArtifactIdentity()`. It records the coherent host/plugin build set; it is not an ABI stability promise and does not replace the loader preflight. |
| `BuildTags` | Diagnostic build tags. No public semantic validation; preserve stable, non-secret values. |
| `GoVersion` | Diagnostic Go toolchain string. It does not make the artifact ABI-compatible. |
| `GitCommit` | Diagnostic source revision. Not used for trust verification. |
| `BuildTime` | Diagnostic build timestamp string; no required format. |

All fields are public surface and discovery only.

## `NativeArtifactIdentity`

```go
func NativeArtifactIdentity() string
```

Returns the identity that the coherent native build workflow embedded through `-ldflags`
(`nauthilus-native-artifact-v1:<sha256>:end-native-artifact`). An unmarked build returns an empty string. The loader
compares every identity embedded in a plugin artifact with the host identity before `plugin.Open`; an empty, stale, or
mixed identity fails with "native artifact does not match the host build identity". See
[Build, test, and debug](../build-test-debug.md#native-artifact-identity).

## `Metadata`

```go
type Metadata struct {
    Build        BuildInfo
    Name         string
    Version      string
    APIVersion   string
    Description  string
    DocsURL      string
    Features     []Feature
    Capabilities []Capability
}
```

| Field | Requirement and current use |
| --- | --- |
| `Build` | Optional diagnostic metadata. |
| `Name` | Required, non-blank product name. Unlike module/component names, public validation only checks non-blank text. |
| `Version` | Required, non-blank product version. No SemVer requirement. |
| `APIVersion` | Required and exactly `APIVersion`. |
| `Description` | Optional discovery text. |
| `DocsURL` | Optional discovery URL; public metadata validation does not parse it. |
| `Features` | Optional discovery labels. |
| `Capabilities` | Optional discovery declaration; not a permission grant. |

`Metadata()` is called before registration. Invalid metadata prevents the module from becoming available. Metadata and factory calls are panic-protected.

## `DebugModuleDefinition`

```go
type DebugModuleDefinition struct {
    Name        string
    Description string
}
```

`Name` must satisfy `ValidateDebugModuleName`; `Description` is optional discovery text. Registration creates the selector `plugin.<module>.<name>`. Reserved core selector names are rejected.

## `Plugin`

```go
type Plugin interface {
    Metadata() Metadata
    Register(Registrar) error
}
```

Every exported `NauthilusPlugin` factory returns a fresh `Plugin` instance. `Metadata` is read first. `Register` then declares that configured module's components. Returning an error or panicking rejects registration.

Registration is intended as a declaration phase: do not open networks or start workers here. The current registrar validates each declaration, but its final commit is not fully transactional: debug and policy registrations can already be committed before a later component error. Treat `Register` as all-or-nothing in plugin code and prevalidate local state.

## `RuntimePlugin`

```go
type RuntimePlugin interface {
    Start(context.Context, Host) error
    Stop(context.Context) error
}
```

This interface is optional. A plugin without it can still register request-time components.

- Modules start in configured order.
- Registered init tasks start after module `Start` calls, in registration order.
- The runtime becomes ready only after startup completes.
- Shutdown clears readiness, stops init tasks in reverse order, stops modules in reverse order, then cancels and waits for `Host.Go` workers.
- An optional module-level `Start` failure disables that module. An init-task `Start` failure is fatal even for an optional module.
- A fatal later startup failure does not automatically call `Stop` on modules that already started.
- The configured module stop timeout applies to `RuntimePlugin.Stop`, not to `InitTask.Stop`.

Both methods receive host-owned contexts and are panic-protected. Honor cancellation and make `Stop` idempotent.

## `ReloadablePlugin`

```go
type ReloadablePlugin interface {
    Reconfigure(context.Context, ConfigView) error
}
```

This optional interface receives the new module configuration on config-only reload. The host calls `Reconfigure` only for a module whose plugin-owned config changed, only after every changed module validated its candidate, and only after the new Policy generation was committed. `Reconfigure` must be all or nothing: on error the plugin keeps serving its previous configuration, the host keeps the previous config view for the module, reports the reload as failed, and retries the change on the next reload. A config change of a plugin that does not implement `ReloadablePlugin` is rejected as restart-bound. `Host.Config()` is not replaced during reconfigure; retain the new argument if later code needs the updated module view.

## `ReconfigureValidator` and `ErrRestartRequired`

```go
type ReconfigureValidator interface {
    ValidateReconfigure(context.Context, ConfigView) error
}

var ErrRestartRequired = errors.New("plugin configuration change requires a restart")
```

Reloadable plugins can implement `ReconfigureValidator` to check a candidate config before any module is reconfigured. `ValidateReconfigure` decodes and validates only; it must not change plugin state, start work, or reach external systems. Any error rejects the whole reload. An error that wraps `ErrRestartRequired` marks the change as restart-bound instead of invalid, and the host reports the module as `restart_required`. Share the decode-and-validate function with `Reconfigure`. See [Configuration reload](../lifecycle-and-registration.md#configuration-reload).

## `ConfigView`

```go
type ConfigView interface {
    Get(path string) (any, bool)
    GetPath(path []string) (any, bool)
    Sub(path string) ConfigView
    SubPath(path []string) ConfigView
    Decode(target any) error
    IsZero() bool
}
```

| Method | Contract |
| --- | --- |
| `Get` | Looks up a dot-separated path and returns a copied format-neutral value plus presence. |
| `GetPath` | Looks up explicit path segments; use it when keys can contain dots. |
| `Sub` | Returns a read-only subtree for a dot-separated path; a missing path produces a zero view. |
| `SubPath` | Explicit-segment form of `Sub`. |
| `Decode` | Decodes the current subtree into a non-nil target and returns strict conversion/shape errors from the host implementation. |
| `IsZero` | Reports a missing or empty view. |

`Registrar.Config()` is the configured module subtree. `InitContext.Config` is the same module view. `Host.Config()` is different: the current production host serializes the entire loaded Nauthilus configuration into a read-only view once at startup. It can therefore contain inline secrets and does not track `Reconfigure`. Minimize access, never log it, and prefer the module-scoped views.

## `ArgsView`

```go
type ArgsView interface {
    Get(path string) (any, bool)
    GetPath(path []string) (any, bool)
    Sub(path string) ArgsView
    SubPath(path []string) ArgsView
    Decode(target any) error
    IsZero() bool
}
```

The methods have the same lookup semantics as `ConfigView`, but expose policy effect arguments in `ObligationRequest.Args` and `PostActionRequest.Args`. Values are read-only inputs. Validate all decoded data because policy configuration is not a substitute for plugin-level bounds.

## `Registrar`

```go
type Registrar interface {
    Config() ConfigView
    RequireCapability(Capability) error
    RegisterInitTask(InitTask) error
    RegisterEnvironmentSource(EnvironmentSource) error
    RegisterSubjectSource(SubjectSource) error
    RegisterBackend(Backend) error
    RegisterObligationTarget(ObligationTarget) error
    RegisterPostActionTarget(PostActionTarget) error
    RegisterHook(Hook) error
    RegisterPolicyAttribute(AttributeDefinition) error
    RegisterDebugModule(DebugModuleDefinition) error
}
```

| Method | Meaning |
| --- | --- |
| `Config` | Returns this configured module's read-only config subtree. |
| `RequireCapability` | Requests one capability and returns an error when operator policy denies it. Request before registering components that need it. |
| `RegisterInitTask` | Registers one named lifecycle task. Names must be valid and unique in the module. |
| `RegisterEnvironmentSource` | Registers a pre-auth source and validates its descriptor. |
| `RegisterSubjectSource` | Registers a post-backend source and validates its descriptor. |
| `RegisterBackend` | Registers a named authentication/account backend. |
| `RegisterObligationTarget` | Registers a named synchronous policy effect. |
| `RegisterPostActionTarget` | Registers a named post-decision enqueue target. |
| `RegisterHook` | Registers and validates one HTTP hook descriptor. |
| `RegisterPolicyAttribute` | Registers a policy attribute definition. |
| `RegisterDebugModule` | Registers one plugin-local debug selector. |

Nil implementations, invalid names/descriptors, and duplicate qualified names are rejected. Names returned by component `Name` or `Descriptor` methods are evaluated inside panic boundaries.

## `Host`

```go
type Host interface {
    ServiceContext() context.Context
    Logger(scope string) Logger
    Tracer(scope string) Tracer
    CompatibilityTracer(scope string) (Tracer, error)
    Metrics(scope string) Metrics
    HTTP(scope string) HTTPClient
    Mail(scope string) Mailer
    ConnectionTargets(scope string) ConnectionTargets
    BackendServers() BackendServers
    Redis() Redis
    Cache(scope string) (Cache, error)
    OpaqueIdentifierTagger() (OpaqueIdentifierTagger, error)
    Helpers() DeterministicHelpers
    LDAP() LDAP
    Config() ConfigView
    Go(ctx context.Context, name string, fn func(context.Context) error)
}
```

`Host` is supplied to `RuntimePlugin.Start`. `ServiceContext` lasts for the host runtime. The service-returning methods are described in [Host services](./services.md).

Scope validation is facade-specific, not a common `Host` guarantee. Logger,
tracer, and metrics currently accept the raw string; metrics export it unchanged
as the `plugin_scope` label while sanitizing only collector-name fragments.
HTTP, mail, and cache validate at their own boundaries, and connection targets
ignore the scope. Current services also do not all add the configured module
automatically, while Redis scripts are process-global. Supply a stable, bounded,
low-cardinality namespace and avoid cross-module collisions in scopes, metric
names, cache keys, target names, and Redis script names.

`OpaqueIdentifierTagger()` is a required part of the version 4 `Host` contract. When the operator has not configured
`plugins.opaque_identifier_tagger`, it returns `ErrOpaqueIdentifierTaggerUnavailable`; there is no unkeyed fallback. See
[Opaque identifier tagging](./services.md#opaque-identifier-tagging).

`Redis()` and `LDAP()` can return `nil` when the corresponding host service is unavailable. Check before use. `Go` starts supervised work: it preserves context values but detaches caller cancellation, binds the work to host lifetime, recovers panics, logs returned errors in classified/redacted form, and waits for the worker during shutdown. `name` must be a stable low-cardinality identifier; do not pass request or user data.

## `Logger`

```go
type Logger interface {
    Debug(context.Context, string, ...LogField)
    Info(context.Context, string, ...LogField)
    Warn(context.Context, string, ...LogField)
    Error(context.Context, string, ...LogField)
}
```

All four methods emit a message plus `LogField` values through host logging; `Debug` also obeys debug selector configuration. The public interface does not validate field keys or values. Never pass secrets, credential-derived material, session tokens, mail contents, raw LDAP filters, unredacted external errors, or high-cardinality attacker-controlled data.
