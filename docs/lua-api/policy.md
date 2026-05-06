---
title: Policy
description: Lua API for emitting request-local policy attributes
keywords: [Lua, Policy, Attributes]
sidebar_position: 21
---

# Policy

```lua
local nauthilus_policy = require("nauthilus_policy")
```

The `nauthilus_policy` module is available to request-time Lua environment and subject sources. It emits Lua-owned custom attributes into the active policy decision context.

Registry scripts also use the global `nauthilus_policy.register_attribute(...)` function during policy snapshot compilation. Runtime plugins use the module function documented here.

## nauthilus\_policy.emit\_attribute

Records one registered Lua-owned policy attribute.

### Syntax

```lua
nauthilus_policy.emit_attribute({
  id = "lua.plugin.example.risky",
  value = true,
  details = {
    status_message = "Policy violation",
  },
})
```

### Parameters

- `id` (string): Registered attribute ID.
- `value` (boolean/string/number/table): Attribute value. The Lua value must match the registered attribute type.
- `details` (table, optional): Detail values keyed by registered detail name.

### Types

| Registry type | Lua value | Runtime value |
|---|---|---|
| `bool` | boolean | boolean |
| `string` | string | string |
| `string_list` | array table of strings | string list |
| `number` | number | number |
| `ip` | string | IP address |
| `cidr` | string | network prefix |
| `datetime` | RFC3339 string | timestamp |

### Validation

Emission fails if:

- the attribute is not registered in the active policy snapshot;
- the attribute is not Lua-owned;
- the registered stage does not match the current Lua runtime stage;
- the active operation is not listed in the registry definition;
- the value or detail type does not match the registry definition;
- a detail exceeds its registered `max_length`.

Failures abort the Lua execution like other Lua runtime errors.

### Test Mode

`--test-lua` provides a fixture-aware mock for `nauthilus_policy.emit_attribute`. The mock records emitted attributes for `policy.expected_calls`, but it does not build or validate a real policy snapshot. See [Lua Test Framework](../guides/lua-test-framework.md#policy).

### Example

Registry script:

```lua
nauthilus_policy.register_attribute({
  id = "lua.plugin.geoip.rejected",
  stage = "subject_analysis",
  operations = { "authenticate" },
  category = "environment",
  type = "bool",
  description = "GeoIP rejection flag",
  details = {
    status_message = {
      type = "string",
      sensitivity = "public",
      purpose = "response_message",
      max_length = 256,
    },
  },
})
```

Subject source script:

```lua
local nauthilus_policy = require("nauthilus_policy")

nauthilus_policy.emit_attribute({
  id = "lua.plugin.geoip.rejected",
  value = true,
  details = {
    status_message = "Policy violation",
  },
})
```

Policy rule:

```yaml
auth:
  policy:
    registry_scripts:
      - "/etc/nauthilus/lua-plugins.d/policy/registry.lua"

    policies:
      - name: deny_geoip_rejection
        stage: auth_decision
        operations: [authenticate]
        if:
          attribute: lua.plugin.geoip.rejected
          is: true
        then:
          decision: deny
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: lua.plugin.geoip.rejected
            detail: status_message
            fallback: "Invalid login or password"
```

For the bundled plugin attributes, see [Lua Policy Plugins](../guides/lua-policy-plugins.md).
