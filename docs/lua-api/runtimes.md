---
title: Lua runtimes and capabilities
description: Which Lua modules and functions are available in init scripts, custom hooks, Lua backends, and policy callbacks
keywords: [Lua, Policy VM, Custom Hooks, Redis, Capabilities]
sidebar_position: 1.5
---
# Lua runtimes and capabilities

Nauthilus 4 does not run every Lua script with the same host API. A script runs in one of three runtimes, and the
runtime decides which modules can be loaded and which functions exist. The module pages of this reference describe the
full API; this page says where each part of it can be used.

The short version:

- **Init scripts, custom hooks, and Lua backends** keep the full Lua API, including Redis writes, outbound HTTP, LDAP,
  DNS, and mail.
- **Environment sources, subject sources, and actions** (including POST-Actions) that are configured under top-level
  `policy` run in the restricted **Policy VM**. It can read, emit policy attributes, and project the backend result, but
  it cannot write to Redis or the cache, open outbound connections, or select a backend server.
- **Generic Policy providers** (`kind: lua`) run in a separate, even smaller sandbox without `require`.

## Runtime overview

| Script type | Configured at | Runtime |
|---|---|---|
| Init script | `auth.backends.lua.backend.default.init_script_paths` | Process runtime (full API) |
| Custom hook | `auth.controls.lua.hooks` | Process runtime (full API) |
| Lua backend | `auth.backends.lua.backend.*.backend_script_path` | Backend runtime (full API) |
| Environment source | `policy.namespaces.authn.providers` with `kind: lua_environment` | Policy VM |
| Subject source | `policy.namespaces.authn.providers` with `kind: lua_subject` | Policy VM |
| Action and POST-Action | `policy.namespaces.authn.effects` with `kind: lua_action` | Policy VM |
| Generic Policy provider | `policy.namespaces.<namespace>.providers` with `kind: lua` | Generic sandbox, see [Generic Target-Aware Lua Providers](../guides/lua-policy-plugins.md#generic-target-aware-lua-providers) |

Scripts in the process and backend runtimes can use every module that is listed in the
[introduction](introduction.md#lua-libraries). Direct filesystem code loading (`dofile`, `loadfile`) is disabled in all
runtimes; shared code is loaded with `require` from the configured `package_path`.

## Policy VM

The Policy VM exists since Nauthilus 4.0.0. It evaluates a script before the configuration is accepted: when a script
or one of the modules it requires uses a module or function that the Policy VM does not provide, the configuration is
rejected at startup or reload. Nothing falls back to an unrestricted runtime.

The check is static. A forbidden function name anywhere in the script or in a required shared module rejects the
script, even when that code path would never run.

### Available modules

| Module | Availability in the Policy VM |
|---|---|
| `nauthilus_context` | Full |
| `nauthilus_http_request` | Full |
| `nauthilus_policy` | Attribute emission. Attribute registration belongs to the registry script, see [Lua Policy Plugins](../guides/lua-policy-plugins.md). |
| `nauthilus_password` | Full |
| `nauthilus_cbor`, `json`, `glua_crypto`, `time` | Full |
| `nauthilus_opentelemetry` | Full |
| `nauthilus_redis` | Read commands on the `"default"` handle only |
| `nauthilus_cache` | Read functions only |
| `nauthilus_prometheus` | Updates on collectors that already exist; no `create_*_vec` |
| `nauthilus_brute_force` | Read functions only; no custom tolerations |
| `nauthilus_psnet` | Lookup only; no `register_connection_target` |
| `nauthilus_i18n` | `get_localized` only; no `register_catalog` |
| `nauthilus_misc` | Without `wait_random` |
| `nauthilus_backend`, `nauthilus_backend_result` | Subject sources only: `get_current_backend_result`, `apply_backend_result`, `remove_from_backend_result`, `get_removed_backend_attributes` |
| `nauthilus_http_response` | Synchronous response actions only |
| Lua base, `table`, `string`, `math` | Available |

### Unavailable modules

`nauthilus_ldap`, `nauthilus_dns`, `nauthilus_mail`, `nauthilus_soft_whitelist`, `nauthilus_util`, `glua_http`, `os`,
`io`, `debug`, `channel`, and `coroutine` cannot be loaded. Environment variables are therefore not readable from a
policy callback.

### Unavailable functions

| Module | Functions that reject the script |
|---|---|
| `nauthilus_redis` | `register_redis_pool`, `redis_set`, `redis_incr`, `redis_del`, `redis_rename`, `redis_expire`, `redis_mset`, `redis_run_script`, `redis_upload_script`, `redis_pipeline`, `redis_hset`, `redis_hdel`, `redis_hincrby`, `redis_hincrbyfloat`, `redis_zadd`, `redis_zrem`, `redis_zremrangebyscore`, `redis_zremrangebyrank`, `redis_zincrby`, `redis_lpush`, `redis_rpush`, `redis_lpop`, `redis_rpop`, `redis_pfadd`, `redis_pfmerge`, `redis_sadd`, `redis_srem` |
| `nauthilus_cache` | `cache_set`, `cache_delete`, `cache_update`, `cache_flush`, `cache_push`, `cache_pop_all` |
| `nauthilus_backend` | `get_backend_servers`, `select_backend_server`, `get_selected_backend_server`, `check_backend_connection` |
| `nauthilus_prometheus` | `create_summary_vec`, `create_counter_vec`, `create_histogram_vec`, `create_gauge_vec` |
| `nauthilus_brute_force` | `set_custom_tolerations`, `set_custom_toleration`, `delete_custom_toleration` |
| `nauthilus_psnet` | `register_connection_target` |
| `nauthilus_i18n` | `register_catalog` |
| `nauthilus_misc` | `wait_random` |
| Lua base | `dofile`, `loadfile`, `loadstring`, `dynamic_loader` |

Create Prometheus collectors, register connection targets, Redis pools, and i18n catalogs in an
[init script](introduction.md#additional-things-to-know). Policy callbacks can then update the collectors.

## Where to put logic that writes state

Redis is not read-only in Nauthilus as a whole; only policy callbacks are read-only. Typical placements:

| Need | Place it in |
|---|---|
| Counters, quotas, rate limits, or other Redis writes during authentication | A [Lua backend](../configuration/database-backends/lua.md), or a [native Go plugin](../developer/go-plugins/index.md) |
| Reporting, management, or maintenance endpoints that read and write Redis | A [custom hook](../rest-api.md#custom-hooks) |
| Outbound HTTP, mail, LDAP, or DNS during a policy decision | A native Go plugin |
| Selecting the backend server for the nginx `Auth-Server` and `Auth-Port` headers | A native Go subject source that returns `SelectedBackend`, see [Result types](../developer/go-plugins/api-reference/results.md) |
| Deciding on values that already exist in Redis | A Lua environment or subject source that reads Redis and emits policy attributes |
| Changing attributes of the backend result | A Lua subject source with `apply_backend_result` |

## Bundled scripts and their status

The `lua-plugins.d` directory in the Nauthilus repository classifies every bundled script in
[`POLICY_VM_COMPATIBILITY.md`](https://github.com/croessner/nauthilus/blob/main/server/lua-plugins.d/POLICY_VM_COMPATIBILITY.md).
The status values mean:

| Status | Meaning |
|---|---|
| `supported` | The script loads in the Policy VM and may be configured under top-level `policy`. |
| `reference-only` | The script needs a capability that the Policy VM does not provide. It is kept as migration and design material. Configuring it under top-level `policy` is rejected. |
| `test-only` | The script exists for the Lua test framework. |
| `backend-runtime` | A Lua backend script. It runs with the full API when a Lua backend is configured. |
| `process-owned` | An init script or custom hook. It runs with the full API. |

In Nauthilus 4.0 the supported policy callbacks are `subject/idp_policy.lua` and `actions/bruteforce_header.lua`. The
bundled environment sources, the other subject sources (including `geoip.lua` and `monitoring.lua`), and the other
actions are `reference-only`. Their production replacements are the bundled native plugins `geoip`, `clickhouse`,
`haveibeenpwnd`, and `reputation`, see [Reference plugins](../developer/go-plugins/reference-plugins/index.md).

The Lua test framework mocks the full API, including functions that the Policy VM rejects. A passing callback test does
not show that a script loads in the Policy VM; check the script against the tables on this page, or start the server
with the script configured.
