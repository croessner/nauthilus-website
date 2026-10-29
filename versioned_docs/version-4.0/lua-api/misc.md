---
title: Miscellaneous helpers
description: nauthilus_misc Lua module providing utility functions
keywords: [Lua]
sidebar_position: 9
---

# nauthilus_misc

The `nauthilus_misc` module exposes small helper functions for Lua scripts.

```lua
local misc = require("nauthilus_misc")
```

## misc.scoped_ip

Returns a normalized identifier for an IP address according to configured scoping rules.

### Configuration precedence

- for `ctx = "lua_generic"`:
  - `auth.backends.lua.backend.default.ip_scoping_v6_cidr`
  - `auth.backends.lua.backend.default.ip_scoping_v4_cidr`
- for `ctx = "rwp"` and `ctx = "tolerations"`:
  - the brute-force scoping settings under `auth.controls.brute_force.ip_scoping`

### Example configuration

```yaml
auth:
  backends:
    lua:
      backend:
        default:
          ip_scoping_v6_cidr: 64
          ip_scoping_v4_cidr: 24
```

### Example usage

```lua
local misc = require("nauthilus_misc")

local scoped = misc.scoped_ip("lua_generic", request.client_ip)
```

When no CIDR is configured for the chosen context and IP version, the original IP is returned unchanged.
