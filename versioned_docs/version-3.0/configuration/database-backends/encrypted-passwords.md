---
title: Encrypted Passwords
description: Supported password encryption formats in Nauthilus
keywords: [Configuration, Passwords, Encryption]
sidebar_position: 5
---

# Encrypted Passwords

Passwords can be stored encrypted inside a SQL database (Lua backend). Nauthilus needs to know this and can deal with the following
password schemas:

## Supported Formats

### PHP Versions

* \{SSHA256\}
* \{SSHA512\}

### Encoded Formats

* MD5
* SSHA256
* SSHA512
* bcrypt
* Argon2i
* Argon2id

## Usage in Lua Backend

The Lua backend can use a built-in function to compare such passwords. When implementing password verification in Lua, you can use the `compare_passwords` function to handle encrypted passwords:

```lua
-- Required modules
local nauthilus_util = require("nauthilus_util")

-- Load password module with dynamic_loader
local nauthilus_password = require("nauthilus_password")

function nauthilus_backend_verify_password(request)
    local b = nauthilus_backend_result.new()

    -- Retrieve the encrypted password from database
    local encrypted_password = get_password_from_database(request.username)

    -- Compare the provided password with the encrypted one
    local match, err = nauthilus_password.compare_passwords(encrypted_password, request.password)
    nauthilus_util.if_error_raise(err)

    -- Set authentication result
    b:authenticated(match)

    -- Return result
    return nauthilus_builtin.BACKEND_RESULT_OK, b
end
```

## Password Storage Best Practices

When storing passwords in your database, consider the following best practices:

1. **Use Strong Hashing Algorithms**: Prefer modern algorithms like Argon2id or bcrypt over older ones like MD5.

2. **Include Salt**: Ensure your password hashing includes a unique salt for each password to prevent rainbow table attacks.

3. **Configure Appropriate Work Factors**: For algorithms like bcrypt and Argon2, configure work factors that balance security and performance.

4. **Regular Updates**: Consider updating your password hashing scheme as newer, more secure algorithms become available.

## Example Configuration

When using the Lua backend with encrypted passwords, you might configure your database connection like this:

```lua
-- Required modules
local nauthilus_util = require("nauthilus_util")

-- Load password module with dynamic_loader
local nauthilus_password = require("nauthilus_password")

-- Example of comparing an encrypted password with a plaintext password
local function verify_encrypted_password(encrypted_password, plaintext_password)
    -- Compare the provided password with the encrypted one
    local match, err = nauthilus_password.compare_passwords(encrypted_password, plaintext_password)
    nauthilus_util.if_error_raise(err)

    return match
end

-- Usage example
local encrypted_password = "$argon2id$v=19$m=65536,t=3,p=4$c2FsdHNhbHRzYWx0$hash"
local is_match = verify_encrypted_password(encrypted_password, "user_password")

if is_match then
    print("Password is correct")
else
    print("Password is incorrect")
end
```

This configuration would be used by the Lua backend to properly verify passwords stored in your database.
