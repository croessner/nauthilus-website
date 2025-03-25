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

Get the human-friendly name of an ISO country code

```lua
dynamic_loader("nauthilus_misc")
local nauthilus_misc = require("nauthilus_misc")

local iso_code = "DE"

local country_name = nauthilus_misc.get_country_name(iso_code)
```
## nauthilus\_misc.wait\_random

Wait a raondom delay between a start and stop value in milliseconds

```lua
dynamic_loader("nauthilus_misc")
local nauthilus_misc = require("nauthilus_misc")

nauthilus_misc.wait_random(500, 3000)
```
