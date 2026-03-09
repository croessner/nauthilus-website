---
title: Password
description: Password related functions
keywords: [Lua]
sidebar_position: 9
---
# Password

```lua
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


## nauthilus_password.generate_password_hash

Generates a short, Redis-compatible password hash identical to the one Nauthilus computes server-side. This is useful when Lua code needs to correlate with server password history or include the hash in notifications.

Since v1.8.2

Description
- Internally equivalent to util.GetHash(util.PreparePassword(password)).
- PreparePassword prefixes the configured server nonce and a NUL separator to the clear password.
- GetHash computes a SHA-256 and returns the first 8 lowercase hex characters.
- The function uses the server’s configured nonce; it does not expose or require it in Lua.

Syntax
```lua
local hash = nauthilus_password.generate_password_hash(password)
```

Parameters
- password (string): The clear text password to hash.

Returns
- hash (string): An 8-character lowercase hex string.

Example
```lua
local nauthilus_password = require("nauthilus_password")

local pw = "s3cr3t!"
local hash = nauthilus_password.generate_password_hash(pw)
print("Password hash:", hash) -- e.g., "a1b2c3d4"
```

Notes
- Intended for correlation and logging in controlled environments. Do not confuse this with full password hashing for storage; use compare_passwords or backend hashing for credential verification.
- Available in Nauthilus v1.8.2 and later.
