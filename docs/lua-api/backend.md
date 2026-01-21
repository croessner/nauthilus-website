---
title: Backend
description: Backend related functions (mainly for Filters)
keywords: [Lua]
sidebar_position: 8
---
# Backend

The `nauthilus_backend` module provides functions to interact with authentication backends and manipulate their results. This is primarily used within Lua **filters**.

```lua
local nauthilus_backend = require("nauthilus_backend")
```

---

# Functions

## nauthilus_backend.get_backend_servers

Returns a list of all configured backend servers that have been monitored.

### Syntax

```lua
local servers = nauthilus_backend.get_backend_servers()
```

### Returns

- `servers` (table): A list of server objects (userdata). Each object has the following properties:
  - `protocol` (string)
  - `host` (string)
  - `port` (number)
  - `request_uri` (string)
  - `test_username` (string)
  - `test_password` (string)
  - `haproxy_v2` (boolean)
  - `tls` (boolean)
  - `tls_skip_verify` (boolean)
  - `deep_check` (boolean)

### Example

```lua
local servers = nauthilus_backend.get_backend_servers()
for i, server in ipairs(servers) do
    nauthilus_util.log_debug("Found server: " .. server.host .. ":" .. tostring(server.port))
end
```

---

## nauthilus_backend.select_backend_server

Assigns a specific backend server address and port to be used for the current request. This is useful for load balancing or proxying (e.g., Dovecot).

### Syntax

```lua
nauthilus_backend.select_backend_server(host, port)
```

### Parameters

- `host` (string): The hostname or IP address of the backend server.
- `port` (number): The port number of the backend server.

### Example

```lua
nauthilus_backend.select_backend_server("10.0.0.50", 993)
```

---

## nauthilus_backend.check_backend_connection

Checks if a connection to a backend server can be established.

### Syntax

```lua
local ok, err = nauthilus_backend.check_backend_connection(protocol, host, port, tls, skip_verify, haproxy_v2)
```

### Parameters

- `protocol` (string): e.g., "imap", "smtp", "http"
- `host` (string): Target host
- `port` (number): Target port
- `tls` (boolean): Use TLS
- `skip_verify` (boolean): Skip TLS certificate verification
- `haproxy_v2` (boolean): Use HAProxy PROXY protocol v2

### Returns

- `ok` (boolean): `true` if connection succeeded
- `err` (string): Error message if connection failed

---

## nauthilus_backend.apply_backend_result

Merges attributes from a `backend_result` object into the current request's result. Attributes in the object will overwrite existing ones if they share the same key.

### Syntax

```lua
nauthilus_backend.apply_backend_result(backend_result_object)
```

### Parameters

- `backend_result_object` (userdata): An object created via `nauthilus_backend_result.new()`.

### Example

```lua
local b = nauthilus_backend_result.new()
b:attributes({ custom_field = "new_value" })
nauthilus_backend.apply_backend_result(b)
```

---

## nauthilus_backend.remove_from_backend_result

Specifies a list of attributes that should be removed from the final authentication result.

### Syntax

```lua
nauthilus_backend.remove_from_backend_result(attribute_names)
```

### Parameters

- `attribute_names` (table): A list of strings representing the keys to remove.

### Example

```lua
nauthilus_backend.remove_from_backend_result({"temp_attribute", "internal_id"})
```
