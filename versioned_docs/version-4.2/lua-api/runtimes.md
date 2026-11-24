---
title: Lua runtimes and capabilities
description: Which Lua modules and functions are available in init scripts, custom hooks, Lua backends, and policy callbacks
keywords: [Lua, Policy VM, Custom Hooks, Redis, Capabilities]
sidebar_position: 1.5
---
# Lua runtimes and capabilities

Since Nauthilus 4.1.1 every Lua script runs with the same host API. Environment sources, subject sources, and actions
can use everything that init scripts, custom hooks, and Lua backends can use: Redis writes, the cache, outbound HTTP,
LDAP, DNS, mail, metric creation, backend server selection, and the complete Lua standard library.

:::important Nauthilus 4.0.0 to 4.1.0 limited policy callbacks
The releases 4.0.0 to 4.1.0 ran environment sources, subject sources, and actions in a restricted "Policy VM" and
rejected a configuration whose callback used a function outside a small read-only set. That limit was not intended and
broke scripts that worked on Nauthilus 3. Nauthilus 4.1.1 removed it. If you run 4.0.x or 4.1.0 and your configuration
is rejected because of a Lua callback, upgrade to 4.1.1 or later; see
[Restrictions in Nauthilus 4.0.0 to 4.1.0](#restrictions-in-nauthilus-400-to-410).
:::

## Runtime overview

| Script type | Configured at | Lua API |
|---|---|---|
| Init script | `auth.backends.lua.backend.default.init_script_paths` | Full API |
| Custom hook | `auth.controls.lua.hooks` | Full API |
| Lua backend | `auth.backends.lua.backend.*.backend_script_path` | Full API |
| Environment source | `policy.namespaces.authn.providers` with `kind: lua_environment` | Full API |
| Subject source | `policy.namespaces.authn.providers` with `kind: lua_subject` | Full API, plus backend server selection |
| Action and POST-Action | `policy.namespaces.authn.effects` with `kind: lua_action` | Full API |
| Policy registry script | `policy.namespaces.authn.schema_contributions.lua.registry_scripts` | Lua standard library and `nauthilus_policy.register_attribute` |
| Generic Policy provider | `policy.namespaces.<namespace>.providers` with `kind: lua` | Separate sandbox, see [Generic Target-Aware Lua Providers](../guides/lua-policy-plugins.md#generic-target-aware-lua-providers) |

"Full API" means every module that is listed in the [introduction](introduction.md#lua-libraries), every bundled helper
library, and the complete Lua 5.1 standard library including `os`, `io`, `debug`, `coroutine`, `load`, `loadstring`,
`dofile`, and `loadfile`.

## Lua engine and JIT compiler

Since Nauthilus 4.2.0 Lua code runs on [gopher-lua-jit](https://github.com/croessner/gopher-lua-jit), a
GopherLua-compatible Lua 5.1 engine with a native just-in-time compiler for hot loops. The pooled VMs that run Lua
backends, custom hooks, actions, environment sources, and subject sources compile numeric loops and loops over number
arrays to machine code on Linux and macOS (amd64 and arm64). Everything else, and every other platform, runs in the
interpreter with identical results. Short-lived states, such as generic `kind: lua` policy providers and registry
scripts, always use the interpreter.

The compiler is enabled by default. `jit: false` in `auth.backends.lua.backend.default` runs the interpreter only; a
change takes effect after a restart:

```yaml
auth:
  backends:
    lua:
      backend:
        default:
          jit: false
```

Scripts need no changes. Two details differ from Nauthilus 4.1:

- `pairs` visits the array part first, then string keys in insertion order, then all other keys in insertion order.
  Scripts must still not rely on a particular order.
- Compiler defects of the previous engine are fixed. For example, `goto` no longer detaches closures from the local
  variables of the surrounding function, and `v = t.x and y` assigns `nil` or `false` when `t.x` is falsy instead of
  leaving `v` unchanged.

When you analyse a Lua problem, compare the behaviour with `jit: false`, and report any difference between both modes.

## Differences between the runtimes

The runtimes differ only where the request itself differs:

| Module or function | Where it differs |
|---|---|
| `nauthilus_backend`, `nauthilus_backend_result` | Bound in subject sources: `get_backend_servers`, `select_backend_server`, `get_selected_backend_server`, `check_backend_connection`, `get_current_backend_result`, `apply_backend_result`, `remove_from_backend_result`, `get_removed_backend_attributes`. |
| `nauthilus_http_response` | A custom hook controls its complete response. In environment sources, subject sources, and synchronous actions the response headers a script sets reach the client; status and body of an authentication response stay with the server. A POST-Action runs after the response left the server; its calls are accepted and have no effect. |
| `nauthilus_http_request` | Bound when the script runs for an HTTP request. |
| `nauthilus_ldap` | Bound when an LDAP backend is configured. |
| `nauthilus_i18n` | `register_catalog` exists in init scripts. Request-time scripts call `get_localized`. |
| `nauthilus_policy` | Attribute emission in environment sources, subject sources, and Lua backends. Attribute registration belongs to the registry script, see [Lua Policy Plugins](../guides/lua-policy-plugins.md). |

## Loading shared modules

`require` resolves the preloaded host modules and the Lua files found through the configured `package_path`. Nauthilus
reads those files when it loads the configuration and keeps that copy for the whole configuration generation:

- A changed or added module file becomes active with the next configuration reload, not immediately.
- `package.path` is empty inside a script. Extending it at runtime does not make `require` search the file system.
- `dofile` and `loadfile` read a file by its path each time they are called.
- `require` accepts a computed module name, for example `require("nauthilus_" .. name)`.

## What is checked when the configuration is loaded

Nauthilus compiles every configured environment source, subject source, and action when it loads or reloads the
configuration. It does not execute them. A configuration is rejected when a script

- does not compile, or
- names its entry point (`nauthilus_call_environment`, `nauthilus_call_subject`, or `nauthilus_call_action`) neither
  in the script itself nor in a Lua module found through the configured `package_path`. This catches a script that is
  configured for the wrong stage.

Everything else is decided when a request runs the script: module-level code runs with every request, and a
`require` of a module that does not exist fails at that point. Nothing is checked statically; a script is not rejected
because of a function or module name it mentions.

## Global variables and pooled VMs

Each configured callback has its own pool of pre-built Lua VMs, and a VM is reused for later requests. For every
request Nauthilus puts a fresh request environment on top of the VM's base environment and maps the request-bound
modules into it. The callback script runs in that environment:

- A global variable that the script assigns, including its entry function, lives only for that request.
- State outside the request environment stays in the VM and is visible to later requests of the same callback, as in
  custom hooks and in Nauthilus 3. This applies to explicit writes to `_G`, to changes of shared tables such as
  `string`, and to globals assigned by a module that is loaded with `require`. Do not keep request data there.
- A module loaded with `require` is compiled once when the configuration is loaded (since 4.1.2; earlier releases
  compiled it for every request) and is executed again for every request.

Nauthilus 4.0.0 to 4.1.0 also rebuilt the base global table for every request.

## Restrictions in Nauthilus 4.0.0 to 4.1.0

This section applies only to the releases 4.0.0 to 4.1.0. In those releases environment sources, subject sources, and
actions ran in the Policy VM with these limits, and a callback that used anything else was rejected when the
configuration was loaded. The check was static: a forbidden name anywhere in the script or in a required shared module
rejected the script.

| Area | Limit in 4.0.0 to 4.1.0 | Since 4.1.1 |
|---|---|---|
| `nauthilus_redis` | Read commands on the `"default"` handle only; no writes, pipelines, scripts, or named pools | Complete module |
| `nauthilus_cache` | Read functions only | Complete module |
| `nauthilus_prometheus` | No `create_*_vec` | Complete module |
| `nauthilus_brute_force` | No custom tolerations | Complete module |
| `nauthilus_psnet` | No `register_connection_target` | Complete module |
| `nauthilus_misc` | No `wait_random` | Complete module |
| `nauthilus_backend` | No server selection in subject sources | Complete module in subject sources |
| `nauthilus_http_response` | Synchronous response actions only | Environment sources, subject sources, and actions |
| `nauthilus_ldap`, `nauthilus_dns`, `nauthilus_mail`, `nauthilus_soft_whitelist`, `nauthilus_util`, `glua_http` | Not loadable | Loadable |
| Standard library | No `os`, `io`, `debug`, `channel`, `coroutine`; no `print`, `load`, `loadstring`, `dofile`, `loadfile`; no environment variables | Complete |
| Helper libraries | `json`, `glua_crypto`, and a UTC-only `time` | All bundled libraries; `time` with any time zone |
| `require` | Literal module names only | Any expression |

Custom hooks, init scripts, and Lua backends had the full API in those releases as well, except `dofile` and
`loadfile`, which 4.1.1 restored in every runtime.

## Bundled scripts and their status

The `lua-plugins.d` directory in the Nauthilus repository lists every bundled script in
[`POLICY_VM_COMPATIBILITY.md`](https://github.com/croessner/nauthilus/blob/main/server/lua-plugins.d/POLICY_VM_COMPATIBILITY.md).
The status values mean:

| Status | Meaning |
|---|---|
| `supported` | The script may be configured under top-level `policy`. |
| `supported, native alternative` | The script may be configured under top-level `policy`; a bundled native plugin covers the same task and is the maintained path. |
| `test-only` | The script exists for the Lua test framework. |
| `backend-runtime` | A Lua backend script. |
| `process-owned` | An init script or custom hook. |

Since Nauthilus 4.1.1 every bundled environment source, subject source, and action can be configured under top-level
`policy`. The native plugins `geoip`, `clickhouse`, and `haveibeenpwnd` are maintained alternatives to
`subject/geoip.lua`, `actions/clickhouse.lua`, and `actions/haveibeenpwnd.lua`, see
[Reference plugins](../developer/go-plugins/reference-plugins/index.md).

The [Lua test framework](../guides/lua-test-framework.md) mocks the Lua API. A passing callback test shows that the
script logic works against the mocks; start the server with the script configured to see it load in the real runtime.
