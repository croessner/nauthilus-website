---
title: Lua Policy Plugins
description: Policy-aware Lua plugins, bundled policy attributes, and registry configuration
keywords: [Lua, Policy, Plugins, Attributes, Registry]
sidebar_position: 8
---

# Lua Policy Plugins

Nauthilus Lua plugins can emit typed policy attributes directly into the active request decision context. This lets a plugin collect a signal once and then let `auth.policy.policies` decide what the final effect should be.

## Enable the Bundled Registry

The bundled policy-aware plugins emit attributes below `lua.plugin.*`. Register these attributes before using them in policies:

```yaml
auth:
  policy:
    registry_scripts:
      - "/etc/nauthilus/lua-plugins.d/policy/registry.lua"
```

The registry is loaded when the policy snapshot is built. If a plugin emits an unknown attribute, the Lua execution fails instead of silently creating a loose fact.

## Plugin Helper

Bundled plugins use `nauthilus_policy_facts`:

```lua
local policy_facts = require("nauthilus_policy_facts")

policy_facts.emit("soft_delay", "risky", true)
policy_facts.emit_public("geoip", "rejected", true, {
    status_message = "Policy violation",
})
policy_facts.status_message("geoip", "Policy violation")
```

- `emit` and `emit_many` write policy attributes and request-local `policy_facts`.
- `emit_public` and `emit_many_public` also write `policy_fact_<namespace>_<key>` custom logs.
- `status_message` sets the normal Nauthilus status message and emits `lua.plugin.<namespace>.status_message`.
- `set` stores only request-local Lua context data and does not emit a policy attribute.

## Attribute Reference

All attributes below are registered by `lua-plugins.d/policy/registry.lua`.

### Feature Plugins

| Plugin | Attribute | Type | Meaning |
|---|---|---:|---|
| `account_longwindow_metrics.lua` | `lua.plugin.account_longwindow.username` | string | Account name used by the long-window collector. |
| `account_longwindow_metrics.lua` | `lua.plugin.account_longwindow.authenticated` | bool | Whether the request was authenticated when metrics were collected. |
| `account_longwindow_metrics.lua` | `lua.plugin.account_longwindow.uniq_ips_24h` | number | Unique account IP estimate over 24 hours. |
| `account_longwindow_metrics.lua` | `lua.plugin.account_longwindow.uniq_ips_7d` | number | Unique account IP estimate over 7 days. |
| `account_longwindow_metrics.lua` | `lua.plugin.account_longwindow.fails_24h` | number | Failed account attempts over 24 hours. |
| `account_longwindow_metrics.lua` | `lua.plugin.account_longwindow.fails_7d` | number | Failed account attempts over 7 days. |
| `account_longwindow_metrics.lua` | `lua.plugin.account_longwindow.has_pw_token` | bool | Whether the request produced a sprayed-password token. |
| `global_pattern_monitoring.lua` | `lua.plugin.global_pattern.attempts` | number | Global attempts in the current window. |
| `global_pattern_monitoring.lua` | `lua.plugin.global_pattern.unique_ips` | number | Global unique IP estimate. |
| `global_pattern_monitoring.lua` | `lua.plugin.global_pattern.unique_users` | number | Global unique user estimate. |
| `global_pattern_monitoring.lua` | `lua.plugin.global_pattern.attempts_per_ip` | number | Attempts-per-IP ratio. |
| `global_pattern_monitoring.lua` | `lua.plugin.global_pattern.attempts_per_user` | number | Attempts-per-user ratio. |
| `global_pattern_monitoring.lua` | `lua.plugin.global_pattern.ips_per_user` | number | IPs-per-user ratio. |
| `security_metrics.lua` | `lua.plugin.security_metrics.global_ips_per_user_24h` | number | Global IPs-per-user ratio over 24 hours. |
| `security_metrics.lua` | `lua.plugin.security_metrics.global_ips_per_user_7d` | number | Global IPs-per-user ratio over 7 days. |
| `security_metrics.lua` | `lua.plugin.security_metrics.protected_accounts` | number | Number of accounts currently in protection mode. |
| `failed_login_hotspot.lua` | `lua.plugin.failed_login_hotspot.username` | string | Username evaluated against the failed-login hotspot set. |
| `failed_login_hotspot.lua` | `lua.plugin.failed_login_hotspot.count` | number | Failed-login hotspot score. |
| `failed_login_hotspot.lua` | `lua.plugin.failed_login_hotspot.rank` | number | Failed-login hotspot rank. |
| `failed_login_hotspot.lua` | `lua.plugin.failed_login_hotspot.triggered` | bool | Whether the hotspot threshold matched. |
| `blocklist.lua` | `lua.plugin.blocklist.matched` | bool | Whether the remote client matched the blocklist. |
| `blocklist.lua` | `lua.plugin.blocklist.client_ip` | ip | Client IP sent to the blocklist service. |
| `blocklist.lua` | `lua.plugin.blocklist.status_message` | string | Client-visible blocklist message. |

`lua.plugin.blocklist.matched` carries a public `status_message` detail when it is emitted.

### Filter Plugins

| Plugin | Attribute | Type | Meaning |
|---|---|---:|---|
| `account_centric_monitoring.lua` | `lua.plugin.account_monitoring.attack_detected` | bool | Whether account-centric monitoring detected an attack pattern. |
| `account_centric_monitoring.lua` | `lua.plugin.account_monitoring.username` | string | Username evaluated by the monitor. |
| `account_centric_monitoring.lua` | `lua.plugin.account_monitoring.uniq_ips_1h` | number | Unique account IP estimate over 1 hour. |
| `account_centric_monitoring.lua` | `lua.plugin.account_monitoring.uniq_ips_24h` | number | Unique account IP estimate over 24 hours. |
| `account_centric_monitoring.lua` | `lua.plugin.account_monitoring.uniq_ips_7d` | number | Unique account IP estimate over 7 days. |
| `account_centric_monitoring.lua` | `lua.plugin.account_monitoring.failed_24h` | number | Failed account attempts over 24 hours. |
| `account_centric_monitoring.lua` | `lua.plugin.account_monitoring.ratio_24h` | number | Account IP-to-failure ratio over 24 hours. |
| `account_protection_mode.lua` | `lua.plugin.account_protection.active` | bool | Whether account protection mode is active. |
| `account_protection_mode.lua` | `lua.plugin.account_protection.reason` | string | Comma-separated protection reason codes. |
| `account_protection_mode.lua` | `lua.plugin.account_protection.backoff_level` | number | Current protection backoff level. |
| `account_protection_mode.lua` | `lua.plugin.account_protection.delay_ms` | number | Delay applied in milliseconds. |
| `account_protection_mode.lua` | `lua.plugin.account_protection.enforce_reject` | bool | Whether protection mode rejects unauthenticated traffic. |
| `account_protection_mode.lua` | `lua.plugin.account_protection.status_message` | string | Client-visible protection message. |
| `geoip.lua` | `lua.plugin.geoip.guid` | string | GeoIP service request identifier. |
| `geoip.lua` | `lua.plugin.geoip.current_country_code` | string | Current ISO-3166 alpha-2 country code. |
| `geoip.lua` | `lua.plugin.geoip.country_codes` | string_list | Country codes observed by the GeoIP service. |
| `geoip.lua` | `lua.plugin.geoip.rejected` | bool | Whether the GeoIP service requested rejection. |
| `geoip.lua` | `lua.plugin.geoip.error` | bool | Whether the GeoIP service returned an error. |
| `geoip.lua` | `lua.plugin.geoip.status_message` | string | Client-visible GeoIP message. |
| `idp_policy.lua` | `lua.plugin.idp_policy.rejected` | bool | Whether the IdP Lua policy rejected the request. |
| `idp_policy.lua` | `lua.plugin.idp_policy.reason` | string | Reason returned by the IdP Lua policy. |
| `idp_policy.lua` | `lua.plugin.idp_policy.oidc_cid` | string | OIDC client identifier evaluated by the plugin. |
| `idp_policy.lua` | `lua.plugin.idp_policy.grant_type` | string | OIDC grant type evaluated by the plugin. |
| `idp_policy.lua` | `lua.plugin.idp_policy.status_message` | string | Client-visible IdP policy message. |
| `monitoring.lua` | `lua.plugin.director.backend_server` | string | Backend server selected by the director subject source. |
| `soft_delay.lua` | `lua.plugin.soft_delay.risky` | bool | Whether the soft-delay subject source considered the request risky. |
| `soft_delay.lua` | `lua.plugin.soft_delay.applied_ms` | number | Delay applied in milliseconds. |

`lua.plugin.account_protection.active`, `lua.plugin.geoip.rejected`, and `lua.plugin.idp_policy.rejected` carry a public `status_message` detail when emitted with a client-visible message.

## Policy Example

```yaml
auth:
  policy:
    registry_scripts:
      - "/etc/nauthilus/lua-plugins.d/policy/registry.lua"

    checks:
      - name: lua_subject_geoip
        type: lua.subject
        stage: subject_analysis
        operations: [authenticate]
        config_ref: auth.policy.attribute_sources.lua.subject.geoip

    policies:
      - name: deny_geoip_rejection
        stage: auth_decision
        operations: [authenticate]
        require_checks: [lua_subject_geoip]
        if:
          attribute: lua.plugin.geoip.rejected
          is: true
        then:
          decision: deny
          reason: geoip_policy_rejected
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: lua.plugin.geoip.rejected
            detail: status_message
            fallback: "Invalid login or password"
```

## Writing Your Own Emitter

Register the attribute:

```lua
nauthilus_policy.register_attribute({
  id = "lua.plugin.example.risky",
  stage = "subject_analysis",
  operations = { "authenticate" },
  category = "environment",
  type = "bool",
  description = "Example risk flag",
})
```

Emit it from a request-time Lua plugin:

```lua
local policy = require("nauthilus_policy")

policy.emit_attribute({
  id = "lua.plugin.example.risky",
  value = true,
})
```

The emitted type, operation, and stage must match the registry definition.
