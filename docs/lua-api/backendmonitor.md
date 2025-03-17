---
title: Backend server monitoring
description: Backend server monitoring related functions
keywords: [Lua]
sidebar_position: 3
---

<!-- TOC -->
* [Backend server monitoring](#backend-server-monitoring)
  * [nauthilus\_backend.get\_backend\_servers](#nauthilus_backendget_backend_servers)
  * [nauthilus\_backend.select\_backend\_server and nauthilus\_backend.apply\_backend\_result](#nauthilus_backendselect_backend_server-and-nauthilus_backendapply_backend_result)
  * [nauthilus\_backend.remove\_from\_backend\_result](#nauthilus_backendremove_from_backend_result)
  * [nauthilus\_backend.check\_backend\_connection](#nauthilus_backendcheck_backend_connection)
<!-- TOC -->

# Backend server monitoring

If the feature **backend\_server\_monitorin** is turned on, the following functions are available in **filters**:

```lua
dynamic_loader("nauthilus_backend")
local nauthilus_backend = require("nauthilus_backend")
```

## nauthilus\_backend.get\_backend\_servers

This function returns a **backend\_server** UserData object.

Usage example:

```lua
dynamic_loader("nauthilus_backend")
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

## nauthilus\_backend.select\_backend\_server and nauthilus\_backend.apply\_backend\_result

If you use the Nginx endpoint in NAuthilus, you can select a backend server with this function:

```lua
dynamic_loader("nauthilus_backend")
local nauthilus_backend = require("nauthilus_backend")

-- See nauthilus_backend.get_backend_servers above!
local server = valid_servers[some_number] -- You must define some logic on how to chose a backend server from the list

nauthilus_backend.select_backend_server(server.ip, server.port)
```

This will return the appropriate HTTP response header **Auth-Server** and **Auth-Port**

If you use a different endpoint, you may add the result to the attributes. In case of Dovecot this might look like this (untested):

```lua
dynamic_loader("nauthilus_backend")
local nauthilus_backend = require("nauthilus_backend")

local b = nauthilus_backend_result:new()
local attributes = {}
-- See nauthilus_backend.get_backend_servers above!
local server = valid_servers[some_number] -- You must define some logic on how to chose a backend server from the list

attributes["hostip"] = server.ip
b:attributes(attributes)
nauthilus_backend.apply_backend_result(b)
```

The result will be available as HTTP-response header **X-Nauthilus-Hostip** and can easily be parsed in a Dovecot Lua backend.

This example lacks persistent routing from users to backend servers. But it is a good starting point. Combine it with Redis or
SQL databases...

## nauthilus\_backend.remove\_from\_backend\_result

Remove attributes from the final result attributes

```lua
dynamic_loader("nauthilus_backend")
local nauthilus_backend = require("nauthilus_backend")

nauthilus_backend.remove_from_backend_result({ "Proxy-Host" })
```
:::note
Removeing attributes is always done before adding attributes (from apply\_backend\_result()-calls)
:::

This removes the Proxy-Host "header" attribute from the result.

## nauthilus\_backend.check\_backend\_connection

Before using a backend server, you could double-check with the following function:

```lua
dynamic_loader("nauthilus_backend")
local nauthilus_backend = require("nauthilus_backend")

local server_ip = "10.10.10.10"
local server_port = 993
local is_haproxy_v2 = true
local uses_tls = true

local error = nauthilus_backend.check_backend_connection(server_ip, server_port, is_haproxy_v2, uses_tls)
```
If anything went fine, **error** equals nil, else it stores a string with an error message.

:::warning
Normally you should not do this, as this will open a connection for each client  request!
:::
