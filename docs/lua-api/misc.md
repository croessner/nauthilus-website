---
title: Miscellaneous helpers
description: nauthilus_misc Lua module providing utility functions
keywords: [Lua]
sidebar_position: 9
---

# nauthilus_misc

The `nauthilus_misc` module exposes small helper functions for Lua scripts. In v1.10.0 a new function was added to provide IP scoping consistent with the Go backend.

```lua
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

## Scoping variables (configuration)

The behavior of misc.scoped_ip is controlled by configuration:

- lua.config.ip_scoping_v6_cidr: IPv6 CIDR to aggregate privacy addresses (0 disables)
- lua.config.ip_scoping_v4_cidr: IPv4 CIDR to aggregate NAT pools (0 disables)

Example configuration (YAML):

```yaml
lua:
  config:
    ip_scoping_v6_cidr: 64
    ip_scoping_v4_cidr: 24
```

Notes:
- Contexts rwp and tolerations follow the brute-force module’s own scoping settings.
- When a CIDR is 0 or unset for the IP version/context, misc.scoped_ip returns the original IP.

See also:
- Configuration → Database Backends → Lua Backend (ip_scoping_* options)
- Configuration → Reference → Lua scoped IP controls

## misc.get_country_name

Retrieves the full English name of a country based on its ISO 3166-1 alpha-2 code.

### Syntax

```lua
local country_name, err = misc.get_country_name(iso_code)
```

### Parameters

- `iso_code` (string, required): The two-letter country code (e.g., "DE", "US").

### Returns

- `country_name` (string): The full name of the country, or "Unknown" if not found.
- `err` (nil): Always returns nil (errors result in "Unknown").

---

## misc.wait_random

Causes the current execution to sleep for a random duration within a specified range. This is useful for implementing artificial delays to thwart timing attacks or rate-limit certain operations.

### Syntax

```lua
local actual_wait, err = misc.wait_random(min_ms, max_ms)
```

### Parameters

- `min_ms` (number, required): Minimum wait time in milliseconds.
- `max_ms` (number, required): Maximum wait time in milliseconds.

### Returns

- `actual_wait` (number): The actual number of milliseconds slept.
- `err` (string/nil): An error message if the range is invalid, otherwise nil.

---

## misc.generate_password_hash

Generates a short, non-cryptographic hash of a password string. This hash is primarily used for the `PW_HIST` feature in Redis to recognize repeating wrong passwords without storing the actual password or a heavy cryptographic hash in the transient cache.

### Syntax

```lua
local hash, err = misc.generate_password_hash(password)
```

### Parameters

- `password` (string, required): The password to hash.

### Returns

- `hash` (string): A lowercase 8-character hexadecimal string representing the hash.
- `err` (nil): Always returns nil.
