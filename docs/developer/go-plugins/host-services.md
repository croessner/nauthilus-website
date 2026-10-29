---
title: Host Services
description: Logging, tracing, metrics, HTTP, mail, Redis, cache, LDAP, backend discovery, and workers for Go plugins
keywords: [pluginapi Host, Redis, LDAP, HTTPClient, Metrics, Tracer, Mailer]
sidebar_position: 5
---

# Host Services

`pluginapi.Host` exposes process-scoped Nauthilus services through narrow interfaces. A runtime plugin receives it in `Start`; components that need a service retain the relevant facade or the host reference on their module instance.

```go
func (p *Plugin) Start(ctx context.Context, host pluginapi.Host) error {
    p.logger = host.Logger("database")
    p.tracer = host.Tracer("database")
    p.metrics = host.Metrics("database")
    p.http = host.HTTP("database")
    return nil
}
```

Scope handling is facade-specific. HTTP, mail, and cache apply explicit name
validation at different points, while logger, tracer, and metrics currently
accept the supplied string without the public component-name validator;
connection targets ignore it. Metrics also export the raw value as the
`plugin_scope` label even though collector-name fragments are sanitized. Always
pass a stable, bounded, low-cardinality identifier yourself. Scopes are not
uniformly prefixed with the configured module name, so independently configured
modules can collide if they choose the same cache, metric, script, or
connection-target names. Never use usernames, addresses, tenant input, or other
request data as a scope.

## Service overview

| Host method | Facade | Ownership boundary |
| --- | --- | --- |
| `ServiceContext()` | `context.Context` | Host lifetime cancellation; never cancel it from plugin code. |
| `Logger(scope)` | `Logger` | Structured host logging and debug-module gating. |
| `Tracer(scope)` | `Tracer` | Child spans rooted in the caller's context. |
| `Metrics(scope)` | `Metrics` | Validated metric definitions; caller-owned scope cardinality. |
| `HTTP(scope)` | `HTTPClient` | Instrumented outbound HTTP with time and body bounds. |
| `Mail(scope)` | `Mailer` | Host SMTP/LMTP transport using value-only messages. |
| `ConnectionTargets(scope)` | `ConnectionTargets` | Generic connection observability, not dialing. |
| `BackendServers()` | `BackendServers` | Immutable monitored backend candidates. |
| `Redis()` | `Redis` | Host Redis handles, key builder, and named script registry. |
| `Cache(scope)` | `Cache` | Process-local module cache. |
| `OpaqueIdentifierTagger()` | `OpaqueIdentifierTagger` | Keyed HMAC tagging with operator-owned keys; returns `ErrOpaqueIdentifierTaggerUnavailable` when unconfigured. |
| `Helpers()` | `DeterministicHelpers` | Host-configured account/IP helper behavior. |
| `LDAP()` | `LDAP` | Host-owned queued LDAP searches and modifications. |
| `Config()` | `ConfigView` | Read-only host-wide configuration view. |
| `Go(ctx, name, fn)` | worker supervisor | Host-lifetime detached work and panic recovery. |

The host does not expose server singletons, mutable request objects, Gin contexts, OpenTelemetry SDK types, raw LDAP connections, or policy engine internals.

## Logging

`Logger` supports `Debug`, `Info`, `Warn`, and `Error` with structured `LogField` values:

```go
logger.Info(ctx, "lookup completed",
    pluginapi.LogField{Key: "lookup_result", Value: "found"},
    pluginapi.LogField{Key: "source", Value: "local"},
)
```

`Debug` records are emitted only when the global level is debug and an applicable selector is enabled. A module has the automatic selector `plugin.<module>`; a local debug module registered as `lookup` has `plugin.<module>.lookup`.

Keep keys stable and values low-cardinality. Do not log:

- credentials, password hashes, or password-derived tokens;
- authorization/cookie headers or session IDs;
- mail recipients, subjects, or bodies;
- raw LDAP filters, SQL statements, query parameters, response bodies, or DSNs;
- raw external errors that may embed any of those values.

Policy facts are not public logs. Use result `Logs` or `PublicPolicyFactLogField` only for values reviewed as public.

## Tracing

`Tracer.Start` returns a derived context and a host-owned `Span`:

```go
callCtx, span := tracer.Start(ctx, "database.lookup",
    pluginapi.TraceAttribute{Key: "component", Value: "passdb"},
)
defer span.End()

if err := lookup(callCtx); err != nil {
    span.RecordError(redact(err))
    return err
}
```

`Span` supports events, attributes, error recording, and `End`. Use the derived context for downstream host HTTP/LDAP calls so propagation and parentage remain correct. Plugin code owns the sensitivity of its attributes and events; the host cannot redact data it never sees structurally. `RecordError` records the supplied error, so pass only a redacted error.

## Metrics

Create instruments with one `MetricDefinition`:

```go
counter, err := host.Metrics("customer_sql").Counter(pluginapi.MetricDefinition{
    Name:   "lookups_total",
    Help:   "Customer SQL lookup results.",
    Labels: []string{"result"},
})
```

Record only declared labels:

```go
counter.Add(ctx, 1, pluginapi.LabelValue{Name: "result", Value: "found"})
```

Available instruments are `Counter`, `Gauge`, `Histogram`, and `Summary`. Histogram buckets are declared in `MetricDefinition.Buckets`; summaries use the host's supported defaults.

Plugin collectors are exported below a host-owned
`nauthilus_plugin_<sanitized scope>_...` namespace. The host reserves its plugin
scope label and rejects malformed or conflicting definitions, but the raw scope
is exported unchanged as the `plugin_scope` label. Never use username, IP
address, account, URL, query, error string, or another unbounded input as a
scope or label.

Every observation must supply exactly the declared labels with non-empty values no longer than 256 bytes. Invalid observations, including a negative counter increment, are silently dropped because observation methods return no error. `Summary` does not expose quantile configuration; `MetricDefinition.Buckets` applies only to histograms. Sanitized scope/name collisions remain possible across modules.

## Outbound HTTP

Use `Host.HTTP(scope).Do` when the value-oriented request is sufficient:

```go
response, err := host.HTTP("reputation").Do(ctx, pluginapi.HTTPRequest{
    Method:           http.MethodGet,
    URL:              endpoint,
    Service:          "reputation_api",
    Headers:          map[string][]string{"Accept": {"application/json"}},
    Timeout:          2 * time.Second,
    MaxResponseBytes: 64 * 1024,
})
```

The facade:

- validates method, URL, timeout, and response limit;
- applies caller or request timeout bounds;
- injects active trace propagation headers;
- returns copied headers, a bounded body, and status code;
- records bounded host HTTP metrics and logs;
- returns `ErrInvalidHTTPRequest` or `ErrHTTPResponseTooLarge` for the corresponding public failures.

The plugin still chooses the endpoint and must validate/redact its config. Host operational logs deliberately avoid URL, query, headers, body, bearer tokens, and raw transport errors.

The facade accepts absolute HTTP and HTTPS URLs but has no destination allowlist; private and loopback targets are possible. Validate plugin-owned endpoints to prevent SSRF. Host HTTP spans include the destination hostname and port even though operational logs omit the URL.

## Mail

`Host.Mail(scope).Send` sends a value-only `MailMessage` through the host SMTP/LMTP transport:

```go
err := host.Mail("notifications").Send(ctx, pluginapi.MailMessage{
    Server:   cfg.Server,
    Port:     cfg.Port,
    HeloName: cfg.HeloName,
    From:     cfg.From,
    To:       recipients,
    Subject:  subject,
    Body:     body,
    TLS:      cfg.TLS,
    StartTLS: cfg.StartTLS,
    LMTP:     cfg.LMTP,
    Username: cfg.Username,
    Password: cfg.Password,
})
```

The plugin owns recipient selection, templates, config validation, and retry semantics. The host owns transport adaptation and bounded result/protocol logging.

Mail validation is intentionally narrow: server, port, sender, recipient presence, and scope are checked, but mailbox syntax and TLS/StartTLS combinations are not. The caller context is checked before the synchronous send; it is not propagated into the underlying SMTP client, so cancellation cannot interrupt an in-progress send.

The public capability model says a mail-using module should declare and require `CapabilityMail`, and the operator should allow `mail`. Current host construction does not turn the mail facade into a sandbox: trusted in-process code can obtain the facade even if it skipped the cooperative registration check. Treat the capability list as an auditable registration contract, not an operating-system permission boundary.

## Connection target observability

`ConnectionTargets` lets a plugin describe an address that the host should count for generic connection visibility:

```go
targets := host.ConnectionTargets("reputation")
err := targets.Register(ctx, pluginapi.ConnectionTarget{
    Name:        "api",
    Address:     "reputation.example.test:443",
    Direction:   pluginapi.ConnectionTargetDirectionRemote,
    Description: "Reputation API",
    Labels:      map[string]string{"service": "reputation"},
})

count, available := targets.Count(ctx, "api")
```

Names, `host:port` addresses, direction, descriptions, and labels are validated. Re-registering an identical target is idempotent; a conflicting duplicate returns `ErrConnectionTargetConflict`. Current runtime wiring does not forward the public `Labels` map to the connection manager, so labels are accepted but have no operational effect. This facade does not open, close, pool, or secure a connection.

## Backend candidates

`Host.BackendServers().List(ctx)` returns copied `BackendServerCandidate` values from host monitoring state. A subject source can filter them and return `candidate.Ref()` as a selected backend.

Candidates expose selection data only: protocol, authority/name when known, address, port, HAProxy v2 setting, and liveness. The list can be empty, and `Name` or `Authority` can be empty when monitoring has no stable value. The host does not automatically select one on behalf of a plugin.

## Redis

`Host.Redis()` exposes the configured host Redis deployment and can be `nil` when no host Redis client is available:

```go
redis := host.Redis()
if redis == nil {
    return errors.New("host Redis is unavailable")
}
value, err := redis.Read().Get(ctx, key).Result()
_, err = redis.Write().Set(ctx, key, value, ttl).Result()
```

Read/write handles implement `redis.Cmdable`; pipeline methods return `redis.Pipeliner`. Plugin code must respect the caller context and avoid unbounded key scans or high-cost operations.

### Key builder

Use `Redis.Keys()` so keys follow the configured Nauthilus prefix and Redis Cluster hash-slot conventions:

```go
tag := host.Helpers().AccountTag(account)
keys := redis.Keys().SameSlot(
    redis.Keys().Keys("acct:"+tag+":lock", "acct:"+tag+":state"),
    tag,
)
```

`Key` and `Keys` add the host prefix without destroying an existing hash tag. `SameSlot` preserves an already matching tag and rewrites mismatching tags to the requested one.

### Script registry

Use stable names for host-managed Lua scripts:

```go
sha, err := redis.Scripts().Upload(ctx, "customer_risk.bump", source)
result, err := redis.Scripts().Run(ctx, "customer_risk.bump", keys, account)
```

`Upload` retains the source and SHA. `Run` requires a previously uploaded name. On `NOSCRIPT`, the host reloads the retained source and retries once. Invalid names and unknown scripts return `ErrInvalidRedisScriptName` and `ErrRedisScriptNotFound`.

The script registry is global to the host, not isolated by module. Uploading the same valid name again replaces the retained source/SHA without a conflict error. Prefix script names with a stable module/product namespace.

Named or additional Redis pools are not exposed. A plugin that needs another deployment owns that client, config, TLS, deadlines, observability, reload swap, and close behavior.

## Process-local cache

`Host.Cache(scope)` returns process-local cache storage keyed by the freely chosen validated scope. It is not automatically isolated by configured module, so two modules using the same scope share/collide. It supports:

- `Set` with TTL, `Get`, `Exists`, and `Delete`;
- list-like `Push` and destructive `PopAll`;
- `Clear`.

The cache is process-local and not durable or replicated. Values are stored and returned without defensive cloning, and cache methods currently ignore their context parameters. Values disappear on restart. Design batching so that a sub-threshold queue cannot be silently mistaken for durable delivery, and implement an explicit flush path when loss at shutdown is unacceptable.

## Deterministic helpers

`Host.Helpers()` offers configuration-aware versions of:

- `AccountTag(account)`;
- `ScopedIP(contextName, ip)`;
- `IsRoutableIP(ip)`.

`ScopedIP` selects the configured grouping rules by context before it scopes the
address. Use `rwp` or `repeating_wrong_password` for the repeating-wrong-password
rules and `tolerations` for the toleration rules. Any other context uses the
Lua-compatible default IPv4/IPv6 grouping. The argument order is deliberately
`contextName` first and `ip` second.

The dependency-light `pluginapi/v1/helpers` subpackage provides explicit option structs for the same algorithms. Prefer the host facade when exact current Nauthilus configuration parity matters; prefer the package when standalone deterministic behavior is needed in plugin tests.

## LDAP

LDAP calls are explicit queued operations. `Host.LDAP()` can be `nil` when the LDAP queue is not configured:

```go
ldap := host.LDAP()
if ldap == nil {
    return errors.New("host LDAP is unavailable")
}
result, err := ldap.Search(ctx, pluginapi.LDAPSearchRequest{
    PoolName:   "default",
    BaseDN:     "ou=people,dc=example,dc=test",
    Filter:     "(uid=sample)",
    Scope:      pluginapi.LDAPScopeSub,
    Attributes: []string{"mail", "memberOf"},
})
```

Modify with one explicit operation:

```go
err := ldap.Modify(ctx, pluginapi.LDAPModifyRequest{
    PoolName:  "default",
    DN:        result.Entries[0].DN,
    Operation: pluginapi.LDAPModifyReplace,
    Attributes: map[string][]string{
        "description": {"updated"},
    },
})
```

Set `AssertionFilter` to make a modify conditional. The host sends the filter as a critical RFC 4528 assertion control, so
the directory applies the change only while the entry still matches, for example an unchanged `entryCSN`. An invalid
filter fails before the request is sent, and a failed assertion is returned as an error; retry only after re-reading the
entry.

Search returns copied `LDAPEntry` values and a flattened attribute map. Public facade validation checks search scope or modify operation, but it does not escape or require non-empty pool names, DNs, filters, or attributes. The plugin owns LDAP filter/DN construction and must set a caller deadline; without one, waiting for a queued response can be unbounded.

The host does not merge results into a backend result. The plugin must deliberately return allowed attributes, facts, or decisions. LDAP queue errors can contain sensitive operational details; redact before logging or translating them into status.

## Opaque identifier tagging

`Host.OpaqueIdentifierTagger()` creates stable pseudonymous tags without giving the plugin key material:

```go
tagger, err := host.OpaqueIdentifierTagger()
if err != nil {
    return err // ErrOpaqueIdentifierTaggerUnavailable when the operator configured no keys
}

tag, err := tagger.Tag(ctx, pluginapi.OpaqueIdentifierInput{
    Scope: "workflow",
    Kind:  "account",
    Value: account,
})
if err != nil {
    return err
}

stored := tag.String() // hmac-sha256-v1:<version>:<authenticator>
```

Use `Tag` for new writes and `Candidates` (active first, then previous) to look up state written before a key rotation.
The scope must be configured by the operator under `plugins.opaque_identifier_tagger`. The exact contract is in
[Host Services reference](./api-reference/services.md#opaque-identifier-tagging).

## Configuration views

`Host.Config()` is a host-wide read-only `ConfigView`; it is materialized from the complete process-start configuration and can include inline secrets. It is not refreshed by plugin reconfiguration. `Registrar.Config()` and `InitContext.Config` point to the module-owned subtree. Both view types support path lookup, subviews, strict decode, and `IsZero`.

Prefer module config for plugin behavior. Reading unrelated global configuration creates hidden coupling to host configuration and can make reload ownership ambiguous.

`Host.Config()` also contains two host-generated projections:

| Path | Content |
| --- | --- |
| `policy_admission.enabled` | Whether `policy.api` is enabled. |
| `policy_admission.clients[]` | One entry per Policy client profile: `principal`, exact `targets` (`<namespace>/<action>`), `schemas`, effective `max_concurrency` and `requests_per_second` (resolved with the same limit resolver as the Policy transport), and `diagnostics`. |
| `policy_admission.targets[]` | One entry per configured Policy target: `target`, `schema`, `mode`, and `no_match`. |
| `host_context.module_name` | On a module-bound host, always the actual configured module instance name; configuration cannot override it. |

The admission projection exposes no authentication material or Policy source. Use it only for startup cross-checks;
runtime authority still comes from the host-authenticated request views.

## Supervised work

`Host.Go(ctx, name, fn)` is the supported worker boundary. It preserves useful trace/context values without inheriting request cancellation, recovers panics, and binds the worker to host/runtime lifetime. It does not provide persistence, concurrency limits for plugin-created fan-out, retry queues, or delivery guarantees; implement those inside a bounded module design.

## API reference

- [Core `Host` and `Logger`](./api-reference/contract.md)
- [Host service facades](./api-reference/services.md)
- [Helpers](./api-reference/helpers.md)
