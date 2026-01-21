---
title: Backend server monitoring
description: Backend server monitoring related functions
keywords: [Lua]
sidebar_position: 3
---
# Backend server monitoring

If the feature **backend\_server\_monitoring** is turned on, the following functions are available in **filters**:

```lua
local nauthilus_backend = require("nauthilus_backend")
```

## nauthilus\_backend.get\_backend\_servers

Retrieves a list of available backend servers.

### Syntax

```lua
local backend_servers = nauthilus_backend.get_backend_servers()
```

### Parameters

None

### Returns

- `backend_servers` (table): A table of backend server objects, each with the following properties:
  - `ip` (string): The IP address of the server
  - `port` (number): The port number of the server
  - `protocol` (string): The protocol used by the server
  - `haproxy_v2` (boolean): Whether the server supports HAProxy protocol v2
  - `tls` (boolean): Whether the server uses TLS

### Example

```lua
local nauthilus_backend = require("nauthilus_backend")

local backend_servers = nauthilus_backend.get_backend_servers()

---@type table
local valid_servers = {}

for _, server in ipairs(backend_servers) do
  -- server.ip
  -- server.port
  -- server.protocol
  -- server.haproxy_v2
  -- server.tls
  -- You may select only HAproxy enabled backends... server.haproxy_v2
  table.insert(valid_servers, server)
end
```

## nauthilus\_backend.select\_backend\_server

Selects a backend server for the Nginx endpoint in NAuthilus.

### Syntax

```lua
nauthilus_backend.select_backend_server(ip, port)
```

### Parameters

- `ip` (string): The IP address of the backend server
- `port` (number): The port number of the backend server

### Returns

None (sets HTTP response headers **Auth-Server** and **Auth-Port**)

### Example

```lua
local nauthilus_backend = require("nauthilus_backend")

-- See nauthilus_backend.get_backend_servers above!
local server = valid_servers[some_number] -- You must define some logic on how to choose a backend server from the list

nauthilus_backend.select_backend_server(server.ip, server.port)
```

## nauthilus\_backend.apply\_backend\_result

Applies backend server information to the result attributes.

### Syntax

```lua
nauthilus_backend.apply_backend_result(backend_result)
```

### Parameters

- `backend_result` (userdata): A backend result object with attributes

### Returns

None

### Example

```lua
local nauthilus_backend = require("nauthilus_backend")

local b = nauthilus_backend_result:new()
local attributes = {}
-- See nauthilus_backend.get_backend_servers above!
local server = valid_servers[some_number] -- You must define some logic on how to choose a backend server from the list

attributes["hostip"] = server.ip
b:attributes(attributes)
nauthilus_backend.apply_backend_result(b)
```

The result will be available as HTTP-response header **X-Nauthilus-Hostip** and can easily be parsed in a Dovecot Lua backend.

This example lacks persistent routing from users to backend servers. But it is a good starting point. Combine it with Redis or SQL databases.

## nauthilus\_backend.remove\_from\_backend\_result

Removes attributes from the final result attributes.

### Syntax

```lua
nauthilus_backend.remove_from_backend_result(attributes)
```

### Parameters

- `attributes` (table): A table of attribute names to remove

### Returns

None

### Example

```lua
local nauthilus_backend = require("nauthilus_backend")

nauthilus_backend.remove_from_backend_result({ "Proxy-Host" })
```

::::note
Removing attributes is always done before adding attributes (from apply\_backend\_result()-calls)
::::

## nauthilus\_backend.check\_backend\_connection

Checks if a connection to a backend server can be established.

### Syntax

```lua
local error = nauthilus_backend.check_backend_connection(server_ip, server_port, is_haproxy_v2, uses_tls)
```

### Parameters

- `server_ip` (string): The IP address of the backend server
- `server_port` (number): The port number of the backend server
- `is_haproxy_v2` (boolean): Whether to use HAProxy protocol v2
- `uses_tls` (boolean): Whether to use TLS

### Returns

- `error` (string): An error message if the connection fails, nil if successful

### Example

```lua
local nauthilus_backend = require("nauthilus_backend")

local server_ip = "10.10.10.10"
local server_port = 993
local is_haproxy_v2 = true
local uses_tls = true

local error = nauthilus_backend.check_backend_connection(server_ip, server_port, is_haproxy_v2, uses_tls)
```

::::warning
Normally you should not do this, as this will open a connection for each client request!
::::