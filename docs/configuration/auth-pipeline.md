---
title: Authentication Pipeline
description: Authentication pipeline limits, caching, password history, and master-user login format
keywords: [Configuration, Authentication, Pipeline, Master User]
sidebar_position: 7
---

# Authentication Pipeline

`auth.pipeline` contains request concurrency, retry, cache, password-history, and master-user settings for the authentication pipeline.

```yaml
auth:
  pipeline:
    max_concurrent_requests: 100
    max_login_attempts: 15
    wait_delay: 0
    local_cache_ttl: 30s

    password_history:
      max_entries: 1000

    master_user:
      enabled: false
      user_format: "{user}*{master_user}"
```

## General Settings

| Key | Type | Default | Purpose |
|---|---:|---|---|
| `max_concurrent_requests` | integer | `100` | Maximum number of concurrent authentication requests handled by the pipeline. |
| `max_login_attempts` | integer | `15` | Maximum login attempts considered by the pipeline before the request is treated as exhausted. |
| `wait_delay` | duration/integer | `0` | Delay before selected authentication responses. |
| `local_cache_ttl` | duration | `30s` | Lifetime for local in-memory auth cache entries. |
| `password_history.max_entries` | integer | `1000` | Maximum password-history entries retained per tracked bucket. |

## Authentication Caches

The pipeline uses three caches with different authority:

| Cache | Configuration | Serves |
|---|---|---|
| Process-local authentication cache | `auth.pipeline.local_cache_ttl` | repeated requests on the same instance |
| Positive password cache (UCP) | `cache` in `auth.backends.order`, `storage.redis.positive_cache_ttl` | password authentication; LDAP and Lua backends, and native backend plugins with [`positive_password_cache`](native-go-plugins.md#positive-password-cache-for-backend-modules) |
| Identity lookup cache (UCI) | `storage.redis.identity_cache` | passwordless LDAP identity lookups; see [Identity Lookup Cache](server-configuration.md#identity-lookup-cache) |

The typed authentication providers `authn/builtin/ldap_backend` and `authn/builtin/lua_backend` keep a configured
cache-first order such as `order: [cache, ldap, ldap(list-account)]`. Their cache lookups accept only entries of their
own backend family and configured instances; foreign in-memory evidence is rejected before the request is changed.
Credentials can therefore be served from the cache while subject providers, account authorization, environment
providers, and post-actions still run on every request.

A cached result never weakens Policy: the host evidence that a cache hit provides is subject to the same
[auth FSM guard](auth-policy.md#host-evidence-guard) as a backend verification.

## Master User

`auth.pipeline.master_user.enabled` turns on master-user parsing for authentication requests.

`auth.pipeline.master_user.user_format` defines how the login name carries the requested target user and the authenticating master user. The format uses exactly one target-user placeholder and exactly one master-user placeholder.

Examples:

| Format | Login name | Parsed target user | Parsed master user |
|---|---|---|---|
| <code>&#123;user&#125;*&#123;master_user&#125;</code> | `alice@example.test*admin@example.test` | `alice@example.test` | `admin@example.test` |
| <code>&#123;user&#125;#&#123;master_user&#125;</code> | `alice@example.test#admin@example.test` | `alice@example.test` | `admin@example.test` |
| <code>&#123;master_user&#125;*&#123;user&#125;</code> | `admin@example.test*alice@example.test` | `alice@example.test` | `admin@example.test` |
| <code>login:&#123;user&#125;&#124;via:&#123;master_user&#125;</code> | `login:alice@example.test|via:admin@example.test` | `alice@example.test` | `admin@example.test` |

The literal text between the placeholders must make the split deterministic. Adjacent target-user and master-user placeholders are invalid because Nauthilus cannot know where one identity ends and the other begins.

The parsed master-user state is available to auth policies as `auth.master_user.active` for `authenticate` requests. See [Auth Policy Reference](auth-policy.md) for the corresponding policy attributes and examples.

## Credential Syntax and Empty Credentials

Since v4.0.3 an empty username or password value is an ordinary failed login, not a malformed request. HTTP JSON, CBOR,
form, header, nginx, and Basic requests and gRPC `Authenticate` answer it with `Invalid login or password` through the
built-in rules `standard_empty_username` and `standard_empty_password`. Such a request runs no backend and does not
update brute-force buckets. A missing credential key and JSON or CBOR `null` still return `400 Bad Request`; for HTTP
header transports an absent header is a missing key and a present empty header is an empty value. `lookup_identity`
answers an empty username with a temporary failure through `standard_lookup_identity_empty_username`.

Since v4.0.6 a username is rejected only for invalid UTF-8 and control characters. Spaces and IMAP atom specials such
as `(`, `)`, `{`, `%`, `"`, and `\` reach the backends, which decide whether the account exists; percent-decoded nginx
headers such as `Vorname%20Nachname` are accepted. An unsafe `authenticate` username is answered like an empty one with
`Invalid login or password`. `lookup_identity` over gRPC keeps `InvalidArgument`. LDAP filters expand the legacy `%s`
placeholder and `%{...}` macros in one pass, so a username that contains macro syntax stays literal.

## Response Texts

`auth.response` overrides the generic client status texts (since v4.0.3):

```yaml
auth:
  response:
    failure_message: "Invalid login or password"
    tempfail_message: "Temporary server problem, try again later"
```

| Key | Type | Default | Purpose |
|---|---:|---|---|
| `failure_message` | string | built-in text | Text of an ordinary failed login. |
| `tempfail_message` | string | built-in text | Text of a temporary failure. |

The texts apply to HTTP `Auth-Status` headers, plain-text bodies, and gRPC authority responses. An empty value keeps
the built-in text. Control characters and texts longer than 256 characters are rejected at load time. A configured text
is also its i18n key, so a Policy localization catalog may translate it. Specific reasons such as missing TLS,
Policy-selected response messages, internal diagnostics, and the IdP login form keep their own texts. The gRPC
authority binds the texts at startup; a change needs a restart there.

`status_message` in the summary log lines, Lua `request.status_message`, and native post-action snapshots report the
text the client receives, including these overrides (since v4.0.6).

## Backend Failures and Temporary Failures

Nauthilus distinguishes a backend that decided against the credentials from a backend that could not decide. Only a
decision is counted by brute-force protection; a technical fault is answered with a temporary failure and never counted
as a wrong password.

| Backend result | Pipeline outcome |
|---|---|
| Authenticated | Success. |
| User found, wrong password (for LDAP only a bind rejected with `invalidCredentials`) | Authentication failure, counted by brute-force protection. |
| Backend declines the request, for example because it does not serve the protocol | The next backend in `auth.backends.order` decides. |
| Technical fault: LDAP connect, bind, search, or modify timeouts and transport errors, exhausted LDAP pool, a dropped LDAP queue request, a Lua backend script failure, a remote authority that is unavailable, a canceled or expired request context | Temporary failure, not counted. |
| Error that no backend classified | Temporary failure, not counted, and logged as unclassified. |

Once any backend in the chain failed technically, a result that neither authenticates nor finds the user is not
treated as an answer. With a cache-first chain, a cache miss is therefore reported as a temporary failure instead of a
wrong password while the authoritative backend is unreachable. A late context error does not overwrite a definitive
bind verdict.

Several pools of the same backend type are tracked individually. One LDAP pool that declines a request no longer
makes a chain of two LDAP pools report that all backends failed, and error logs name the failing pool.

For the remote backend of a split edge, an unavailable authority, a deadline, `RESOURCE_EXHAUSTED`, and unexpected
gRPC statuses are technical faults. `UNAUTHENTICATED` and `PERMISSION_DENIED` from the authority make the remote backend
decline, so the remaining backends decide. `FAILED_PRECONDITION`, `INVALID_ARGUMENT`, and `ALREADY_EXISTS` mean the
authority refused the request itself; they are answered as temporary failures and make no statement about the
credentials. See [Remote backend](database-backends/remote.md).

Requests that cannot be admitted or that end with an unexpected application error are also temporary failures and
never authenticate the request: an exhausted [`policy.runtime.authn`](auth-policy.md#internal-authentication-admission)
bound, a saturated post-action supervisor, a failing `host_sync` provider, or an unavailable Decision Service
generation. See [Unexpected application errors](auth-policy.md#unexpected-application-errors).

When the repeating-wrong-password check cannot reach Redis after a failed password, Nauthilus also answers with a
temporary failure and does not count the request. See
[Unavailable Brute-Force State](brute-force.md#unavailable-brute-force-state).
