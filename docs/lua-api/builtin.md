---
title: Builtin
description: Logging and status messages
keywords: [Lua]
sidebar_position: 2
---
# Builtin Lua functions

## nauthilus\_builtin.status\_message\_set

Sets a custom status message to be returned when a client request is rejected.

### Syntax

```lua
nauthilus_builtin.status_message_set(message)
```

### Parameters

- `message` (string): The custom rejection message to display to the client

### Returns

None

### Example

```lua
nauthilus_builtin.status_message_set("Authentication failed: Too many login attempts")
```

## nauthilus\_builtin.custom\_log\_add

Adds key-value pairs to the result log.

### Syntax

```lua
nauthilus_builtin.custom_log_add(key, value)
```

### Parameters

- `key` (string): The name of the log field
- `value` (string/number/boolean): The value to log (other types will be replaced with "UNSUPPORTED")

### Returns

None

### Example

```lua
nauthilus_builtin.custom_log_add("user_id", 12345)
nauthilus_builtin.custom_log_add("login_source", "mobile_app")
```

::::note
In **features**, **backend**, and **filters**, logs are added to the final result log line. In **actions**, logging is appended to the **action** log line because actions may run asynchronously after the main request has closed.

You can call this function multiple times, even with the same key-value pairs. Logs cannot be removed once set.
::::