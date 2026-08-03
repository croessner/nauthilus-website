---
title: CBOR
description: Lua helpers for encoding and decoding CBOR payloads
keywords: [Lua, CBOR, Encoding]
sidebar_position: 21
---

# CBOR

```lua
local cbor = require("nauthilus_cbor")
```

The `nauthilus_cbor` module exposes the same CBOR policy used by the HTTP authentication endpoint. It can encode Lua values to a CBOR byte string and decode CBOR byte strings back into Lua values.

## Supported Values

Decoded CBOR values are converted to Lua as follows:

| CBOR value | Lua value |
| --- | --- |
| null | `cbor.null` |
| boolean | boolean |
| text string | string |
| byte string | string |
| integer | number |
| floating point | number |
| array | table with consecutive numeric keys |
| map | table |

When encoding Lua values:

- `nil` becomes CBOR null.
- booleans, strings, numbers, arrays, and maps are supported.
- integer Lua numbers are encoded as integers; non-integer numbers are encoded as floating point values.
- array tables use consecutive numeric keys from `1` to `#table`.
- map tables use string keys; integer numeric keys are converted to string keys.
- `cbor.bytes(value)` marks a Lua string for CBOR byte-string encoding.
- `cbor.null` can be used when a table needs an explicit null value.

## cbor.decode

Decodes a CBOR byte string.

### Syntax

```lua
local value, err = cbor.decode(payload)
```

### Parameters

- `payload` (string): CBOR bytes.

### Returns

- `value` (any): The decoded Lua value, or `nil` on error.
- `err` (string): Error text, or `nil` on success.

### Example

```lua
local cbor = require("nauthilus_cbor")

local value, err = cbor.decode(request_body)
if err ~= nil then
  return nauthilus_builtin.custom_log("CBOR decode failed: " .. err)
end

if value.optional_field == cbor.null then
  value.optional_field = nil
end
```

## cbor.encode

Encodes a Lua value as a CBOR byte string.

### Syntax

```lua
local payload, err = cbor.encode(value)
```

### Parameters

- `value` (any): Lua value to encode.

### Returns

- `payload` (string): Encoded CBOR bytes, or `nil` on error.
- `err` (string): Error text, or `nil` on success.

### Example

```lua
local cbor = require("nauthilus_cbor")

local payload, err = cbor.encode({
  username = "alice@example.test",
  ok = true,
  attributes = {
    "mail",
    "uid",
  },
  binary = cbor.bytes("\001\002\003"),
  absent = cbor.null,
})

if err ~= nil then
  return nauthilus_builtin.custom_log("CBOR encode failed: " .. err)
end
```

## cbor.bytes

Marks a Lua string as a CBOR byte string during encoding. Without this marker, Lua strings are encoded as CBOR text strings.

### Syntax

```lua
local bytes = cbor.bytes(value)
```

### Parameters

- `value` (string): Bytes stored in a Lua string.

### Returns

- `bytes` (userdata): A byte-string marker accepted by `cbor.encode`.

## cbor.null

`cbor.null` is a stable sentinel for explicit CBOR null values. It is useful when null must be preserved inside a Lua table because plain Lua `nil` removes a table key.
