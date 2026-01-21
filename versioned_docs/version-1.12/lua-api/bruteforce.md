---
title: Brute Force
description: Brute force prevention and toleration functions
keywords: [Lua]
sidebar_position: 15
---
# Brute Force

The `nauthilus_brute_force` module allows Lua scripts to interact with the brute force protection system, manage custom tolerations, and check if an IP is currently blocked.

```lua
local nauthilus_brute_force = require("nauthilus_brute_force")
```

---

# Functions

## nauthilus_brute_force.set_custom_tolerations

Sets multiple custom toleration configurations from a list of tables.

### Syntax

```lua
local ok, err = nauthilus_brute_force.set_custom_tolerations(tolerations)
```

### Parameters

- `tolerations` (table): A list (array) of toleration tables. Each table must contain:
  - `ip_address` (string): The IP or CIDR.
  - `tolerate_percent` (number): The percentage of failed requests to tolerate.
  - `tolerate_ttl` (string): The duration (e.g., "24h", "15m").

### Returns

- `ok` (string/nil): "OK" if successful.
- `err` (string/nil): Error message if failed.

---

## nauthilus_brute_force.set_custom_toleration

Sets a single custom toleration configuration.

### Syntax

```lua
local ok, err = nauthilus_brute_force.set_custom_toleration(toleration)
```

### Parameters

- `toleration` (table): A table containing:
  - `ip_address` (string)
  - `tolerate_percent` (number)
  - `tolerate_ttl` (string)

### Returns

- `ok` (string/nil): "OK" if successful.
- `err` (string/nil): Error message if failed.

---

## nauthilus_brute_force.delete_custom_toleration

Removes a custom toleration for a specific IP address.

### Syntax

```lua
local ok, err = nauthilus_brute_force.delete_custom_toleration(ip)
```

### Parameters

- `ip` (string): The IP address to remove.

### Returns

- `ok` (string/nil): "OK" if successful.

---

## nauthilus_brute_force.get_custom_tolerations

Retrieves all currently active custom tolerations.

### Syntax

```lua
local list, err = nauthilus_brute_force.get_custom_tolerations()
```

### Returns

- `list` (table): A list of toleration tables.
- `err` (string/nil): Error message.

---

## nauthilus_brute_force.get_tolerate_map

Retrieves the current authentication statistics (counters) for a specific IP address from the toleration system.

### Syntax

```lua
local counters, err = nauthilus_brute_force.get_tolerate_map(ip)
```

### Parameters

- `ip` (string): The IP address to check.

### Returns

- `counters` (table): A table mapping labels (e.g., "total", "failed") to their numeric counts.
- `err` (string/nil): Error message.

---

## nauthilus_brute_force.is_ip_address_blocked

Checks if an IP address is currently blocked by the brute force protection system.

### Syntax

```lua
local buckets, err = nauthilus_brute_force.is_ip_address_blocked(ip)
```

### Parameters

- `ip` (string): The IP address to check.

### Returns

- `buckets` (table/nil): A list of bucket names that are causing the block, or `nil` if not blocked.
- `err` (string/nil): Error message.

### Example

```lua
local buckets = nauthilus_brute_force.is_ip_address_blocked(request.client_ip)
if buckets then
    nauthilus_util.log_warn("IP " .. request.client_ip .. " is blocked by: " .. table.concat(buckets, ", "))
end
```
