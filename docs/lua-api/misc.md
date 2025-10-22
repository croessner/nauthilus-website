---
title: Miscellaneous helpers
description: nauthilus_misc Lua module providing utility functions
keywords: [Lua]
sidebar_position: 9
---

# nauthilus_misc

The `nauthilus_misc` module exposes small helper functions for Lua scripts. In v1.10.0 a new function was added to provide IP scoping consistent with the Go backend.

```lua
dynamic_loader("nauthilus_misc")
local misc = require("nauthilus_misc")
```

## misc.scoped_ip

Returns a normalized identifier for an IP address according to configured scoping rules. This ensures consistent behavior across features and with the built‑in brute‑force components.

### Syntax

```lua
local scoped = misc.scoped_ip(ctx, ip)
-- or with default context:
local scoped = misc.scoped_ip(ip)
```

### Parameters

- `ctx` (string, optional): Scoping context. One of:
  - `"lua_generic"` (default): For general feature/metrics use.
  - `"rwp"`: Repeating‑Wrong‑Password context (matches brute‑force RWP scoping).
  - `"tolerations"`: Tolerations context (matches brute‑force tolerations scoping).
- `ip` (string, required): IPv4 or IPv6 address.

### Returns

- A string identifier to use for deduplication (can be the original IP or a network like `2001:db8::/64` or `192.0.2.0/24`), depending on configuration.

### Configuration precedence

- For `ctx = "lua_generic"`:
  - Uses `lua.config.ip_scoping_v6_cidr` and `lua.config.ip_scoping_v4_cidr`.
- For `ctx = "rwp"` and `ctx = "tolerations"`:
  - Uses the existing brute‑force `ip_scoping` settings.
- If no CIDR is configured for the IP version/context, the function returns the original IP.

### Examples

```lua
local misc = require("nauthilus_misc")

-- Generic scoping for metrics/dedup
local id = misc.scoped_ip("lua_generic", request.client_ip)
nauthilus_redis.redis_pfadd(client, "ntc:hll:acct:" .. request.username .. ":ips:86400", id)

-- RWP context (matches brute‑force)
local id2 = misc.scoped_ip("rwp", request.client_ip)
```

### Version

- Added in v1.10.0.

## Other helpers

- `get_country_name(code)` → Country name for ISO code (requires countries DB)
- `wait_random(min_ms, max_ms)` → Sleep for a random amount of milliseconds
- `generate_password_hash(password)` → Redis‑compatible short hash used by Nauthilus
