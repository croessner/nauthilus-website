---
title: HTTP
description: HTTP request functions to deal with headers and body
keywords: [Lua]
sidebar_position: 5
---
# HTTP request

```lua
local nauthilus_http_request = require("nauthilus_http_request")
```
## nauthilus\_http\_request.get\_all\_http\_request\_headers

Gets the full set of HTTP request headers from a connecting service.

### Syntax

```lua
local header_table = nauthilus_http_request.get_all_http_request_headers()
```

### Parameters

None

### Returns

- `header_table` (table): A Lua table where:
  - **Keys** are the header names (strings)
  - **Values** are tables containing all values for that header (as strings)

### Example

```lua
local nauthilus_http_request = require("nauthilus_http_request")

local header_table = nauthilus_http_request.get_all_http_request_headers()

for header_key, header_value_table in pairs(header_table) do
  print("header key: " .. header_key)
  for index, header_value in ipairs(header_value_table) do
    print("header_value[" .. tostring(index) .. "]: " .. header_value)
  end
end 
```

## nauthilus\_http\_request.get\_http\_request\_header

Gets a table of values for a specific HTTP request header.

### Syntax

```lua
local header_table = nauthilus_http_request.get_http_request_header(header_name)
```

### Parameters

- `header_name` (string): The name of the HTTP header to retrieve

### Returns

- `header_table` (table): A Lua table containing all values for the specified header (as strings)

### Example

```lua
local nauthilus_http_request = require("nauthilus_http_request")

local header_table = nauthilus_http_request.get_http_request_header("Content-Type")
```

## nauthilus\_http\_request.get\_http\_request\_body

Gets the payload of an HTTP request as a string.

### Syntax

```lua
local body = nauthilus_http_request.get_http_request_body()
```

### Parameters

None

### Returns

- `body` (string): The HTTP request body content

### Example

```lua
local nauthilus_http_request = require("nauthilus_http_request")

local body = nauthilus_http_request.get_http_request_body()
```
