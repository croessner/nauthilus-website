---
title: Misc
description: Miscellaneous functions
keywords: [Lua]
sidebar_position: 8
---
# Misc

```lua
dynamic_loader("nauthilus_misc")
local nauthilus_misc = require("nauthilus_misc")
```

## nauthilus\_misc.get\_country\_name

Gets the human-friendly name of an ISO country code.

### Syntax

```lua
local country_name = nauthilus_misc.get_country_name(iso_code)
```

### Parameters

- `iso_code` (string): The ISO 3166-1 alpha-2 country code

### Returns

- `country_name` (string): The human-readable country name

### Example

```lua
dynamic_loader("nauthilus_misc")
local nauthilus_misc = require("nauthilus_misc")

local iso_code = "DE"

local country_name = nauthilus_misc.get_country_name(iso_code)
-- Returns "Germany"
```
## nauthilus\_misc.wait\_random

Waits for a random delay between a start and stop value in milliseconds.

### Syntax

```lua
nauthilus_misc.wait_random(start_ms, stop_ms)
```

### Parameters

- `start_ms` (number): The minimum delay in milliseconds
- `stop_ms` (number): The maximum delay in milliseconds

### Returns

None

### Example

```lua
dynamic_loader("nauthilus_misc")
local nauthilus_misc = require("nauthilus_misc")

-- Wait between 500ms and 3000ms
nauthilus_misc.wait_random(500, 3000)
```
