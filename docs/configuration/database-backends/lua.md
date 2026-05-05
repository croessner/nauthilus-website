---
title: Lua Backend
description: Lua backend and Lua control configuration in config v2
keywords: [Configuration, Lua, Backend]
sidebar_position: 7
---

# Lua Backend

Config v2 separates Lua credential verification from Lua control and extension points.

## Two Lua Areas

Credential verification:

- `auth.backends.lua.backend.default`
- `auth.backends.lua.backend.named_backends`
- `auth.backends.lua.backend.search`

Controls and extension points:

- `auth.controls.lua.controls`
- `auth.controls.lua.filters`
- `auth.controls.lua.actions`
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

## Lua Controls Example

```yaml
auth:
  controls:
    enabled:
      - lua
    lua:
      controls:
        - name: "geoip"
          script_path: "/etc/nauthilus/lua/controls/geoip.lua"
        - name: "policy_gate"
          script_path: "/etc/nauthilus/lua/controls/policy_gate.lua"
      filters:
        - name: "idp_context"
          script_path: "/etc/nauthilus/lua/filters/idp_context.lua"
        - name: "idp_policy"
          script_path: "/etc/nauthilus/lua/filters/idp_policy.lua"
      actions:
        - type: "brute_force"
          name: "telegram"
          script_path: "/etc/nauthilus/lua/actions/telegram.lua"
      hooks:
        - http_location: "status"
          http_method: "GET"
          script_path: "/etc/nauthilus/lua/hooks/status.lua"
          scopes:
            - "nauthilus:admin"
```

## Scheduling with Auth Policy

Lua controls and Lua filters are scheduled through `auth.policy.checks`. Use the check plan to select the operation, optional auth-state guard, and start order.

```yaml
auth:
  policy:
    checks:
      - name: "lua_control_geoip"
        type: "lua.control"
        stage: "pre_auth"
        operations: ["authenticate", "lookup_identity"]
        config_ref: "auth.controls.lua.controls.geoip"
        output: "checks.lua_control_geoip"

      - name: "lua_control_policy_gate"
        type: "lua.control"
        stage: "pre_auth"
        operations: ["authenticate", "lookup_identity"]
        after: ["lua_control_geoip"]
        config_ref: "auth.controls.lua.controls.policy_gate"
        output: "checks.lua_control_policy_gate"
```

Use `operations` for request operation scope, `run_if.auth_state` for authenticated or unauthenticated scheduling, and `after` for check ordering.

For the full migration workflow, see [Auth Policy Configuration Guide](../../guides/auth-policy-configuration.md). For the complete policy schema, see [Auth Policy Reference](../auth-policy.md).

## Hook Authorization

If `scopes` are configured on a Lua hook, the request must present a valid Bearer token and the token must include at least one required scope.

Backchannel Bearer acceptance is configured under:

- `auth.backchannel.oidc_bearer.enabled`

## Notes

- keep `controls` and `services` semantics separate
- use `auth.controls.lua.hooks`, not `lua.custom_hooks`
- use `auth.backends.lua.backend.*` for verification backends, not for policy
