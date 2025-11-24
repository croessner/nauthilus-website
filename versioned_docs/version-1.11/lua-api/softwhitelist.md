---
title: Soft whitelists
description: Soft whitelisting related functions for Nauthilus builtin features
keywords: [Lua]
sidebar_position: 13
---
# Soft whitelisting

Features like **brute\_force**, **relay\_domains** and **rbl** support soft whitelists. You can dynamically adjust
these lists from within Lua.

```lua
local nauthilus_soft_whitelist = require("nauthilus_soft_whitelist")
```

## nauthilus\_soft\_whitelist.soft\_whitelist\_set

Adds or replaces a soft whitelist entry for a specific username, network, and feature.

### Syntax

```lua
local err = nauthilus_soft_whitelist.soft_whitelist_set(username, network, feature)
```

### Parameters

- `username` (string): The username to whitelist
- `network` (string): A valid network with CIDR notation (e.g., "192.168.0.0/24")
- `feature` (string): The feature to whitelist for (e.g., "brute_force", "relay_domains", "rbl")

### Returns

- `err` (string): An error message if the operation fails, nil on success

### Example

```lua
local nauthilus_soft_whitelist = require("nauthilus_soft_whitelist")

local username = "testuser"
local network = "192.168.0.0/24"
local feature = "brute_force"

local err = nauthilus_soft_whitelist.soft_whitelist_set(username, network, feature)
if err then
    print("Error:", err)
else
    print("Successfully added whitelist entry")
end
```

## nauthilus\_soft\_whitelist.soft\_whitelist\_get

Retrieves all associated networks for a given username and feature.

### Syntax

```lua
local networks = nauthilus_soft_whitelist.soft_whitelist_get(username, feature)
```

### Parameters

- `username` (string): The username to look up
- `feature` (string): The feature to get whitelists for (e.g., "brute_force", "relay_domains", "rbl")

### Returns

- `networks` (table): A Lua table containing all whitelisted networks for the specified username and feature

### Example

```lua
local nauthilus_soft_whitelist = require("nauthilus_soft_whitelist")

local username = "testuser"
local feature = "brute_force"

local result_table = nauthilus_soft_whitelist.soft_whitelist_get(username, feature)

-- result_table will be { [1] = "192.168.0.0/24" } if that network is whitelisted
for i, network in ipairs(result_table) do
    print("Whitelisted network:", network)
end
```

## nauthilus\_soft\_whitelist.soft\_whitelist\_delete

Removes a network from the whitelist for a given username and feature.

### Syntax

```lua
nauthilus_soft_whitelist.soft_whitelist_delete(username, network, feature)
```

### Parameters

- `username` (string): The username to modify
- `network` (string): The network to remove from the whitelist
- `feature` (string): The feature to remove the whitelist from

### Returns

None

### Example

```lua
local nauthilus_soft_whitelist = require("nauthilus_soft_whitelist")

local username = "testuser"
local network = "192.168.0.0/24"
local feature = "brute_force"

nauthilus_soft_whitelist.soft_whitelist_delete(username, network, feature)

-- Will remove the network "192.168.0.0/24" from the user's whitelist
```