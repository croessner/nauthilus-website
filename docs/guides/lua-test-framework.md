---
title: "Lua Test Framework"
description: "Complete reference for --test-lua: callbacks, JSON fixture schema, per-module settings, expected_calls, and working examples"
keywords:
  - Lua
  - Testing
  - Mocking
  - JSON fixtures
  - CI
  - Reference
sidebar_position: 3
---

# Lua Test Framework

This page is the complete reference for Nauthilus Lua test mode.

Goal: after reading this page, you can create deterministic Lua tests for all supported callback types and module mocks.

## What test mode does

`--test-lua` executes one Lua script in an isolated test runtime.

It preloads:
- all Nauthilus mock modules (`nauthilus_*`)
- built-in helper table (`nauthilus_builtin`)
- `gopher-lua-libs`
- `glua_crypto`
- `glua_http`
- real `nauthilus_redis` backed by in-memory `miniredis`
- an in-memory `db` mock (`require("db")`)

Important:
- There is no standalone logging module in test mode.
- For logs and status messages, use builtin functions:
  - `nauthilus_builtin.custom_log_add(key, value)`
  - `nauthilus_builtin.status_message_set(message)`

It can validate:
- callback result (`expected_output`)
- strict call sequence (`expected_calls`) per module

## CLI reference

```bash
go run ./server --test-lua <script.lua> --test-callback <type> [--test-mock <fixture.json>]
```

Flags:
- `--test-lua`: path to Lua script
- `--test-callback`: one of `subject|environment|action|backend|hook|cache_flush`
- `--test-mock`: optional JSON fixture file

Exit codes:
- `0`: test passed
- non-zero: callback/runtime/assertion failure

## Callback contract

Required global Lua functions by callback type:
- `subject`: `nauthilus_call_subject(request)` -> `action, result`
- `environment`: `nauthilus_call_environment(request)` -> `triggered, abort, result`
- `action`: `nauthilus_call_action(request)` -> boolean, integer, or `nil`
- `backend`: `nauthilus_backend_verify_password(request)` -> `result, table|userdata`
- `hook`: `nauthilus_run_hook()` -> any (test runtime stores boolean-like result as action result)
- `cache_flush`: `nauthilus_cache_flush(request)` -> table, string|nil

Subject source return semantics:
- `action`: boolean (`nauthilus_builtin.SUBJECT_ACCEPT` or `nauthilus_builtin.SUBJECT_REJECT`)
- `result`: integer (`nauthilus_builtin.SUBJECT_RESULT_OK` or `nauthilus_builtin.SUBJECT_RESULT_FAIL`)

Environment source return semantics:
- `triggered`: boolean (`nauthilus_builtin.ENVIRONMENT_TRIGGER_NO` or `nauthilus_builtin.ENVIRONMENT_TRIGGER_YES`)
- `abort`: boolean (`nauthilus_builtin.ENVIRONMENT_ABORT_NO` or `nauthilus_builtin.ENVIRONMENT_ABORT_YES`)
- `result`: integer (`nauthilus_builtin.ENVIRONMENT_RESULT_OK` or `nauthilus_builtin.ENVIRONMENT_RESULT_FAIL`)

Action return semantics:
- boolean: used directly
- integer: `0` means success, any other value means failure
- `nil`: treated as success

Backend return semantics:
- `result`: integer (`nauthilus_builtin.BACKEND_RESULT_OK` or `nauthilus_builtin.BACKEND_RESULT_FAIL`)
- `backend_result`: table or userdata payload returned from `nauthilus_backend_result.new()`

## Request object (`request`) in test runtime

If `context` exists in fixture, fields are mapped into `request`:
- `username`, `password`
- `client_ip`, `client_port`, `client_host`, `client_id`
- `local_ip`, `local_port`
- `service`, `protocol`, `user_agent`, `session`
- `debug`, `no_auth`, `authenticated`, `user_found`
- `account`, `unique_user_id`, `display_name`, `status_message`
- `brute_force_count`

Additional derived fields:
- `log_level` (`debug` when `context.debug=true`, else `info`)
- `log_format` (`json`)
- `logging` table with `log_level`, `log_format`

## Fixture schema (top-level)

```json
{
  "context": { },
  "redis": { },
  "ldap": { },
  "backend": { },
  "misc": { },
  "password": { },
  "soft_whitelist": { },
  "mail": { },
  "dns": { },
  "opentelemetry": { },
  "brute_force": { },
  "psnet": { },
  "prometheus": { },
  "util": { },
  "cache": { },
  "db": { },
  "backend_result": { },
  "http_request": { },
  "http_response": { },
  "http_client": { },
  "expected_output": { }
}
```

All blocks are optional.

## `expected_calls` reference (common)

Most module blocks support:

```json
"expected_calls": [
  { "method": "<name>", "arg_contains": "<substring>" }
]
```

Rules:
- call order is strict
- method names are compared case-insensitively
- `arg_contains` is optional and matched case-insensitively
- missing calls fail
- extra calls fail

Scope:
- `expected_calls` only works for functions that the Lua test runner instruments explicitly.
- In practice, that means the mocked or wrapped module APIs documented on this page, for example `nauthilus_context`, `nauthilus_redis`, `nauthilus_backend`, `nauthilus_policy`, `nauthilus_http_request`, `nauthilus_http_response`, `nauthilus_util`, `nauthilus_cache`, the dedicated `db` mock, and the wrapped HTTP client module.
- Arbitrary self-written Lua helper functions are not tracked.
- Standard library calls such as `string.*`, `table.*`, `math.*`, or generic `require(...)` modules are not tracked unless the test runner exposes a dedicated mock or wrapper for that module.
- Use the per-module "Supported `expected_calls.method` values" lists below as the authoritative source. If a function is not listed there, it is not observable via `expected_calls`.

DB uses a dedicated expected-call structure (see DB section).

## Complete module reference

### `context`

Fields:
- `username` string
- `password` string
- `client_ip` string
- `client_port` string
- `client_host` string
- `client_id` string
- `local_ip` string
- `local_port` string
- `service` string
- `protocol` string
- `user_agent` string
- `session` string
- `debug` bool
- `no_auth` bool
- `authenticated` bool
- `user_found` bool
- `account` string
- `unique_user_id` string
- `display_name` string
- `status_message` string
- `attributes` object (`map[string]string`)
- `brute_force_count` integer
- `expected_calls` common format

Supported `expected_calls.method` values:
- `context_set`
- `context_get`
- `context_delete`

Lua example:

```lua
local ctx = require("nauthilus_context")
ctx.context_set("trace_id", "abc")
local v = ctx.context_get("trace_id")
```

JSON example:

```json
{
  "context": {
    "username": "alice",
    "client_ip": "192.0.2.10",
    "expected_calls": [
      {"method": "context_set", "arg_contains": "trace_id"},
      {"method": "context_get", "arg_contains": "trace_id"}
    ]
  }
}
```

### `redis`

Fields:
- `initial_data` object:
  - `strings` object (`map[string]string`)
  - `hashes` object (`map[string]map[string]string`)
  - `sets` object (`map[string][]string`)
  - `lists` object (`map[string][]string`)
  - `zsets` object (`map[string][]object`) with entries:
    - `member` string
    - `score` number
  - `hyperloglogs` object (`map[string][]string`)
  - `ttl_seconds` object (`map[string]int64`) applied via `EXPIRE`
- `expected_calls` common format

Supported `expected_calls.method` values:
- `register_redis_pool`, `get_redis_connection`
- `redis_ping`, `redis_get`, `redis_set`, `redis_incr`, `redis_del`, `redis_rename`, `redis_expire`, `redis_exists`
- `redis_encrypt`, `redis_decrypt`, `redis_is_encryption_enabled`
- `redis_run_script`, `redis_upload_script`, `redis_pipeline`
- `redis_mget`, `redis_mset`, `redis_keys`, `redis_scan`
- `redis_hget`, `redis_hset`, `redis_hdel`, `redis_hlen`, `redis_hgetall`, `redis_hmget`, `redis_hincrby`, `redis_hincrbyfloat`, `redis_hexists`
- `redis_zadd`, `redis_zrem`, `redis_zrank`, `redis_zrange`, `redis_zrevrange`, `redis_zrangebyscore`, `redis_zremrangebyscore`, `redis_zremrangebyrank`, `redis_zcount`, `redis_zscore`, `redis_zrevrank`, `redis_zincrby`
- `redis_lpush`, `redis_rpush`, `redis_lpop`, `redis_rpop`, `redis_lrange`, `redis_llen`
- `redis_pfadd`, `redis_pfcount`, `redis_pfmerge`
- `redis_sadd`, `redis_sismember`, `redis_smembers`, `redis_srem`, `redis_scard`

Lua example:

```lua
local r = require("nauthilus_redis")
local ok, set_err = r.redis_set("default", "counter", "1", 0)
if set_err then error(set_err) end
local v, get_err = r.redis_get("default", "counter")
if get_err then error(get_err) end
```

JSON example:

```json
{
  "redis": {
    "initial_data": {
      "strings": {
        "counter": "1",
        "tenant:alice": "acme"
      },
      "hashes": {
        "profile:alice": {
          "mail": "alice@example.com"
        }
      },
      "sets": {
        "roles:alice": ["admin", "imap"]
      },
      "lists": {
        "mailbox:recent:alice": ["msg1", "msg2"]
      },
      "zsets": {
        "scoreboard": [
          {"member": "alice", "score": 10},
          {"member": "bob", "score": 20}
        ]
      },
      "hyperloglogs": {
        "unique_users": ["alice", "bob", "alice"]
      },
      "ttl_seconds": {
        "counter": 300
      }
    },
    "expected_calls": [
      {"method": "redis_set", "arg_contains": "counter"},
      {"method": "redis_get", "arg_contains": "counter"}
    ]
  }
}
```

### `ldap`

Fields:
- `search_result` object (`map[string][]string`)
- `search_error` string
- `modify_ok` bool
- `modify_error` string
- `endpoint_host` string
- `endpoint_port` integer
- `endpoint_error` string
- `expected_calls` common format

Supported `expected_calls.method` values:
- `ldap_search`
- `ldap_modify`
- `ldap_endpoint`

Lua example:

```lua
local ldap = require("nauthilus_ldap")
local attrs, err = ldap.ldap_search("dc=example,dc=com", "(uid=alice)", {"mail"})
```

JSON example:

```json
{
  "ldap": {
    "search_result": {
      "mail": ["alice@example.com"]
    },
    "endpoint_host": "ldap.internal",
    "endpoint_port": 389,
    "expected_calls": [
      {"method": "ldap_endpoint"},
      {"method": "ldap_search"}
    ]
  }
}
```

### `backend`

Fields:
- `backend_servers` array of objects:
  - `protocol` string
  - `host` string
  - `port` integer
  - `request_uri` string
  - `test_username` string
  - `test_password` string
  - `haproxy_v2` bool
  - `tls` bool
  - `tls_skip_verify` bool
  - `deep_check` bool
- `expected_calls` common format

Supported `expected_calls.method` values:
- `get_backend_servers`
- `select_backend_server`
- `apply_backend_result`
- `remove_from_backend_result`

Lua example:

```lua
local backend = require("nauthilus_backend")
local servers = backend.get_backend_servers()
backend.select_backend_server(servers[1].host, servers[1].port)
```

JSON example:

```json
{
  "backend": {
    "backend_servers": [
      {"protocol": "imap", "host": "10.0.0.20", "port": 993, "tls": true}
    ],
    "expected_calls": [
      {"method": "get_backend_servers"},
      {"method": "select_backend_server", "arg_contains": "10.0.0.20"}
    ]
  },
  "expected_output": {
    "used_backend_address": "10.0.0.20",
    "used_backend_port": 993,
    "error_expected": false
  }
}
```

### `backend_result`

Fields:
- `authenticated` bool
- `user_found` bool
- `account_field` string
- `totp_secret` string
- `totp_recovery` array of strings
- `unique_user_id` string
- `display_name` string
- `attributes` object (`map[string]string`)
- `expected_calls` common format

Supported `expected_calls.method` values:
- `new`
- `authenticated`
- `user_found`
- `account_field`
- `totp_secret_field`
- `totp_recovery_field`
- `unique_user_id_field`
- `display_name_field`
- `webauthn_credentials`
- `attributes`

Lua example:

```lua
local br = require("nauthilus_backend_result")
local r = br.new()
r.authenticated(true)
r.user_found(true)
r.account_field("alice")
return r
```

JSON example:

```json
{
  "backend_result": {
    "authenticated": true,
    "user_found": true,
    "account_field": "alice",
    "expected_calls": [
      {"method": "new"},
      {"method": "authenticated"},
      {"method": "user_found"},
      {"method": "account_field"}
    ]
  }
}
```

### `db`

Fields:
- `open_error` string
- `exec_error` string
- `query_error` string
- `declarative_mode` bool
- `expected_calls` array of DB call objects:
  - `method` string (`open|stmt|exec|query|close`)
  - `query_contains` string (optional)
  - `rows_affected` int64 (optional, for `exec`)
  - `last_insert_id` int64 (optional, for `exec`)
  - `columns` array of strings (optional, for `query`)
  - `rows` array of row arrays (optional, for `query`)

Behavior notes:
- `require("db")` always uses this in-memory mock in test mode.
- `declarative_mode=true` keeps behavior fixture-driven without relying on internal expectation plumbing.
- if `columns` omitted but `rows` present, fallback names are generated (`col_1`, `col_2`, ...).

Lua example:

```lua
local db = require("db")
local conn, err = db.open("mysql", "mock://")
if err then return nil end
conn:exec("insert into users(name) values (?)", "alice")
local res = conn:query("select id, name from users")
conn:close()
return res
```

JSON example:

```json
{
  "db": {
    "declarative_mode": true,
    "expected_calls": [
      {"method": "open"},
      {"method": "exec", "query_contains": "insert into", "rows_affected": 1, "last_insert_id": 7},
      {"method": "query", "query_contains": "select", "columns": ["id", "name"], "rows": [[7, "alice"]]},
      {"method": "close"}
    ]
  }
}
```

### `http_request`

Fields:
- `method` string
- `path` string
- `headers` object (`map[string]string`)
- `body` string
- `expected_calls` common format

Supported `expected_calls.method` values:
- `get_http_method`
- `get_http_path`
- `get_http_body`
- `get_http_header`
- `get_http_request_header`

Lua example:

```lua
local req = require("nauthilus_http_request")
local method = req.get_http_method()
local auth = req.get_http_header("Authorization")
```

JSON example:

```json
{
  "http_request": {
    "method": "GET",
    "path": "/health",
    "headers": {"Authorization": "Bearer token"},
    "expected_calls": [
      {"method": "get_http_method"},
      {"method": "get_http_header", "arg_contains": "Authorization"}
    ]
  }
}
```

### `http_response`

Fields:
- `status_code` integer (reserved for fixtures; current mock functions do not consume this field directly)
- `headers` object (`map[string]string`) (reserved)
- `body` string (reserved)
- `expected_calls` common format

Supported `expected_calls.method` values:
- `html`
- `set_http_response_header`
- `json`

Lua example:

```lua
local resp = require("nauthilus_http_response")
resp.set_http_response_header("X-Test", "1")
resp.json(resp.STATUS_OK, {ok=true})
```

JSON example:

```json
{
  "http_response": {
    "expected_calls": [
      {"method": "set_http_response_header", "arg_contains": "X-Test"},
      {"method": "json", "arg_contains": "200"}
    ]
  }
}
```

### `http_client` (glua_http)

Fields:
- `responses` array of objects:
  - `status_code` integer (optional, defaults to `200`)
  - `headers` object (`map[string]string`) (optional)
  - `body` string (optional)
  - `error` string (optional, returns `nil, error` to Lua)
- `expected_calls` common format

Supported `expected_calls.method` values:
- `get`
- `post`
- any lowercase HTTP verb emitted through `http.request(...)` (for example `put`, `delete`)

Behavior notes:
- Each `glua_http` call consumes one response from `responses` in order.
- If `responses` is exhausted, the mock returns a default success response (`200` + empty body).
- `arg_contains` matching is performed against `url=<url> body=<body>`.

Lua example:

```lua
local http = require("glua_http")

local res, err = http.post("http://clickhouse.local:8123", {
  body = "SELECT 1",
  headers = { ["Content-Type"] = "text/plain" }
})
if err ~= nil then error(err) end
```

JSON example:

```json
{
  "http_client": {
    "responses": [
      {
        "status_code": 200,
        "headers": {"X-Test": "ok"},
        "body": "{\"rows\":0}"
      }
    ],
    "expected_calls": [
      {"method": "post", "arg_contains": "clickhouse.local"},
      {"method": "post", "arg_contains": "SELECT 1"}
    ]
  }
}
```

### `dns`

Fields:
- `lookup_result` object (`map[string]any`)
- `expected_calls` common format

Supported `expected_calls.method` values:
- `lookup`

Lua example:

```lua
local dns = require("nauthilus_dns")
local a = dns.lookup("example.com")
```

JSON example:

```json
{
  "dns": {
    "lookup_result": {
      "example.com": ["93.184.216.34"]
    },
    "expected_calls": [
      {"method": "lookup", "arg_contains": "example.com"}
    ]
  }
}
```

### `opentelemetry`

Fields:
- `expected_calls` common format

Supported `expected_calls.method` values:
- `tracer`
- `default_tracer`
- `start_span`
- `set_attributes`
- `record_error`
- `set_status`
- `finish`

Lua example:

```lua
local otel = require("nauthilus_opentelemetry")
local t = otel.default_tracer()
local span = t.start_span("lua_test")
span.set_attributes({k="v"})
span.finish()
```

JSON example:

```json
{
  "opentelemetry": {
    "expected_calls": [
      {"method": "default_tracer"},
      {"method": "start_span"},
      {"method": "set_attributes"},
      {"method": "finish"}
    ]
  }
}
```

### `brute_force`

Fields:
- `is_blocked` bool
- `increment_by` integer
- `expected_calls` common format

Supported `expected_calls.method` values:
- `is_blocked`
- `increment`

Lua example:

```lua
local bf = require("nauthilus_brute_force")
if not bf.is_blocked() then
  bf.increment()
end
```

JSON example:

```json
{
  "brute_force": {
    "is_blocked": false,
    "increment_by": 3,
    "expected_calls": [
      {"method": "is_blocked"},
      {"method": "increment"}
    ]
  }
}
```

### `psnet`

Fields:
- `stats` object (`map[string]any`)
- `expected_calls` common format

Supported `expected_calls.method` values:
- `get_stats`

Lua example:

```lua
local psnet = require("nauthilus_psnet")
local s = psnet.get_stats("imap://10.0.0.20:993")
```

JSON example:

```json
{
  "psnet": {
    "stats": {"connections": 5, "latency_ms": 12},
    "expected_calls": [
      {"method": "get_stats", "arg_contains": "imap://"}
    ]
  }
}
```

### `prometheus`

Fields:
- `expected_calls` common format

Supported `expected_calls.method` values:
- `create_summary_vec`
- `create_counter_vec`
- `create_histogram_vec`
- `create_gauge_vec`
- `increment_counter`
- `increment_gauge`
- `decrement_gauge`
- `start_histogram_timer`
- `start_summary_timer`
- `stop_timer`

Lua example:

```lua
local p = require("nauthilus_prometheus")
local t = p.start_histogram_timer("auth_duration", {"imap"})
p.stop_timer(t)
```

JSON example:

```json
{
  "prometheus": {
    "expected_calls": [
      {"method": "start_histogram_timer"},
      {"method": "stop_timer"}
    ]
  }
}
```

### `misc`

Fields:
- `expected_calls` common format

Supported `expected_calls.method` values:
- `get_country_name`
- `wait_random`
- `scoped_ip`

Lua example:

```lua
local misc = require("nauthilus_misc")
local country, err = misc.get_country_name("DE")
```

JSON example:

```json
{
  "misc": {
    "expected_calls": [
      {"method": "get_country_name", "arg_contains": "DE"}
    ]
  }
}
```

### `password`

Fields:
- `compare_result` bool
- `policy_result` bool
- `generated_hash` string
- `expected_calls` common format

Supported `expected_calls.method` values:
- `compare_passwords`
- `check_password_policy`
- `generate_password_hash`

Lua example:

```lua
local pw = require("nauthilus_password")
local ok = pw.compare_passwords("hash", "secret")
```

JSON example:

```json
{
  "password": {
    "compare_result": true,
    "generated_hash": "mock$argon2$...",
    "expected_calls": [
      {"method": "compare_passwords"}
    ]
  }
}
```

### `soft_whitelist`

Fields:
- `entries` object (`map[string][]string`), key format in mock: `<environment>:<username>`
- `expected_calls` common format

Supported `expected_calls.method` values:
- `soft_whitelist_set`
- `soft_whitelist_get`
- `soft_whitelist_delete`

Lua example:

```lua
local sw = require("nauthilus_soft_whitelist")
sw.soft_whitelist_set("alice", "192.0.2.0/24", "geo")
local list = sw.soft_whitelist_get("alice", "geo")
```

JSON example:

```json
{
  "soft_whitelist": {
    "entries": {
      "geo:alice": ["192.0.2.0/24"]
    },
    "expected_calls": [
      {"method": "soft_whitelist_get", "arg_contains": "alice:geo"}
    ]
  }
}
```

### `mail`

Fields:
- `send_error` string
- `expected_calls` common format

Supported `expected_calls.method` values:
- `send_mail`

Lua example:

```lua
local mail = require("nauthilus_mail")
mail.send_mail({server="smtp.internal", from="a@x", to="b@y", subject="Test", body="ok"})
```

JSON example:

```json
{
  "mail": {
    "expected_calls": [
      {"method": "send_mail", "arg_contains": "smtp.internal"}
    ]
  }
}
```

### `util`

Fields:
- `envs` object (`map[string]string`)
- `expected_calls` common format

Supported `expected_calls.method` values:
- `getenv`
- `log`
- `get_redis_key`
- `if_error_raise`
- `print_result`
- `is_table`
- `table_length`
- `is_string`

Behavior notes:
- `get_redis_key(request, key)` returns `request.redis_prefix .. key` when `request.redis_prefix` is present; otherwise it returns `key`.
- `if_error_raise(err)` raises a Lua error when `err` is non-nil.

Lua example:

```lua
local u = require("nauthilus_util")

local mode = u.getenv("MODE", "dev")
u.log("clickhouse", "debug", "mode=" .. mode)

local req = { redis_prefix = "nauthilus:" }
local dedupKey = u.get_redis_key(req, "clickhouse:authdedup:alice:203.0.113.10")

local info = { key = dedupKey, mode = mode }
if u.is_table(info) then
  local count = u.table_length(info)
  if u.is_string(dedupKey) and count > 0 then
    u.print_result("util-demo", mode, dedupKey)
  end
end

u.if_error_raise(nil)
```

JSON example:

```json
{
  "util": {
    "envs": {"MODE": "prod"},
    "expected_calls": [
      {"method": "getenv", "arg_contains": "MODE"},
      {"method": "log", "arg_contains": "debug"},
      {"method": "get_redis_key", "arg_contains": "clickhouse:authdedup"},
      {"method": "is_table"},
      {"method": "table_length"},
      {"method": "is_string"},
      {"method": "print_result"},
      {"method": "if_error_raise", "arg_contains": "nil"}
    ]
  }
}
```

### `cache`

Fields:
- `entries` object (`map[string]any`)
- `expected_calls` common format

Supported `expected_calls.method` values:
- `cache_set`
- `cache_get`
- `cache_delete`
- `cache_exists`
- `cache_update`
- `cache_keys`
- `cache_size`
- `cache_flush`
- `cache_push`
- `cache_pop_all`

Lua example:

```lua
local c = require("nauthilus_cache")
c.cache_set("tenant:alice", "acme")
local v = c.cache_get("tenant:alice")
```

JSON example:

```json
{
  "cache": {
    "entries": {"tenant:alice": "acme"},
    "expected_calls": [
      {"method": "cache_get", "arg_contains": "tenant:alice"}
    ]
  }
}
```

### `policy`

The test runtime provides a fixture-aware mock for `require("nauthilus_policy")`.

Fields:
- `expected_calls` common format

Supported `expected_calls.method` values:
- `emit_attribute`

The policy mock records calls to `emit_attribute(...)`. It does not build or validate a real `auth.policy` snapshot. Use production/config tests for registry ownership, stage, operation, and type validation. In Lua test fixtures, use `expected_calls` to assert that a script emits the expected policy fact.

The `arg_contains` value is matched against a stable string built from the emitted table:

- `id=<attribute-id>`
- `value=<value>`
- `details.<name>=<value>` for each detail, sorted by detail name

Lua example:

```lua
local policy = require("nauthilus_policy")

policy.emit_attribute({
  id = "lua.plugin.geoip.rejected",
  value = true,
  details = {
    status_message = "Policy violation",
  },
})
```

JSON example:

```json
{
  "policy": {
    "expected_calls": [
      {
        "method": "emit_attribute",
        "arg_contains": "id=lua.plugin.geoip.rejected value=true details.status_message=Policy violation"
      }
    ]
  }
}
```

## Builtin table (`nauthilus_builtin`)

The test runtime provides the global builtin table used in production scripts.

Commonly used functions:
- `nauthilus_builtin.custom_log_add(key, value)`: appends structured test log output
- `nauthilus_builtin.status_message_set(message)`: records a status message in test output

Assertions:
- `custom_log_add(...)` -> `expected_output.logs_contain` / `logs_not_contain`
- `status_message_set(...)` -> `expected_output.status_message_contain` / `status_message_not_contain`

## `expected_output` reference

Fields:
- `subject_result` int
- `subject_rejected` bool
- `environment_triggered` bool
- `environment_abort` bool
- `environment_result` int
- `action_result` bool
- `backend_result` bool
- `backend_return_code` int
- `backend_authenticated` bool
- `backend_user_found` bool
- `backend_account_field` string
- `backend_display_name` string
- `backend_unique_user_id` string
- `cache_flush_additional_keys` array of strings
- `cache_flush_account_name` string
- `used_backend_address` string
- `used_backend_port` int
- `status_message_contain` array of strings
- `status_message_not_contain` array of strings
- `logs_contain` array of strings
- `logs_not_contain` array of strings
- `error_expected` bool

Notes:
- All fields are optional. The runner only validates fields that are present in `expected_output`.
- `status_message_contain`, `status_message_not_contain`, `logs_contain`, and `logs_not_contain` use substring matching against the collected output entries.
- `error_expected: true` requires at least one runtime or validation error. If it is omitted, it behaves like `false`.

Example:

```json
{
  "expected_output": {
    "environment_triggered": true,
    "environment_abort": false,
    "environment_result": 0,
    "status_message_not_contain": ["Access denied"],
    "logs_contain": ["policy accepted"],
    "logs_not_contain": ["panic"],
    "error_expected": false
  }
}
```

## Full end-to-end example

Lua script (`example_environment.lua`):

```lua
local ctx = require("nauthilus_context")
local redis = require("nauthilus_redis")

function nauthilus_call_environment(request)
  local user = ctx.context_get("username") or request.username
  local key = "tenant:" .. user
  local tenant, err = redis.redis_get("default", key)

  if err ~= nil then
    nauthilus_builtin.custom_log_add("tenant_error", tostring(err))
    return nauthilus_builtin.ENVIRONMENT_TRIGGER_NO, nauthilus_builtin.ENVIRONMENT_ABORT_NO, nauthilus_builtin.ENVIRONMENT_RESULT_FAIL
  end

  if tenant == nil then
    nauthilus_builtin.custom_log_add("tenant_status", "missing")
    return nauthilus_builtin.ENVIRONMENT_TRIGGER_NO, nauthilus_builtin.ENVIRONMENT_ABORT_NO, nauthilus_builtin.ENVIRONMENT_RESULT_OK
  end

  nauthilus_builtin.custom_log_add("tenant_status", "found")
  nauthilus_builtin.custom_log_add("tenant_value", tostring(tenant))
  return nauthilus_builtin.ENVIRONMENT_TRIGGER_YES, nauthilus_builtin.ENVIRONMENT_ABORT_NO, nauthilus_builtin.ENVIRONMENT_RESULT_OK
end
```

Fixture (`example_environment_test.json`):

```json
{
  "context": {
    "username": "alice",
    "expected_calls": [
      {"method": "context_get", "arg_contains": "username"}
    ]
  },
  "redis": {
    "initial_data": {
      "strings": {
        "tenant:alice": "acme"
      }
    },
    "expected_calls": [
      {"method": "redis_get", "arg_contains": "tenant:alice"}
    ]
  },
  "expected_output": {
    "environment_triggered": true,
    "logs_contain": ["tenant_status: found", "tenant_value: acme"],
    "error_expected": false
  }
}
```

Run:

```bash
go run ./server --test-lua example_environment.lua --test-callback environment --test-mock example_environment_test.json
```

## Plugin regression suite

Repository fixtures for core plugins:
- `testdata/lua/plugins/*.json`
- wrappers: `testdata/lua/plugins/*_wrapper.lua`
- ClickHouse-specific luatest fixtures and wrappers:
  - `server/testing/luatest/testdata/clickhouse/*.json`
  - `server/testing/luatest/testdata/clickhouse/*_wrapper.lua`

Run all plugin tests:

```bash
./scripts/run-lua-plugin-tests.sh
```

## CI pattern

```bash
set -euo pipefail

./scripts/run-lua-plugin-tests.sh
go run ./server --test-lua testdata/lua/example_subject.lua --test-callback subject --test-mock testdata/lua/subject_test.json
go run ./server --test-lua testdata/lua/example_environment.lua --test-callback environment --test-mock testdata/lua/environment_test.json
go run ./server --test-lua testdata/lua/example_action.lua --test-callback action --test-mock testdata/lua/action_test.json
go run ./server --test-lua testdata/lua/example_backend.lua --test-callback backend --test-mock testdata/lua/backend_test.json
go run ./server --test-lua testdata/lua/example_hook.lua --test-callback hook --test-mock testdata/lua/hook_test.json
go run ./server --test-lua testdata/lua/plugins/cache_flush_wrapper.lua --test-callback cache_flush --test-mock testdata/lua/plugins/cache_flush_test.json
```

## Troubleshooting

- `function not found`: ensure script defines the callback function matching `--test-callback`.
- `method mismatch` in `expected_calls`: check exact method name and order.
- `requires an active request binding`: ensure you call Redis functions through test runtime callback functions (`nauthilus_call_*`), not at top-level script load time.
- `query mismatch` in DB: adjust `query_contains` to real SQL substring.
- `logs_contain` mismatch: check exact custom log output (including prefixes/content).
- `status_message_contain` mismatch: verify script really calls `nauthilus_builtin.status_message_set(...)`.

## Related docs

- [Lua Backend](/docs/configuration/database-backends/lua)
- [Lua API](/docs/lua-api/introduction)
- [Full Configuration Example](/docs/configuration/full-example)
