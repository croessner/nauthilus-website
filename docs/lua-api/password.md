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

Compares two passwords by detecting and applying the hashing algorithm.

### Syntax

```lua
local match, err = nauthilus_password.compare_passwords(stored_password, clear_password)
```

### Parameters

- `stored_password` (string): The password from a database, typically a hash
- `clear_password` (string): The clear text password to compare

### Returns

- `match` (boolean): True if passwords match, false otherwise
- `err` (string): An error message if comparison fails

### Example

```lua
dynamic_loader("nauthilus_password")
local nauthilus_password = require("nauthilus_password")

local some_stored_pw = "password_from_db"
local some_password = "pw_given_by_user"

local match, err = nauthilus_password.compare_passwords(some_stored_pw, some_password)
if match then
    print("Passwords match!")
else
    print("Passwords do not match or error: " .. (err or ""))
end
```

## nauthilus\_password.check\_password\_policy

Checks a given password against a defined password policy.

### Syntax

```lua
local policy_ok = nauthilus_password.check_password_policy(policy, password)
```

### Parameters

- `policy` (table): A Lua table containing the password policy rules:
  - `min_length` (number): Minimum password length
  - `min_upper` (number): Minimum number of uppercase characters
  - `min_lower` (number): Minimum number of lowercase characters
  - `min_number` (number): Minimum number of numeric characters
  - `min_special` (number): Minimum number of special characters
- `password` (string): The password to check against the policy

### Returns

- `policy_ok` (boolean): True if the password meets the policy requirements, false otherwise

### Example

```lua
dynamic_loader("nauthilus_password")
local nauthilus_password = require("nauthilus_password")

local password = "some_secret"

local ppolicy_ok = nauthilus_password.check_password_policy({
    min_length = 12,
    min_upper = 2,
    min_lower = 2,
    min_number = 1,
    min_special = 0,
}, password)

if ppolicy_ok then
    print("Password meets policy requirements")
else
    print("Password does not meet policy requirements")
end
```
