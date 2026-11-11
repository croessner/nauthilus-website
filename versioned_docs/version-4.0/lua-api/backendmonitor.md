---
title: Backend server monitoring
description: Backend server monitoring related functions
keywords: [Lua]
sidebar_position: 3
---
# Backend server monitoring

The `nauthilus_backend` module is available in **subject sources**:

```lua
local nauthilus_backend = require("nauthilus_backend")
```

:::warning Availability in Nauthilus 4
Subject sources run in the Policy VM. It provides the backend-result functions
[`apply_backend_result`](#nauthilus_backendapply_backend_result) and
[`remove_from_backend_result`](#nauthilus_backendremove_from_backend_result), but not the server-selection functions.
A subject source that uses `get_backend_servers`, `select_backend_server`, or `check_backend_connection` is rejected when
the configuration is loaded.

These three functions are documented here because the [Lua test framework](../guides/lua-test-framework.md) still
mocks them and scripts from Nauthilus 3 use them. To select the backend server for the nginx `Auth-Server` and
`Auth-Port` headers in Nauthilus 4, use a native Go subject source that returns `SelectedBackend`; see
[Result types](../developer/go-plugins/api-reference/results.md) and
[Lua runtimes and capabilities](runtimes.md).
:::

## nauthilus\_backend.get\_backend\_servers

Retrieves a list of available backend servers.

:::warning
Not available to subject sources in Nauthilus 4. See the availability note at the top of this page.
:::

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

:::warning
Not available to subject sources in Nauthilus 4. See the availability note at the top of this page.
:::

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

attributes["hostip"] = "10.10.10.10" -- A value computed by the subject source

b:attributes(attributes)
nauthilus_backend.apply_backend_result(b)
```

The result will be available as HTTP-response header **X-Nauthilus-Hostip** and can easily be parsed in a Dovecot Lua backend.

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

:::warning
Not available to subject sources in Nauthilus 4. See the availability note at the top of this page.
:::

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
