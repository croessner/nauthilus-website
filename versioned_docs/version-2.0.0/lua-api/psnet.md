---
title: PSnet
description: TCP connection counting related functions
keywords: [Lua]
sidebar_position: 11
---
# PS net

Register connections and count established connections.

```lua
local nauthilus_psnet = require("nauthilus_psnet")
```

## nauthilus\_psnet.register\_connection\_target

Registers a target for which Nauthilus will count established connections.

### Syntax

```lua
nauthilus_psnet.register_connection_target(target, direction, description)
```

### Parameters

- `target` (string): Hostname:port or IP-address:port tuple
- `direction` (string): Connection direction
  - **remote**: The target is outside of Nauthilus
  - **local**: The target is local to Nauthilus
- `description` (string): A description about this target

### Returns

None

### Example

```lua
local nauthilus_psnet = require("nauthilus_psnet")

local target = "api.pwnedpasswords.com:443"
local direction = "remote"
local description = "Some meaningful description"

nauthilus_psnet.register_connection_target(target, direction, description)
```

::::tip
You can register targets in an init Lua script
::::

## nauthilus\_psnet.get\_connection\_target

Gets the current number of established connections for a target.

### Syntax

```lua
local count, err = nauthilus_psnet.get_connections_target(target)
```

### Parameters

- `target` (string): Hostname:port or IP-address:port tuple

### Returns

- `count` (number): The number of established connections
- `err` (string): An error message if the operation fails

### Example

```lua
local nauthilus_psnet = require("nauthilus_psnet")

local target = "api.pwnedpasswords.com:443"

local count, err = nauthilus_psnet.get_connections_target(target)
if err then
    print("Error:", err)
else
    print("Current connections:", count)
end
```