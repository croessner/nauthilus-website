---
title: Host Services
description: Complete HTTP, mail, connection, Redis, cache, helper, LDAP, metrics, and tracing API reference
keywords: [HTTPClient, Mailer, Redis, Cache, LDAP, Metrics, Tracer]
sidebar_position: 7
---

# Host Services

Obtain these facades from [`Host`](./contract.md#host). Native plugins are trusted in-process code; facades provide stable value contracts, validation, and observability, not sandboxing.

## Public service errors

| Variable | Returned when |
| --- | --- |
| `ErrInvalidRedisScriptName` | A named script does not match `[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}`. |
| `ErrRedisScriptNotFound` | `RedisScriptRegistry.Run` names no uploaded script. |
| `ErrInvalidHTTPRequest` | An HTTP method, URL, service, timeout, body limit, header name, or header value is invalid. |
| `ErrHTTPResponseTooLarge` | Reading would exceed the selected response body limit. No truncated success response is returned. |
| `ErrInvalidConnectionTarget` | Target address, direction, or labels are invalid. |
| `ErrConnectionTargetConflict` | A duplicate name/address registration is not idempotently identical. |

Use `errors.Is`. Additional transport/facade errors are not guaranteed sentinel values and should be classified/redacted before logging.

## Backend candidates

### `BackendServers`

```go
type BackendServers interface {
    List(context.Context) []BackendServerCandidate
}
```

`List` returns an immutable snapshot of monitored candidates described in [Common results](./results.md#backendservercandidate). The current facade ignores cancellation during the in-memory list operation. It returns no error; an unavailable/empty monitor yields an empty slice.

## Outbound HTTP

### `HTTPRequest`

```go
type HTTPRequest struct {
    Headers          map[string][]string
    Body             []byte
    Method           string
    URL              string
    Service          string
    Timeout          time.Duration
    MaxResponseBytes int64
}
```

| Field | Validation and default |
| --- | --- |
| `Headers` | Copied. Names must be valid HTTP tokens; values cannot contain CR/LF. `Connection`, `Keep-Alive`, `Proxy-Connection`, `Trailer`, `Transfer-Encoding`, and `Upgrade` are rejected. Trace propagation can add/replace tracing headers. |
| `Body` | Copied request bytes. The facade imposes no separate request-body maximum; plugin config must bound it. |
| `Method` | Trimmed and uppercased. Empty defaults to `GET`; must be an HTTP token no longer than 32 bytes. |
| `URL` | Required absolute `http` or `https` URL with a host. User info and query are allowed by parser but must not contain secrets. There is no production SSRF host/IP allowlist. |
| `Service` | Low-cardinality component-name label. Empty defaults to the facade scope; resulting value must match the component grammar. |
| `Timeout` | Zero defaults to 10 seconds; negative is invalid. A positive value creates a child deadline in addition to the caller context. |
| `MaxResponseBytes` | Zero defaults to 1 MiB; negative is invalid. A response one byte over the limit fails closed with `ErrHTTPResponseTooLarge`. |

### `HTTPResponse`

```go
type HTTPResponse struct {
    Headers    map[string][]string
    Body       []byte
    StatusCode int
}
```

`StatusCode` is the upstream status; non-2xx responses are still successful facade calls. `Headers` are copied with hop-by-hop fields above removed. `Body` is the complete bounded body. Transport, cancellation, validation, or size failures return an empty response plus error.

### `HTTPClient`

```go
type HTTPClient interface {
    Do(context.Context, HTTPRequest) (HTTPResponse, error)
}
```

The current adapter injects OpenTelemetry propagation, records bounded service/method/result metrics, and creates spans containing destination host and port. It logs no URL/query/header/body or raw transport error, but the span still discloses the target host/port. Redirect behavior follows the host `http.Client`. Validate endpoint allowlists in plugin configuration.

## Mail

### `MailMessage`

```go
type MailMessage struct {
    To       []string
    Server   string
    HeloName string
    Username string
    Password string
    From     string
    Subject  string
    Body     string
    Port     int
    TLS      bool
    StartTLS bool
    LMTP     bool
}
```

| Field | Meaning and current validation |
| --- | --- |
| `To` | Recipient strings. At least one non-blank value required; syntax is not otherwise parsed by the facade. |
| `Server` | Required non-blank SMTP/LMTP server. No host allowlist is applied. |
| `HeloName` | Optional HELO/EHLO/LHLO name passed to the transport. |
| `Username` | Optional transport authentication user. Secret-sensitive. |
| `Password` | Optional transport password in a plain Go string. Never log/retain it; prefer operator-managed configuration. |
| `From` | Required non-blank envelope/sender value; syntax is not otherwise parsed here. |
| `Subject` | Message subject. Not logged by the facade. |
| `Body` | Message body. Not logged by the facade. |
| `Port` | Required integer from 1 through 65535. |
| `TLS` | Requests direct TLS according to the host SMTP client. |
| `StartTLS` | Requests STARTTLS according to that client. The public facade does not reject contradictory TLS flags. |
| `LMTP` | Selects LMTP instead of SMTP. |

### `Mailer`

```go
type Mailer interface {
    Send(context.Context, MailMessage) error
}
```

`Send` is synchronous. The scope supplied to `Host.Mail` must satisfy the component-name grammar. The adapter checks `ctx.Err()` before transport, but the current SMTP/LMTP client call does not receive the context, so cancellation after sending begins may not interrupt it. Errors are classified/redacted; logs omit server, recipients, subject, body, credentials, and raw error. The current host does not independently enforce `CapabilityMail` at this call boundary.

## Connection targets

### `ConnectionTargetDirection`

```go
type ConnectionTargetDirection string
```

| Constant | Value | Meaning |
| --- | --- | --- |
| `ConnectionTargetDirectionLocal` | `"local"` | Observe matching local/listening endpoints. |
| `ConnectionTargetDirectionRemote` | `"remote"` | Observe matching remote/outbound endpoints. |

### `ConnectionTarget`

```go
type ConnectionTarget struct {
    Labels      map[string]string
    Name        string
    Address     string
    Description string
    Direction   ConnectionTargetDirection
}
```

| Field | Validation |
| --- | --- |
| `Labels` | Optional copied labels. Only `component`, `protocol`, `role`, and `service` are accepted. Every supplied value must be non-empty, match the component grammar, and be at most 64 bytes. Labels are registration metadata; current low-level counter registration is driven by address/direction/description. |
| `Name` | Required valid component name; process-facade unique. |
| `Address` | Required `host:port`, normalized with `net.JoinHostPort`; host non-blank, port 1-65535. No URL, credentials, or path. |
| `Description` | Trimmed text; empty defaults to `Name`. Do not include secrets or high-cardinality data. |
| `Direction` | Exactly `local` or `remote`. |

### `ConnectionTargets`

```go
type ConnectionTargets interface {
    Register(context.Context, ConnectionTarget) error
    Count(context.Context, string) (int, bool)
}
```

`Register` is idempotent when the same name, normalized address, and direction repeat. Reusing a name with different identity, or the same direction/address under another name, returns `ErrConnectionTargetConflict`. `Count` looks up a registered name and returns the current observed count plus availability. The `scope` passed to `Host.ConnectionTargets` is currently ignored, so names share one process registry across modules. This service observes connections; it does not dial or authorize them.

## Redis

The root public API exposes exact `github.com/redis/go-redis/v9` interfaces. Their package version is therefore part of the Go plugin ABI.

### `Redis`

```go
type Redis interface {
    Read() redis.Cmdable
    Write() redis.Cmdable
    ReadPipeline() redis.Pipeliner
    WritePipeline() redis.Pipeliner
    Keys() RedisKeyBuilder
    Scripts() RedisScriptRegistry
}
```

`Host.Redis()` can return nil; each direct command/pipeline handle can also be nil. `Read`/`Write` choose host-configured handles, while pipeline methods return fresh host pipelines whose execution/closure remains the plugin's responsibility. Direct handles expose the full go-redis command surface, have no module namespace or capability gate, and can bypass `RedisKeyBuilder`; use them only with reviewed, host-prefixed keys and explicit contexts.

### `RedisKeyBuilder`

```go
type RedisKeyBuilder interface {
    Key(string) string
    Keys(...string) []string
    SameSlot([]string, string) []string
}
```

`Key` and `Keys` apply the configured host Redis prefix. `SameSlot` returns keys adjusted to share a Redis Cluster slot. A blank hash tag defaults to `{nauthilus-plugin}`; unbraced input is braced. This can rewrite keys, so use the returned slice. It does not apply a per-module namespace.

### `RedisScriptRegistry`

```go
type RedisScriptRegistry interface {
    Upload(context.Context, string, string) (string, error)
    Run(context.Context, string, []string, ...any) (any, error)
}
```

`Upload` requires a non-blank source and a name matching `[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}`; it loads on the write handle, best-effort loads read handles, stores source plus SHA, and returns the SHA. Names are process-global and a later upload replaces an earlier script, including across modules.

`Run` requires a previously uploaded name. It evaluates by SHA on the write handle. A missing caller deadline gets the current five-second script timeout. On `NOSCRIPT` it reloads and retries once. Multi-key cluster calls, and calls that return `CROSSSLOT`, can have keys rewritten with `{nauthilus-plugin}` before retry. Returned values and Redis errors are raw go-redis values/errors; redact before logging.

## Process-local cache

### `Cache`

```go
type Cache interface {
    Set(context.Context, string, any, time.Duration)
    Get(context.Context, string) (any, bool)
    Delete(context.Context, string) bool
    Exists(context.Context, string) bool
    Push(context.Context, string, any) int
    PopAll(context.Context, string) []any
    Clear(context.Context)
}
```

| Method | Behavior |
| --- | --- |
| `Set` | Stores `value` under `key` with TTL. The underlying process cache defines zero/negative TTL behavior. |
| `Get` | Returns a present, non-expired value and true. |
| `Delete` | Deletes a key and reports whether it existed. |
| `Exists` | Reports present and non-expired state. |
| `Push` | Appends to a list value and returns its new length. |
| `PopAll` | Returns all list values and clears the key. |
| `Clear` | Flushes this scope's cache. |

`Host.Cache(scope)` requires `scope` to match the module-name grammar and returns an error otherwise. The registry key is only that supplied scope; the configured module is not automatically included, so equal scopes share a cache across modules. Entries are cleaned on a 30-second interval. Current methods ignore their contexts and store/return raw Go references rather than deep copies. Do not cache secrets or mutable values without making your own copies; bound keys, values, list length, and TTL.

## Deterministic helpers

### `DeterministicHelpers`

```go
type DeterministicHelpers interface {
    AccountTag(string) string
    ScopedIP(string, string) string
    IsRoutableIP(string) bool
}
```

`AccountTag` uses host-configured account hash-tag behavior. `ScopedIP` takes
`contextName` first and `ip` second. Context `rwp` or
`repeating_wrong_password` selects the repeating-wrong-password IPv6 prefix,
`tolerations` selects the toleration prefix, and every other context selects the
Lua-compatible default IPv4/IPv6 grouping. `IsRoutableIP` applies the shared
deterministic routability test. These are pure, non-secret helpers and may differ
from the standalone package through host configuration. See
[`helpers`](./helpers.md) for explicit option-based variants.

## LDAP

`Host.LDAP()` can return nil. The production facade queues work at low priority and waits for a reply. Without a caller deadline it can wait indefinitely.

### `LDAPScope`

```go
type LDAPScope string
```

| Constant | Value |
| --- | --- |
| `LDAPScopeBase` | `"base"` |
| `LDAPScopeOne` | `"one"` |
| `LDAPScopeSub` | `"sub"` |

Only these values are accepted by `Search`.

### `LDAPModifyOperation`

```go
type LDAPModifyOperation string
```

| Constant | Value |
| --- | --- |
| `LDAPModifyAdd` | `"add"` |
| `LDAPModifyDelete` | `"delete"` |
| `LDAPModifyReplace` | `"replace"` |

Only these values are accepted by `Modify`.

### LDAP value structs

```go
type LDAPSearchRequest struct {
    Attributes []string
    PoolName   string
    BaseDN     string
    Filter     string
    Scope      LDAPScope
}

type LDAPSearchResult struct {
    Attributes map[string][]string
    Entries    []LDAPEntry
}

type LDAPModifyRequest struct {
    Attributes map[string][]string
    PoolName   string
    DN         string
    Operation  LDAPModifyOperation
}

type LDAPEntry struct {
    Attributes map[string][]string
    DN         string
}
```

| Field | Meaning |
| --- | --- |
| `LDAPSearchRequest.Attributes` | Requested attribute names; copied by the facade. |
| `LDAPSearchRequest.PoolName` | Host LDAP pool selector. |
| `LDAPSearchRequest.BaseDN` | Search base DN. |
| `LDAPSearchRequest.Filter` | Complete LDAP filter string. The facade does not escape or validate it. |
| `LDAPSearchRequest.Scope` | Required supported scope above. |
| `LDAPSearchResult.Attributes` | Host-flattened attribute map from the LDAP reply. |
| `LDAPSearchResult.Entries` | Per-entry result values. |
| `LDAPModifyRequest.Attributes` | Copied attribute/value mutations. |
| `LDAPModifyRequest.PoolName` | Host LDAP pool selector. |
| `LDAPModifyRequest.DN` | Target DN. The facade does not validate syntax. |
| `LDAPModifyRequest.Operation` | Required supported operation above. |
| `LDAPEntry.Attributes` | Copied attributes for one entry. |
| `LDAPEntry.DN` | Entry distinguished name. |

Current public validation checks only the scope/operation enums. It does not require non-empty pool/base/DN/filter/attribute names, escape filters, or enforce field size. Build filters with LDAP escaping, validate plugin config, bound results, and never log raw filters, DNs, or sensitive attributes.

### `LDAP`

```go
type LDAP interface {
    Search(context.Context, LDAPSearchRequest) (LDAPSearchResult, error)
    Modify(context.Context, LDAPModifyRequest) error
}
```

Both methods clone mutable request containers before queueing and honor caller cancellation while waiting for a reply. Queue/LDAP errors can contain sensitive server text; classify/redact them.

## Metrics

### `MetricDefinition`

```go
type MetricDefinition struct {
    Buckets []float64
    Labels  []string
    Name    string
    Help    string
}
```

| Field | Validation/default |
| --- | --- |
| `Buckets` | Histogram buckets. Copied. Empty uses Prometheus default buckets. Ignored by counter, gauge, and summary. |
| `Labels` | Exact required labels. Names must match `[a-zA-Z_:][a-zA-Z0-9_:]*`, be unique, and cannot be reserved `plugin_scope`. |
| `Name` | Required Prometheus-style name using the same grammar. Host collector becomes `nauthilus_plugin_<sanitized scope>_<sanitized name>`. |
| `Help` | Prometheus help text. Empty receives a host-generated non-empty help string. Do not include secrets. |

Scope/name sanitization replaces unsupported characters with `_`, so distinct input scopes/names can collide at collector registration. Metric registration returns such errors. The supplied scope itself is not validated or bounded and is exported unchanged as the automatic `plugin_scope` label; keep it static and low-cardinality.

### `LabelValue`

```go
type LabelValue struct {
    Name  string
    Value string
}
```

Every observation must supply every declared label exactly once, no unknown/duplicate labels. Values must be non-empty and at most 256 bytes. Invalid observations are silently dropped because handle methods return no error. Keep values low-cardinality and non-secret.

### Instrument interfaces

```go
type Counter interface {
    Add(context.Context, float64, ...LabelValue)
}

type Gauge interface {
    Set(context.Context, float64, ...LabelValue)
    Add(context.Context, float64, ...LabelValue)
}

type Histogram interface {
    Observe(context.Context, float64, ...LabelValue)
}

type Summary interface {
    Observe(context.Context, float64, ...LabelValue)
}
```

Counter negative additions are silently dropped. Gauges accept set/add values. Histograms and summaries accept observations. Current adapters ignore the passed context. `Summary` registers no configured quantile objectives, so it exposes count/sum rather than plugin-defined quantiles.

### `Metrics`

```go
type Metrics interface {
    Counter(MetricDefinition) (Counter, error)
    Gauge(MetricDefinition) (Gauge, error)
    Histogram(MetricDefinition) (Histogram, error)
    Summary(MetricDefinition) (Summary, error)
}
```

Each method validates and registers, or returns an existing handle for the same facade, kind, and name. Metrics are keyed by supplied scope, not automatically by configured plugin module. The scope is caller-controlled and receives no component-name validation.

## Tracing

### `TraceAttribute`

```go
type TraceAttribute struct {
    Key   string
    Value any
}
```

`Key` and `Value` are public and have no API-level bounds. The current adapter preserves bool, int, int64, float64, and string types; other values become `fmt.Sprint` strings. Never attach secrets, unbounded/high-cardinality data, raw URLs/query strings, raw external errors, or request snapshots.

### `Span`

```go
type Span interface {
    AddEvent(string, ...TraceAttribute)
    SetAttributes(...TraceAttribute)
    RecordError(error)
    End()
}
```

`AddEvent` records a named event and attributes. `SetAttributes` updates span attributes. `RecordError` records the supplied error verbatim in the current adapter, so redact first. `End` must be called exactly once by normal plugin code; conventionally `defer span.End()` immediately after start.

### `Tracer`

```go
type Tracer interface {
    Start(context.Context, string, ...TraceAttribute) (context.Context, Span)
}
```

`Start` returns a derived propagation context and host-owned span. Use the returned context for downstream facade/network calls. The span name and attributes are not automatically validated for secrecy or cardinality. A no-op host tracer returns the input context and safe no-op span.
