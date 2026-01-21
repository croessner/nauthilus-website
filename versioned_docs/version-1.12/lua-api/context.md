---
title: Context
description: Shared Lua context between features, backend, filters and actions
keywords: [Lua]
sidebar_position: 4
---
# Context

:::note Concurrency since 1.8.9
Starting with Nauthilus v1.8.9, Lua features and filters execute in parallel. The shared request context remains available across scripts, but there is no deterministic order of reads/writes between scripts. Prefer idempotent updates or namespaced keys to avoid conflicts, and do not rely on one feature running before another.
:::

```lua
local nauthilus_context = require("nauthilus_context")
```

## nauthilus\_context.context\_set

Adds a value to the shared Lua context.

### Syntax

```lua
nauthilus_context.context_set(key, value)
```

### Parameters

- `key` (string): The key to store the value under
- `value` (string/number/boolean/table): The value to store (cannot be a function)

### Returns

None

### Example

```lua
local nauthilus_context = require("nauthilus_context")

nauthilus_context.context_set("user_id", 12345)
```

## nauthilus\_context.context\_get

Retrieves a value from the shared Lua context.

### Syntax

```lua
local value = nauthilus_context.context_get(key)
```

### Parameters

- `key` (string): The key to retrieve the value for

### Returns

- `value` (any): The stored value, or nil if the key doesn't exist

### Example

```lua
local nauthilus_context = require("nauthilus_context")

local user_id = nauthilus_context.context_get("user_id")
```

## nauthilus\_context.context\_delete

Deletes a key/value pair from the shared Lua context.

### Syntax

```lua
nauthilus_context.context_delete(key)
```

### Parameters

- `key` (string): The key to delete

### Returns

None

### Example

```lua
local nauthilus_context = require("nauthilus_context")

nauthilus_context.context_delete("user_id")
```
