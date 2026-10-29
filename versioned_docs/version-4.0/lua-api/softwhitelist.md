---
title: Soft whitelists
description: Soft whitelisting related functions for Nauthilus environment controls
keywords: [Lua]
sidebar_position: 13
---
# Soft whitelisting

Environment controls like **brute\_force**, **relay\_domains** and **rbl** support soft whitelists. You can dynamically adjust
these lists from within Lua.

```lua
local nauthilus_soft_whitelist = require("nauthilus_soft_whitelist")
```

## nauthilus\_soft\_whitelist.soft\_whitelist\_set

Adds or replaces a soft whitelist entry for a specific username, network, and environment control.

### Syntax

```lua
local err = nauthilus_soft_whitelist.soft_whitelist_set(username, network, environment)
```

### Parameters

- `username` (string): The username to whitelist
- `network` (string): A valid network with CIDR notation (e.g., "192.168.0.0/24")
- `environment` (string): The environment control to whitelist for (e.g., "brute_force", "relay_domains", "rbl")

### Returns

- `err` (string): An error message if the operation fails, nil on success

### Example

```lua
local nauthilus_soft_whitelist = require("nauthilus_soft_whitelist")

local username = "testuser"
local network = "192.168.0.0/24"
local environment = "brute_force"

local err = nauthilus_soft_whitelist.soft_whitelist_set(username, network, environment)
if err then
    print("Error:", err)
else
    print("Successfully added whitelist entry")
end
```

## nauthilus\_soft\_whitelist.soft\_whitelist\_get

Retrieves all associated networks for a given username and environment control.

### Syntax

```lua
local networks = nauthilus_soft_whitelist.soft_whitelist_get(username, environment)
```

### Parameters

- `username` (string): The username to look up
- `environment` (string): The environment control to get whitelists for (e.g., "brute_force", "relay_domains", "rbl")

### Returns

- `networks` (table): A Lua table containing all whitelisted networks for the specified username and environment control

### Example

```lua
local nauthilus_soft_whitelist = require("nauthilus_soft_whitelist")

local username = "testuser"
local environment = "brute_force"

local result_table = nauthilus_soft_whitelist.soft_whitelist_get(username, environment)

-- result_table will be { [1] = "192.168.0.0/24" } if that network is whitelisted
for i, network in ipairs(result_table) do
    print("Whitelisted network:", network)
end
```

## nauthilus\_soft\_whitelist.soft\_whitelist\_delete

Removes a network from the whitelist for a given username and environment control.

### Syntax

```lua
nauthilus_soft_whitelist.soft_whitelist_delete(username, network, environment)
```

### Parameters

- `username` (string): The username to modify
- `network` (string): The network to remove from the whitelist
- `environment` (string): The environment control to remove the whitelist from

### Returns

None

### Example

```lua
local nauthilus_soft_whitelist = require("nauthilus_soft_whitelist")

local username = "testuser"
local network = "192.168.0.0/24"
local environment = "brute_force"

nauthilus_soft_whitelist.soft_whitelist_delete(username, network, environment)

-- Will remove the network "192.168.0.0/24" from the user's whitelist
```
