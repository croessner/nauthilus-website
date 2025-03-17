---
title: PSnet
description: TCP connection counting related functions
keywords: [Lua]
sidebar_position: 11
---

<!-- TOC -->
* [PS net](#ps-net)
  * [nauthilus\_psnet.register\_connection\_target](#nauthilus_psnetregister_connection_target)
  * [nauthilus\_psnet.get\_connection\_target](#nauthilus_psnetget_connection_target)
<!-- TOC -->

# PS net

Register connections and count established connections.

```lua
dynamic_loader("nauthilus_psnet")
local nauthilus_misc = require("nauthilus_psnet")
```

## nauthilus\_psnet.register\_connection\_target

Registers a target, for which Nauthilus will count established connections. It can count connection originating from
Nauthilus or incoming connections.

| parameter   | description                                                               |
|-------------|---------------------------------------------------------------------------|
| target      | Hostname:port or IP-address:port tuple                                    |
| direction   | **remote** means the target is outside, local** means the target is local |
| description | Some description about this target.                                       |

```lua
local target = "api.pwnedpasswords.com:443"
local direction = "remote"
local description = "Some meaningful description"

nauthilus_psnet.register_connection_target(target, direction, description)
```
:::tip
You can register targtes in an init Lua script
:::

## nauthilus\_psnet.get\_connection\_target

Get the current number of established connections for a target.

```lua
local target = "api.pwnedpasswords.com:443"

local count, err = nauthilus_psnet.get_connections_target(target)
```

