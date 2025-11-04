---
title: Cache
description: Process-wide in-memory cache for Lua (store data across requests)
keywords: [Lua, Cache]
sidebar_position: 13
---
# Cache

Available since Nauthilus version 1.8.9.

The `nauthilus_cache` module provides a process-wide in-memory cache that can be accessed from any Lua script
(feature, backend, filter, action). Use it to store and reuse data across requests, aggregate values for batched
processing, or implement simple counters. Entries are thread-safe and can optionally expire via TTL.

```lua
dynamic_loader("nauthilus_cache")
local nauthilus_cache = require("nauthilus_cache")
```

Notes
- The cache is in-process and shared across all Lua requests in the same Nauthilus instance.
- Values are stored as simple Lua types or tables (numbers, strings, booleans, tables). Functions are not supported.
- Optional TTL can be provided per entry (in seconds). A TTL of 0 or nil means "no expiry".
- There is a background janitor cleaning up expired entries, plus lazy cleanup on read.

---

# Functions

## nauthilus_cache.cache_set

Stores a value under a key with optional TTL (in seconds).

### Syntax

```lua
-- ttl_seconds is optional (nil or 0 = no expiry)
local result, error = nauthilus_cache.cache_set(key, value, ttl_seconds)
```

### Parameters

- `key` (string): Cache key
- `value` (any table/primitive): Value to store (string/number/boolean/table)
- `ttl_seconds` (number, optional): Lifetime in seconds. `nil` or `0` means no expiration

### Returns

- `result` (string): "OK" on success
- `error` (nil|string): Currently nil on success; reserved for future error use

### Example

```lua
dynamic_loader("nauthilus_cache")
local cache = require("nauthilus_cache")

cache.cache_set("greeting", "hello", 60)   -- expires after 60s
cache.cache_set("config", { retry = 3 })    -- no expiry
```

---

## nauthilus_cache.cache_get

Retrieves a stored value if present and not expired.

### Syntax

```lua
local value = nauthilus_cache.cache_get(key)
```

### Parameters

- `key` (string): Cache key

### Returns

- `value` (any|nil): The stored value, or `nil` if not present or expired

### Example

```lua
local v = cache.cache_get("greeting")
if v then
  -- use value
end
```

---

## nauthilus_cache.cache_delete

Deletes a key from the cache.

### Syntax

```lua
local removed = nauthilus_cache.cache_delete(key)
```

### Parameters

- `key` (string): Cache key to delete

### Returns

- `removed` (boolean): `true` if the key existed and was removed; otherwise `false`

### Example

```lua
local ok = cache.cache_delete("greeting")
```

---

## nauthilus_cache.cache_exists

Checks whether a non-expired entry exists for the key.

### Syntax

```lua
local present = nauthilus_cache.cache_exists(key)
```

### Parameters

- `key` (string): Cache key

### Returns

- `present` (boolean): `true` if present and not expired; otherwise `false`

---

## nauthilus_cache.cache_update

Atomically updates the value at a key by calling your provided Lua function with the current value.
The function must be synchronous (no yields). The return value of your function becomes the new cached value.

### Syntax

```lua
local new_value = nauthilus_cache.cache_update(key, updater_fn)
```

### Parameters

- `key` (string): Cache key
- `updater_fn` (function): Called as `updater_fn(old_value)` and must return the new value to store

### Returns

- `new_value` (any): The value returned by `updater_fn`, after storing it

### Example

```lua
-- Increment a counter
local n = nauthilus_cache.cache_update("login_attempts", function(old)
  old = old or 0
  return old + 1
end)
```

---

## nauthilus_cache.cache_keys

Returns a list (array table) of all non-expired keys.

### Syntax

```lua
local keys = nauthilus_cache.cache_keys()
```

### Returns

- `keys` (table): Array of strings

---

## nauthilus_cache.cache_size

Returns the number of non-expired entries in the cache.

### Syntax

```lua
local n = nauthilus_cache.cache_size()
```

### Returns

- `n` (number): Count of current entries

---

## nauthilus_cache.cache_flush

Removes all entries from the cache.

### Syntax

```lua
nauthilus_cache.cache_flush()
```

### Returns

None

---

## nauthilus_cache.cache_push

Appends a value to a list stored at `key`. If the key does not exist, a new list is created. If the key holds a
non-list value, it is promoted to a list containing the previous value followed by the new one.

### Syntax

```lua
local new_length = nauthilus_cache.cache_push(key, value)
```

### Parameters

- `key` (string): Cache key
- `value` (any): Value to append

### Returns

- `new_length` (number): The new length of the list

### Example

```lua
nauthilus_cache.cache_push("failed_logins", { ts = os.time(), user = request.username or "n/a" })
```

---

## nauthilus_cache.cache_pop_all

Returns the entire list at `key` and clears it. If the key doesn't exist, returns an empty list. If the key holds a
non-list value, returns a list with that single value and removes the key.

### Syntax

```lua
local list = nauthilus_cache.cache_pop_all(key)
```

### Parameters

- `key` (string): Cache key

### Returns

- `list` (table): Array table of values

### Example (Batch Aggregation)

```lua
-- During requests (collect items)
nauthilus_cache.cache_push("failed_logins", {
  ts = os.time(),
  user = request.username or "n/a",
  ip = request.client_ip or "n/a",
})

-- Later (post-action or scheduled job)
local batch = nauthilus_cache.cache_pop_all("failed_logins")
if #batch > 0 then
  -- process batch
end
```

---

# Remarks

- Scope: The cache is per process. If you run multiple Nauthilus instances, each has its own cache.
- TTL: Expired entries are evicted lazily on access and periodically by a background janitor.
- Types: Complex Lua tables are stored and returned as tables. Functions and userdata are not supported.
- Performance: Access is thread-safe; prefer small values and aggregate regularly for large batches.
