---
title: HTTP Hooks
description: Complete hook descriptor, authentication, request, response, routing, and production behavior reference
keywords: [Hook, HookDescriptor, HookAuth, HookScope, RequiredScopes, HookRequest, HookResponse]
sidebar_position: 8
---

# HTTP Hooks

Native hooks expose trusted plugin code through the Nauthilus custom HTTP surface. Registration validates each descriptor; authorization, body limits, request construction, timeout, panic/error handling, and response filtering occur before/after `Hook.Serve`.

## `HookScope`

```go
type HookScope string
```

| Constant | Value | Token scope mapping |
| --- | --- | --- |
| `HookScopePublic` | `"public"` | No bearer scope required. |
| `HookScopeInternal` | `"internal"` | Nauthilus `authenticate` scope. |
| `HookScopeAdmin` | `"admin"` | Nauthilus `admin` scope. |

Scope is evaluated together with `HookAuth` when the operator has not configured
an exact `required_scopes` override. It is not sufficient on its own.

## `HookAuth`

```go
type HookAuth string
```

| Constant | Value | Meaning |
| --- | --- | --- |
| `HookAuthNone` | `"none"` | No hook-specific authentication. Allowed only with public scope. |
| `HookAuthToken` | `"token"` | Valid bearer token plus the scope mapped from `HookScope`, unless exact operator scopes replace that mapping. |
| `HookAuthSession` | `"session"` | Current production adapter requires the validated Basic/session marker. It does not evaluate `HookScope`. |
| `HookAuthAdmin` | `"admin"` | Always requires an administrative bearer token, regardless of scope. |

### Coarse authorization matrix

This matrix applies when the effective descriptor has no `RequiredScopes`:

| `Auth` | `public` scope | `internal` scope | `admin` scope |
| --- | --- | --- | --- |
| `none` | Allowed anonymously | Rejected with 403 before plugin call | Rejected with 403 before plugin call |
| `token` | Bearer token, no required scope | Bearer token with `authenticate` scope | Bearer token with `admin` scope |
| `admin` | Admin bearer required | Admin bearer required | Admin bearer required |
| `session` | Validated Basic/session marker | Same marker; scope ignored | Same marker; **not** an admin check |

Do not use `HookAuthSession` with `HookScopeAdmin` to protect administrative operations in the current implementation. Use `HookAuthAdmin`.

### Exact operator-owned scopes

An operator can replace the coarse scope mapping for one registered local hook:

```yaml
plugins:
  modules:
    - name: customer_status
      path: /usr/local/lib/nauthilus/plugins/customer_status.so
      hooks:
        - name: health
          required_scopes:
            - nauthilus:admin
            - nauthilus:custom:health
```

The list has **any-of** semantics: a valid bearer token containing either scope
is accepted. Exact scopes take precedence over the descriptor's coarse
`Scope`/`Auth` mapping at request time. Authorization still happens before body
reading, request construction, and plugin invocation.

This override is deliberately host-owned:

- plugin code must leave `HookDescriptor.RequiredScopes` empty;
- `name` is the registered local component name, not the qualified
  `<module>.<name>` value;
- a non-empty list requires `HookAuthToken` and a non-public hook;
- values are trimmed, validated as RFC 6749 scope tokens, de-duplicated in
  declaration order, and limited to 32 entries;
- invalid or duplicate configuration entries, unmatched hook names, and
  conflicting descriptors fail module registration;
- omitted and empty lists preserve the coarse descriptor behavior; and
- changing hook authorization configuration requires a process restart.

## `HookDescriptor`

```go
type HookDescriptor struct {
    RequiredScopes []string
    Timeout        time.Duration
    Name           string
    Method         string
    Path           string
    Alias          string
    Scope          HookScope
    Auth           HookAuth
    MaxBodyBytes   int64
}
```

| Field | Validation, default, and current behavior |
| --- | --- |
| `RequiredScopes` | Host-injected copy of `plugins.modules[].hooks[].required_scopes`. Plugin descriptors must leave it empty. A non-empty effective list requires any one listed bearer scope and replaces coarse scope/auth evaluation. |
| `Timeout` | Must be non-negative. Zero adds no hook-specific deadline; the inbound request context still applies. Positive values bound `Serve`. |
| `Name` | Required valid component name, qualified as `<module>.<name>`. |
| `Method` | Required non-blank text. Routing normalizes it with trim + uppercase. Registration does not otherwise enforce an HTTP-token grammar. |
| `Path` | Required absolute path beginning with `/`. At runtime it is trim-normalized to one leading slash. The canonical HTTP route is under `/api/v1/custom`, so descriptor `/risk` is served at `/api/v1/custom/risk`. |
| `Alias` | Optional absolute path beginning with `/`. It is a direct absolute route alias, not automatically under `/api/v1/custom`. |
| `Scope` | Required one of the three declared scope constants; no zero default. |
| `Auth` | Required one of the four declared auth constants; no zero default. |
| `MaxBodyBytes` | Must be non-negative. Zero uses the current global request-body default of 1 MiB; positive is the exact bound. |

Canonical routes are keyed by normalized path plus normalized method. Aliases are
method-specific and are dispatched only after the normal router found no
concrete route; an existing application route therefore wins over an alias.
`GET` does not implicitly register `HEAD`: register a separate `HEAD` descriptor
when that method must be served.

If two hooks collide, the current runtime makes **both** canonical bindings
unroutable rather than failing startup. Duplicate aliases make that alias
unroutable; their canonical hooks remain routable unless the canonical keys also
collide. An alias targeting an ambiguous canonical hook is also removed. Avoid
duplicates proactively; registration itself does not provide a global
route-collision error.

## `HookRequest`

```go
type HookRequest struct {
    Snapshot RequestSnapshot
    Headers  map[string][]string
    Query    map[string][]string
    Body     []byte
    Path     string
    Method   string
}
```

| Field | Current production population |
| --- | --- |
| `Snapshot` | Hook-specific snapshot described below. |
| `Headers` | Copied, redacted HTTP headers. Authorization, proxy authorization, cookie, and configured password-bearing headers are removed. |
| `Query` | Copied parsed query values. Attacker-controlled and potentially sensitive. |
| `Body` | Complete copied body after authorization and `MaxBodyBytes` enforcement; an oversized request gets 413 without constructing the request or invoking the plugin. Known `Content-Length` is rejected early, while streamed/chunked bodies are bounded while reading. |
| `Path` | Actual inbound URL path, including canonical `/api/v1/custom/...` or the alias path. It is not merely `HookDescriptor.Path`. |
| `Method` | Actual inbound HTTP method. |

The production custom-hook builder currently populates only these `RequestSnapshot` values:

- `Session` from the host request GUID;
- `Service = "custom_hook"` and `Protocol = "http"`;
- `Method`, `Headers`, and `UserAgent` from HTTP;
- `Username` from authenticated bearer `sub`;
- `ClientIP`, `ClientPort`, and `ClientHost` from the request;
- `OIDCCID` from the first non-empty bearer claim `client_id`, `azp`, then `sub`;
- `Runtime.Authenticated` when bearer claims exist or the Basic/session marker is validated.

The builder currently leaves `ExternalSessionID`, account/identity fields, `ClientID`, `ClientNet`, local endpoint fields, SAML and login-attempt data, TLS, health-check, diagnostics, IdP scope/group/client metadata, MFA data, `Authorized`, debug/repeating/RWP flags, and stage flags at zero values. These fields remain public surface and generic hook request builders can populate them, but current HTTP routing does not.

Maps/slices are copies. Treat them as immutable; mutation does not change the host request.

## `HookResponse`

```go
type HookResponse struct {
    Headers    map[string][]string
    Body       []byte
    StatusCode int
}
```

| Field | Validation and effect |
| --- | --- |
| `Headers` | Every name/value is validated. CR/LF and invalid fields are rejected. Hop-by-hop, auth/cookie, configured secret, CORS, security-policy, content-length, server/date, and other host-owned headers are denied. One invalid/forbidden header rejects the **entire** response and returns host 502; it is not silently dropped. |
| `Body` | Written verbatim after headers/status. Suppressed for `HEAD` and when empty. No response-size limit is imposed by this hook adapter, so bound it in plugin code. |
| `StatusCode` | Zero defaults to 200. Values 100 through 599 are accepted; anything else rejects the response and produces 502. Use `net/http` constants. |

Important distinction: `HookResponse.Headers` fail closed on any unsafe header. [`ResponseMutation`](./results.md#responsemutation) used by subject/obligation paths instead silently skips unsafe headers.

The host owns headers including `Auth-Status`, `Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, connection controls, CORS, CSP/HSTS/frame/content security headers, `Content-Length`, `Date`, and `Server`. Do not use hooks as an alternate channel for credentials or host authorization state.

## `Hook`

```go
type Hook interface {
    Descriptor() HookDescriptor
    Serve(context.Context, HookRequest) (HookResponse, error)
}
```

`Descriptor` is read and validated during registration. `Serve` runs only after routing, authorization, and body validation. It receives the inbound context plus the optional descriptor deadline. Honor cancellation and do not retain request data.

Returned errors and recovered panics currently yield HTTP 500. The runtime panic
boundary converts the panic to a bounded `ErrPluginPanic` error and does not
return the recovered value to the caller. A `context.DeadlineExceeded` result
yields 504; `context.Canceled` currently falls back to 500. Error details are
not returned to the HTTP caller. A rejected or malformed `HookResponse` yields
502 instead.
