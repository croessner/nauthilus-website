---
title: Utilities
description: Common utility functions
keywords: [Lua]
sidebar_position: 20
---
# Utilities

The `nauthilus_util` module provides several helper functions for Lua scripts in Nauthilus.

```lua
local nauthilus_util = require("nauthilus_util")
```

---

# Functions

## nauthilus_util.getenv

Returns the value of an environment variable, cached via `nauthilus_cache`.

### Syntax

```lua
local val = nauthilus_util.getenv(name, default)
```

### Parameters

- `name` (string) - The name of the environment variable.
- `default` (string) - A default value if the environment variable is not set.

### Returns

- `val` (string) - The value of the environment variable or the default value.

### Example

```lua
local api_url = nauthilus_util.getenv("API_URL", "http://localhost:8080")
```

---

## nauthilus_util.exists_in_table

Iterates over a flat Lua table (list) and checks if a string was found in the values.

### Syntax

```lua
local found = nauthilus_util.exists_in_table(tbl, element)
```

### Parameters

- `tbl` (table) - The table to search in.
- `element` (string) - The string to search for.

### Returns

- `found` (boolean) - `true` if found, `false` otherwise.

### Example

```lua
local roles = {"admin", "user", "guest"}
if nauthilus_util.exists_in_table(roles, "admin") then
    -- User is an admin
end
```

---

## nauthilus_util.get_current_timestamp

Creates a timestamp string valid for logging purposes. It respects the `TZ` environment variable.

### Syntax

```lua
local ts = nauthilus_util.get_current_timestamp()
```

### Returns

- `ts` (string) - A formatted timestamp string (e.g., "2006-01-02T15:04:05 -07:00").

### Example

```lua
local timestamp = nauthilus_util.get_current_timestamp()
-- result: "2024-01-21T15:00:00 +01:00"
```

---

## nauthilus_util.table_length

Calculates the length of a Lua table.

### Syntax

```lua
local len = nauthilus_util.table_length(tbl)
```

### Parameters

- `tbl` (table) - The table to count.

### Returns

- `len` (number) - The number of elements in the table.

### Example

```lua
local my_table = {a = 1, b = 2, c = 3}
local size = nauthilus_util.table_length(my_table)
-- size: 3
```

---

## nauthilus_util.if_error_raise

Checks if an error was set and calls the Lua `error` function to exit script execution. It ignores "redis: nil" or "OK" messages.

### Syntax

```lua
nauthilus_util.if_error_raise(err)
```

### Parameters

- `err` (string) - The error message to check.

### Example

```lua
local result, err = nauthilus_redis.redis_get("handle", "my_key")
nauthilus_util.if_error_raise(err)
```

---

## nauthilus_util.is_table

Returns `true` if the given parameter is of type table.

### Syntax

```lua
local result = nauthilus_util.is_table(object)
```

### Parameters

- `object` (any) - The object to check.

### Example

```lua
local data = {key = "value"}
if nauthilus_util.is_table(data) then
    -- It is a table
end
```

---

## nauthilus_util.is_string

Returns `true` if the given parameter is of type string.

### Syntax

```lua
local result = nauthilus_util.is_string(object)
```

### Parameters

- `object` (any) - The object to check.

### Example

```lua
if nauthilus_util.is_string("hello") then
    -- It is a string
end
```

---

## nauthilus_util.is_number

Returns `true` if the given parameter is of type number.

### Syntax

```lua
local result = nauthilus_util.is_number(object)
```

### Parameters

- `object` (any) - The object to check.

### Example

```lua
if nauthilus_util.is_number(123) then
    -- It is a number
end
```

---

## nauthilus_util.get_redis_key

Returns a Redis key with the prefix from the request, if available.

### Syntax

```lua
local key = nauthilus_util.get_redis_key(request, key)
```

### Parameters

- `request` (table) - The Nauthilus request object.
- `key` (string) - The base Redis key.

### Returns

- `key` (string) - The prefixed Redis key.

### Example

```lua
local key = nauthilus_util.get_redis_key(request, "my_data")
-- result: "nt_:my_data" (if prefix is "nt_")
```

---

## nauthilus_util.toboolean

Converts a string value into a boolean.

### Syntax

```lua
local bool = nauthilus_util.toboolean(str)
```

### Parameters

- `str` (string) - The string to convert.

### Returns

- `bool` (boolean) - `false` if the lower-cased string is "false", "0", or empty. `true` otherwise.

### Example

```lua
local is_enabled = nauthilus_util.toboolean("true") -- true
local is_disabled = nauthilus_util.toboolean("0") -- false
```

---

## nauthilus_util.generate_random_string

Creates a random string of a specified length.

### Syntax

```lua
local str = nauthilus_util.generate_random_string(length)
```

### Parameters

- `length` (number) - The desired length of the string.

### Returns

- `str` (string) - The random alphanumeric string.

### Example

```lua
local nonce = nauthilus_util.generate_random_string(16)
```

---

## nauthilus_util.is_routable_ip

Checks if an IP address is routable on the internet.

### Syntax

```lua
local routable = nauthilus_util.is_routable_ip(ip)
```

### Parameters

- `ip` (string) - The IP address to check.

### Returns

- `routable` (boolean) - `true` if routable, `false` for private or reserved ranges.

### Example

```lua
local ok = nauthilus_util.is_routable_ip("8.8.8.8") -- true
local internal = nauthilus_util.is_routable_ip("192.168.1.1") -- false
```

---

## Logging Functions

The following functions log messages at different levels. They respect the configured log level and format.

### Syntax

```lua
nauthilus_util.log_debug(logging, result)
nauthilus_util.log_info(logging, result)
nauthilus_util.log_notice(logging, result)
nauthilus_util.log_warn(logging, result)
nauthilus_util.log_error(logging, result, err_string)
```

### Parameters

- `logging` (table) - The logging configuration object.
- `result` (table) - A table of key/value pairs to log.
- `err_string` (string) - (Only for `log_error`) An additional error message.

### Example

```lua
local log_data = {
    user = request.username,
    action = "login",
    status = "success"
}
nauthilus_util.log_info(request.logging, log_data)
```
