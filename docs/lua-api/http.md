---
title: HTTP
description: HTTP request functions to deal with headers and body
keywords: [Lua]
sidebar_position: 5
---

<!-- TOC -->
* [HTTP request](#http-request)
  * [nauthilus\_http.get\_all\_http\_request\_headers](#nauthilus_httpget_all_http_request_headers)
  * [nauthilus\_http\_request.get\_http\_request\_header](#nauthilus_http_requestget_http_request_header)
  * [nauthilus\_http\_request.get\_http\_request\_body](#nauthilus_http_requestget_http_request_body)
<!-- TOC -->

# HTTP request

```lua
dynamic_loader("nauthilus_http_request")
local nauthilus_http_request = require("nauthilus_http_request")
```
## nauthilus\_http.get\_all\_http\_request\_headers

It is possible to get the full set of HTTP request headers from a connecting service in Lua with the following function:

```lua
dynamic_loader("nauthilus_http_request")
local nauthilus_http_request = require("nauthilus_http_request")

local header_table = nauthilus_http_request.get_all_http_request_headers()

for header_key, header_value_table in pair(header_table) do
  print("header key: " .. header_key)
  for index, header_value in ipars(header_value_table) do
    print("header_value[" .. tostring(index) .. "]: " .. header_value)
  end
end 
```

As the example demonstrates, the result is a Lua table. The names for each header are stored in the key of this table, while the values
are also stored in a Lua table as list of strings.

## nauthilus\_http\_request.get\_http\_request\_header

Get a table of values for an HTTP request header.

```lua
dynamic_loader("nauthilus_http_request")
local nauthilus_http_request = require("nauthilus_http_request")

local header_table = nauthilus_http_request.get_http_request_headers("Content-Type")
```

## nauthilus\_http\_request.get\_http\_request\_body

Get the payload of an HTTP request  as a string.

```lua
dynamic_loader("nauthilus_http_request")
local nauthilus_http_request = require("nauthilus_http_request")

local body = nauthilus_http_request.get_http_request_body()
```
