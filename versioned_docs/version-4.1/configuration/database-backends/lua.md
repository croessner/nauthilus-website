---
title: Lua Backend
description: Lua backend and Lua policy extension configuration in config v2
keywords: [Configuration, Lua, Backend]
sidebar_position: 7
---

# Lua Backend

Config v2 separates Lua credential verification from Lua policy extension points.

## Two Lua Areas

Credential verification:

- `auth.backends.lua.backend.default`
- `auth.backends.lua.backend.named_backends`
- `auth.backends.lua.backend.search`

Policy extension points:

- `policy.namespaces.authn.providers` with `kind: lua_environment`
- `policy.namespaces.authn.providers` with `kind: lua_subject`
- `policy.namespaces.authn.effects` with `kind: lua_action`
- `auth.controls.lua.hooks`

This split is intentional: backend verification and control logic are different concerns.

## Backend Example

```yaml
auth:
  backends:
    lua:
      backend:
        default:
          backend_script_path: "/etc/nauthilus/lua/backend.lua"
          init_script_paths:
            - "/etc/nauthilus/lua/init.lua"
          package_path: "/etc/nauthilus/lualib/?.lua"
          backend_number_of_workers: 10
          action_number_of_workers: 10
          queue_length: 100
          cache_flush_script_path: "/etc/nauthilus/lua/cache_flush.lua"
        named_backends:
          reporting:
            backend_script_path: "/etc/nauthilus/lua/reporting.lua"
            backend_number_of_workers: 4
        search:
          - protocol:
              - imap
              - smtp
            cache_name: "mail"
          - protocol:
              - oidc
              - saml
            cache_name: "identity"
```

## Lua Policy Extension Example

```yaml
auth:
  controls:
    enabled:
      - lua
    lua:
      hooks:
        - http_location: "status"
          http_method: "GET"
          script_path: "/etc/nauthilus/lua/hooks/status.lua"
          public: false
          scopes:
            - "nauthilus:admin"

        - http_location: "health-summary"
          http_method: "GET"
          script_path: "/etc/nauthilus/lua/hooks/health-summary.lua"
          public: true

policy:
  namespaces:
    authn:
      providers:
        lua_environment_risk_facts:
          kind: lua_environment
          script_path: "/etc/nauthilus/lua/environment/risk_facts.lua"
          targets: [{action: authenticate}]
          executions: [host_sync]
        lua_environment_policy_gate:
          kind: lua_environment
          script_path: "/etc/nauthilus/lua/environment/policy_gate.lua"
          targets: [{action: authenticate}]
          executions: [host_sync]
        lua_subject_idp_context:
          kind: lua_subject
          script_path: "/etc/nauthilus/lua/subject/idp_context.lua"
          targets: [{action: authenticate}]
          executions: [host_sync]
        lua_subject_idp_policy:
          kind: lua_subject
          script_path: "/etc/nauthilus/lua/subject/idp_policy.lua"
          targets: [{action: authenticate}]
          executions: [host_sync]
      effects:
        lua_action_bruteforce_header:
          kind: lua_action
          action_type: brute_force
          script_path: "/etc/nauthilus/lua-plugins.d/actions/bruteforce_header.lua"
          execution: host_sync
```

:::note Policy callbacks use the full Lua API since Nauthilus 4.1.1
Scripts configured as `lua_environment`, `lua_subject`, or `lua_action` can write to Redis and the cache and can use
outbound HTTP, LDAP, DNS, and mail, like hooks, init scripts, and backend scripts. Every bundled `lua-plugins.d`
environment, subject, and action script can be configured here. Nauthilus 4.0.0 to 4.1.0 rejected such scripts when
the configuration was loaded. See [Lua runtimes and capabilities](../../lua-api/runtimes.md).
:::

The effect entries define reusable scripts. Request-time dispatch is selected by the active policy decision, not by the effect definition itself. Synchronous actions use `auth.obligation.lua_action.dispatch` with `action_type` set to `brute_force`, `lua`, `tls_encryption`, `relay_domains`, or `rbl`; Lua POST-Actions use `auth.obligation.lua_post_action.enqueue` with `action_type: post` and `execution: host_post_action`.

## Scheduling with top-level Policy

Lua environment and subject providers are scheduled by checkpoint provider instances. Use the domain plan to select the action, optional auth-state guard, and start order.

```yaml
policy:
  namespaces:
    authn:
      domain_plans:
        password:
          checkpoints:
            pre_auth:
              providers:
                - name: risk_facts
                  use: authn/lua_environment_risk_facts
                  actions: [authenticate, lookup_identity]
                  run_if:
                    auth_state: any
                - name: policy_gate
                  use: authn/lua_environment_policy_gate
                  actions: [authenticate, lookup_identity]
                  after: [risk_facts]
                  run_if:
                    auth_state: any
```

Use `actions` for request action scope, `run_if.auth_state` for authenticated or unauthenticated scheduling, and `after` for provider ordering.

For the full migration workflow, see [Policy Configuration Guide](../../guides/auth-policy-configuration.md). For the complete ownership model, see [Policy Configuration](../auth-policy.md).

## Hook Authorization

Lua hooks are fail-closed unless their access model is explicit. `public` and `scopes` have the following semantics;
scoped Basic credentials count as callers since 4.1.0:

| Hook configuration | Accepted authentication |
| --- | --- |
| `public: true` and no `scopes` | No authentication is required. |
| No `public` marker and no `scopes` | The unrestricted backchannel Basic credential (`auth.backchannel.basic_auth.username` and `password`) is required. A scoped Basic credential cannot open the hook. |
| One or more `scopes` | A caller holding at least one configured scope is required: a valid Bearer access token, or a scoped Basic credential (`auth.backchannel.basic_auth.users`). Both are authorized alike. |

For a scoped hook, the unrestricted Basic credential holds no scope and does not satisfy the scope requirement; it is
refused with `403`. If OIDC Bearer authentication is not enabled, a scoped hook is open to scoped Basic credentials
only. Missing or invalid credentials return `401`; a valid Bearer token or Basic credential without any required scope
returns `403`.

Do not set `public: true` merely to restore the pre-hardening behavior of an unscoped hook. Use it only when anonymous
access to that script and its output is intentional. When `scopes` are present, the scope requirement takes
precedence; omit `public` to keep the configuration unambiguous.

Backchannel Bearer acceptance is configured under:

- `auth.backchannel.oidc_bearer.enabled`

Backchannel Basic credentials are configured under:

- `auth.backchannel.basic_auth` (see [Backchannel Basic Credentials](../../rest-api.md#backchannel-basic-credentials))

Example of an explicitly public hook:

```yaml
auth:
  controls:
    lua:
      hooks:
        - http_location: "health-summary"
          http_method: "GET"
          script_path: "/etc/nauthilus/lua/hooks/health-summary.lua"
          public: true
```

Example of a protected hook:

```yaml
auth:
  controls:
    lua:
      hooks:
        - http_location: "maintenance"
          http_method: "POST"
          script_path: "/etc/nauthilus/lua/hooks/maintenance.lua"
          scopes:
            - "nauthilus:admin"
            - "nauthilus:security"
```

Scope matching is any-of: either scope in this example authorizes the request after Bearer validation.

## Notes

- keep `controls` and `services` semantics separate
- use `auth.controls.lua.hooks`, not `lua.custom_hooks`
- use `auth.backends.lua.backend.*` for verification backends, not for policy
