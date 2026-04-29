---
title: Lua Backend
description: Lua backend and Lua control configuration in config v2
keywords: [Configuration, Lua, Backend]
sidebar_position: 7
---

# Lua Backend

Config v2 separates Lua credential verification from Lua policy execution.

## Two Lua Areas

Credential verification:

- `auth.backends.lua.backend.default`
- `auth.backends.lua.backend.named_backends`
- `auth.backends.lua.backend.search`

Policy and extension points:

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
          when_authenticated: true
          when_unauthenticated: true
          when_no_auth: false
        - name: "policy_gate"
          script_path: "/etc/nauthilus/lua/controls/policy_gate.lua"
          depends_on:
            - "geoip"
          when_authenticated: true
          when_unauthenticated: true
          when_no_auth: false
      filters:
        - name: "idp_context"
          script_path: "/etc/nauthilus/lua/filters/idp_context.lua"
        - name: "idp_policy"
          script_path: "/etc/nauthilus/lua/filters/idp_policy.lua"
          depends_on:
            - "idp_context"
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

## Dependency Ordering with depends_on

`depends_on` is available on Lua controls and Lua filters:

- `auth.controls.lua.controls[*].depends_on`
- `auth.controls.lua.filters[*].depends_on`

It is a list of script names from the same list. A control can depend on another control. A filter can depend on another filter. Dependencies are not shared between the control and filter lists.

```yaml
auth:
  controls:
    lua:
      controls:
        - name: "geoip"
          script_path: "/etc/nauthilus/lua/controls/geoip.lua"
          when_authenticated: true
          when_unauthenticated: true
          when_no_auth: false
        - name: "policy_gate"
          script_path: "/etc/nauthilus/lua/controls/policy_gate.lua"
          depends_on:
            - "geoip"
          when_authenticated: true
          when_unauthenticated: true
          when_no_auth: false
```

Nauthilus builds deterministic dependency levels from these names. Scripts in the same level can run in parallel. A dependent script runs only after all scripts it depends on have completed and their request-local Lua context changes have been merged.

The configuration is validated during startup:

- script names must be unique within the list
- dependencies must reference existing names in the same list
- a script cannot depend on itself
- dependency cycles are rejected
- the dependency must be runnable in all request modes required by the dependent script

## Hook Authorization

If `scopes` are configured on a Lua hook, the request must present a valid Bearer token and the token must include at least one required scope.

Backchannel Bearer acceptance is configured under:

- `auth.backchannel.oidc_bearer.enabled`

## Notes

- keep `controls` and `services` semantics separate
- use `auth.controls.lua.hooks`, not `lua.custom_hooks`
- use `auth.backends.lua.backend.*` for verification backends, not for policy
