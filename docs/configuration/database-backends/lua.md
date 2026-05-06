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

- `auth.policy.attribute_sources.lua.environment`
- `auth.policy.attribute_sources.lua.subject`
- `auth.policy.obligation_targets.lua.actions`
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
          scopes:
            - "nauthilus:admin"

  policy:
    attribute_sources:
      lua:
        environment:
          - name: "geoip"
            script_path: "/etc/nauthilus/lua/environment/geoip.lua"
          - name: "policy_gate"
            script_path: "/etc/nauthilus/lua/environment/policy_gate.lua"
        subject:
          - name: "idp_context"
            script_path: "/etc/nauthilus/lua/subject/idp_context.lua"
          - name: "idp_policy"
            script_path: "/etc/nauthilus/lua/subject/idp_policy.lua"

    obligation_targets:
      lua:
        actions:
          - type: "brute_force"
            name: "telegram"
            script_path: "/etc/nauthilus/lua/actions/telegram.lua"
```

The `actions` entries define reusable scripts. Request-time dispatch is selected by the active policy decision, not by the action definition itself. Synchronous actions use `auth.obligation.lua_action.dispatch` with `action` set to `brute_force`, `lua`, `tls_encryption`, `relay_domains`, or `rbl`; Lua POST-Actions use `auth.obligation.lua_post_action.enqueue` for `type: "post"` actions.

## Scheduling with Auth Policy

Lua environment and subject sources are scheduled through `auth.policy.checks`. Use the check plan to select the operation, optional auth-state guard, and start order.

```yaml
auth:
  policy:
    checks:
      - name: "lua_environment_geoip"
        type: "lua.environment"
        stage: "pre_auth"
        operations: ["authenticate", "lookup_identity"]
        config_ref: "auth.policy.attribute_sources.lua.environment.geoip"
        output: "checks.lua_environment_geoip"

      - name: "lua_environment_policy_gate"
        type: "lua.environment"
        stage: "pre_auth"
        operations: ["authenticate", "lookup_identity"]
        after: ["lua_environment_geoip"]
        config_ref: "auth.policy.attribute_sources.lua.environment.policy_gate"
        output: "checks.lua_environment_policy_gate"
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
