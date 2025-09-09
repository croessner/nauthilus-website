---
title: HTTP response
description: HTTP response functions for setting headers, status and body from Lua
keywords: [Lua]
sidebar_position: 6
---
# HTTP response

The `nauthilus_http_response` module allows Lua code to set or modify HTTP response headers,
set the HTTP status code, and write the raw response body. This is useful, for example, to
signal frontends (like Keycloak) to apply additional protection measures (e.g., CAPTCHA),
return specific HTTP statuses from custom hooks, or serve non-JSON content directly from Lua.

Availability: since Nauthilus 1.8.5. Status and body writing support added in 1.9.0. Content-Type helper and Gin-mapped wrappers added in 1.9.2.

```lua
dynamic_loader("nauthilus_http_response")
local nauthilus_http_response = require("nauthilus_http_response")
```

Notes
- Availability: This module is available in Hooks. It may also be used by Filters and Features, but with strict limitations (see below). It is not available in non-HTTP contexts (e.g., pure backend workers without an HTTP response).
- If you write generic Lua code that may also run in non-HTTP contexts, guard calls with `pcall(...)`. 
- Header names are case-insensitive on the wire; use canonical forms for readability.
- Important: Filters and Features MUST NOT send a response body. They may set or add/remove HTTP response headers to signal state to the frontend, and they may set an HTTP status code if appropriate, but they must not write the response body or use helpers that emit a body (see Prohibited operations in Filters/Features).

## nauthilus_http_response.set_http_response_header

Replaces the value of an HTTP response header. If the header already exists, its values are overwritten with the provided one.

### Syntax

```lua
nauthilus_http_response.set_http_response_header(name, value)
```

### Parameters

- `name` (string): Header name
- `value` (string): Header value to set

### Returns

None

### Example

```lua
dynamic_loader("nauthilus_http_response")
local nauthilus_http_response = require("nauthilus_http_response")

-- Force JSON response type
nauthilus_http_response.set_http_response_header("Content-Type", "application/json")
```

## nauthilus_http_response.add_http_response_header

Appends a value to an HTTP response header without removing existing values.

### Syntax

```lua
nauthilus_http_response.add_http_response_header(name, value)
```

### Parameters

- `name` (string): Header name
- `value` (string): Header value to add

### Returns

None

### Example

```lua
dynamic_loader("nauthilus_http_response")
local nauthilus_http_response = require("nauthilus_http_response")

-- Add an additional Vary entry while keeping others intact
nauthilus_http_response.add_http_response_header("Vary", "Accept-Encoding")
```

## nauthilus_http_response.remove_http_response_header

Removes an HTTP response header from the response.

### Syntax

```lua
nauthilus_http_response.remove_http_response_header(name)
```

### Parameters

- `name` (string): Header name

### Returns

None

### Example

```lua
dynamic_loader("nauthilus_http_response")
local nauthilus_http_response = require("nauthilus_http_response")

-- Remove an accidental header
nauthilus_http_response.remove_http_response_header("X-Debug")
```

## nauthilus_http_response.set_http_status

Sets the HTTP status code for the current response. Availability: Hooks only.

### Syntax

```lua
nauthilus_http_response.set_http_status(code)
```

### Parameters

- `code` (number): HTTP status code (e.g., 200, 403, 429)

### Returns

None

### Example
```lua
dynamic_loader("nauthilus_http_response")
local rsp = require("nauthilus_http_response")

-- signal rate limiting
rsp.set_http_status(429)
```

## nauthilus_http_response.set_http_content_type

Sets the Content-Type response header. This is a convenience wrapper around set_http_response_header specifically for Content-Type.

Version: Introduced in Nauthilus 1.9.2.

### Syntax

```lua
nauthilus_http_response.set_http_content_type(value)
```

### Parameters

- `value` (string): The MIME type with optional charset, e.g., "text/html; charset=utf-8".

### Returns

None

### Example

```lua
dynamic_loader("nauthilus_http_response")
local rsp = require("nauthilus_http_response")

rsp.set_http_content_type("text/html; charset=utf-8")
rsp.set_http_status(200)
rsp.write_http_response_body("<html><body>Hello</body></html>")
```

Notes
- Prefer this over manually setting the header when writing custom bodies.
- Combine with write_http_response_body and set_http_status for full control.

## Prohibited operations in Filters/Features

The following operations MUST NOT be used from Filters or Features because they send a response body. Using these from Filters/Features can break upstream expectations and clients:

- nauthilus_http_response.write_http_response_body(...)
- nauthilus_http_response.string(status, body)
- nauthilus_http_response.html(status, html)
- nauthilus_http_response.data(status, content_type, data)

These APIs are only permitted from Hooks. Filters and Features are limited to manipulating headers and, if needed, setting an HTTP status code. See the examples below for allowed usage.

## nauthilus_http_response.write_http_response_body

Writes raw data to the HTTP response body. When you write the body in Lua, Nauthilus will not
override it with a JSON payload. Be sure to set an appropriate `Content-Type` header and
status code yourself when returning custom content.

### Syntax

```lua
nauthilus_http_response.write_http_response_body(data)
```

### Parameters

- `data` (string): The raw content to write to the response body

### Returns

None

### Example

```lua
dynamic_loader("nauthilus_http_response")
local rsp = require("nauthilus_http_response")

-- Return plain text content directly from a custom hook
rsp.set_http_response_header("Content-Type", "text/plain; charset=utf-8")
rsp.set_http_status(200)
rsp.write_http_response_body("Hello from Lua!\n")

-- Note: When the response body has been written, the server will not emit JSON from any returned Lua table.
```

### Interaction with custom hooks' JSON behavior

- If your Lua hook returns a Lua table and does NOT write to the response body, Nauthilus
  will serialize that table as JSON and use the current response status (default 200 if unset).
- If your Lua hook writes to the response body (using `write_http_response_body`) or otherwise
  has already written headers/body, the server will not override it with JSON.
- This allows you to return arbitrary content types (HTML, text, binary) from Lua hooks.

## New in 1.9.2: Gin-mapped wrappers and status constants

Version 1.9.2 introduces direct wrappers for common Gin response helpers. These wrappers always require an explicit status code and internally call the respective Gin methods. They also handle HEAD requests safely (no body is written for HEAD):

- nauthilus_http_response.string(status, body): text/plain with Gin's ctx.String
- nauthilus_http_response.data(status, content_type, data): arbitrary content with ctx.Data
- nauthilus_http_response.html(status, html): convenience for text/html; charset=utf-8 using ctx.Data
- nauthilus_http_response.redirect(status, location): send a redirect using ctx.Redirect

In addition, the module now exposes UPPER_CASE status code constants for convenience:

- STATUS_OK, STATUS_CREATED, STATUS_NO_CONTENT
- STATUS_MOVED_PERMANENTLY, STATUS_FOUND, STATUS_SEE_OTHER, STATUS_NOT_MODIFIED
- STATUS_BAD_REQUEST, STATUS_UNAUTHORIZED, STATUS_FORBIDDEN, STATUS_NOT_FOUND, STATUS_METHOD_NOT_ALLOWED, STATUS_CONFLICT, STATUS_UNSUPPORTED_MEDIA_TYPE, STATUS_TOO_MANY_REQUESTS
- STATUS_INTERNAL_SERVER_ERROR, STATUS_NOT_IMPLEMENTED, STATUS_BAD_GATEWAY, STATUS_SERVICE_UNAVAILABLE, STATUS_GATEWAY_TIMEOUT

Example usage:

```lua
dynamic_loader("nauthilus_http_response")
local rsp = require("nauthilus_http_response")

-- Text response
rsp.set_http_response_header("Cache-Control", "no-cache")
rsp.string(rsp.STATUS_OK, "Hello from Lua!\n")

-- HTML response
local html = "<html><body><h1>Hello</h1></body></html>"
rsp.html(rsp.STATUS_OK, html)

-- Binary or arbitrary content
local csv = "a,b,c\n1,2,3\n"
rsp.data(rsp.STATUS_OK, "text/csv; charset=utf-8", csv)

-- Redirect
rsp.redirect(rsp.STATUS_SEE_OTHER, "/login")
```

Notes
- Always pass an explicit status code; there is no default.
- For HEAD requests, string/html/data will set status and refrain from writing a body.
- Prefer adding Cache-Control: no-cache for dynamic responses.

## Allowed usage in Filters/Features: signaling protection mode

In an account-protection filter you may want to hint a frontend to require a CAPTCHA
or other step-up challenge for a specific account. Combine your detection logic with
response headers as follows:

```lua
dynamic_loader("nauthilus_http_response")
local nauthilus_http_response = require("nauthilus_http_response")

-- within your filter logic after detecting protection mode
pcall(function()
  nauthilus_http_response.set_http_response_header("X-Nauthilus-Protection", "stepup")
  nauthilus_http_response.set_http_response_header("X-Nauthilus-Protection-Reason", "uniq24,fail24")
end)
```

This pattern is safe in mixed environments because `pcall` prevents failures in non-HTTP contexts.
