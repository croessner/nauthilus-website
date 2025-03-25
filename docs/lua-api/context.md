---
title: Context
description: Shared Lua context between features, backend, filters and actions
keywords: [Lua]
sidebar_position: 4
---
# Context

```lua
dynamic_loader("nauthilus_context")
local nauthilus_context = require("nauthilus_context")
```

## nauthilus\_context.context\_set
Add a value to the shared Lua context. Values can be strings, numbers, booleans and tables. You can not add functions here.

```lua
dynamic_loader("nauthilus_context")
local nauthilus_context = require("nauthilus_context")

nauthilus_context.context_set("key", value)
```

Get a Lua context value:

## nauthilus\_context.context\_get

```lua
dynamic_loader("nauthilus_context")
local nauthilus_context = require("nauthilus_context")

local value = nauthilus_context.context_get("key")
```

If there is no result, nil is returned.

## nauthilus\_context.context\_delete

To delete a key/value pair from the Lua context, use the following function:

```lua
dynamic_loader("nauthilus_context")
local nauthilus_context = require("nauthilus_context")

nauthilus_context.context_delete("key")
```
