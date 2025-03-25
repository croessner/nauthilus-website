---
title: Password
description: Password related functions
keywords: [Lua]
sidebar_position: 9
---
# Password

```lua
dynamic_loader("nauthilus_password")
local nauthilus_password = require("nauthilus_password")
```

## nauthilus\_password.compare\_passwords

Compare two passwords. The first parameter is from a database. It is probably some kind of hash. The second argument is
a clear text password. The function detects the algorithm used by the first given parameter and creates the same for the second
parameter. If the result is equal, passwords are identical.

```lua
dynamic_loader("nauthilus_password")
local nauthilus_password = require("nauthilus_password")

local some_stored_pw = "password_from_db"
local some_password = "pw_given_by_user"

local match, err = nauthilus_password.compare_passwords(some_stored_pw, some_password)
```

## nauthilus\_password.check\_password\_policy

Check a given password against some password policy

```lua
dynamic_loader("nauthilus_password")
local nauthilus_password = require("nauthilus_password")

local password = "some_secret"

local ppolicy_ok = nauthilus_password.check_password_policy({
            min_length = 12,
            min_upper = 2,
            min_lower = 2,
            min_dumber = 1,
            min_special = 0,
        }, password)
```
