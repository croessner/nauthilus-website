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
dynamic_loader("nauthilus_soft_whitelist")
local nauthilus_soft_whitelist = require("nauthilus_soft_whitelist")
```

## nauthilus\_soft\_whitelist.soft\_whitelist\_set

Add (or replace) an entry like this:

```lua
local username = "testuser"
local network = "192.168.0.0/24"
local feature = "brute_force"

local err = nauthilus_soft_whitelist.soft_whitelist_set(username, network, feature)
```

Network must be a valid network with a CIDR-mask, even for a single address!

The "err" variable will be set to nil on success. If you specify a wrong feature, "err" will contain a message about this issue.

## nauthilus\_soft\_whitelist.soft\_whitelist\_get

This method retrieves all associsated networks for a given username and feature.

```lua
local username = "testuser"
local feature = "brute_force"

local result_table = nauthilus_soft_whitelist.soft_whitelist_get(username, feature)

-- result_table will be { [1] = "192.168.0.0/24" } for the example above
```

## nauthilus\_soft\_whitelist.soft\_whitelist\_delete

Remove a network for a given username and feature.

```lua
local username = "testuser"
local network = "192.168.0.0/24"
local feature = "brute_force"

nauthilus_soft_whitelist.soft_whitelist_delete(username, network, feature)

-- Will remove the network "192.168.0.0/24" from the users' whitelist
```
