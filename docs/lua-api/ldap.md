---
title: LDAP
description: LDAP related functions
keywords: [Lua]
sidebar_position: 6
---
# Backend LDAP

It is possible to send LDAP search requests to the main LDAP worker pool, if the **ldap** backend is enabled.

```lua
dynamic_loader("nauthilus_ldap")
local nauthilus_ldap = require("nauthilus_ldap")
```

## nauthilus\_ldap.ldap\_search

Performs an LDAP search request using the main LDAP worker pool.

### Syntax

```lua
local result, error = nauthilus_ldap.ldap_search(search_params)
```

### Parameters

- `search_params` (table): A Lua table containing the search parameters:
  - `pool_name` (string, optional): The name of the LDAP connection pool to use (defaults to the main pool if not specified)
  - `session` (string): The session identifier from the calling function
  - `basedn` (string): The base DN for the LDAP search
  - `filter` (string): The LDAP search filter
  - `attributes` (table): A Lua table listing the attributes to retrieve
  - `scope` (string): The search scope (e.g., "sub", "base", "one")

### Returns

- `result` (table): A Lua table where:
  - **Keys** are the LDAP attribute names
  - **Values** are tables containing all values for that attribute (multi-value support)
- `error` (string): An error message if the search fails

### Example

```lua
dynamic_loader("nauthilus_ldap")
local nauthilus_ldap = require("nauthilus_ldap")

local user = "bob"

local result, error = nauthilus_ldap.ldap_search({
  session = request.session, -- request: from the calling function
  basedn = "dc=acme,dc=com",
  filter = "(|(uniqueIdentifier=" .. user .. ")(uid=" .. user .. "))",
  attributes = {
    [1] = "some_attr1",
    [2] = "some_attr2",
  },
  scope = "sub"
})

local attributes = {} -- may be applied in a filter
if result then
  if type(result) == "table" then
    for key, value in pairs(result) do
      attributes[key] = value[1] -- LDAP single value example
    end
  end
end 
```

If anything went fine, the **result** contains a Lua table, where the key represents the LDAP attribute name and the values
are Lua tables with all values (multi value).

::::warning
LDAP search requests are blocking operations!
::::

## nauthilus\_ldap.ldap\_modify

Performs an LDAP modify operation using the main LDAP worker pool.

### Syntax

```lua
local result, error = nauthilus_ldap.ldap_modify(modify_params)
```

### Parameters

- `modify_params` (table): A Lua table containing the modify parameters:
  - `pool_name` (string, optional): The name of the LDAP connection pool to use (defaults to the main pool if not specified)
  - `session` (string): The session identifier from the calling function
  - `dn` (string): The distinguished name of the LDAP entry to modify
  - `operation` (string): The type of modify operation to perform:
    - **add**: Add the specified attributes/values to the entry
    - **delete**: Remove the specified attributes/values from the entry
    - **replace**: Replace the specified attributes/values in the entry
  - `attributes` (table): A Lua table where:
    - **Keys** are the attribute names
    - **Values** are tables containing the values for that attribute

### Returns

- `result` (string): "OK" if the operation was successful
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_ldap")
local nauthilus_ldap = require("nauthilus_ldap")

-- Example: Add a new attribute to a user
local result, error = nauthilus_ldap.ldap_modify({
  session = request.session, -- request: from the calling function
  dn = "uid=bob,ou=people,dc=acme,dc=com",
  operation = "add",
  attributes = {
    telephoneNumber = { "+1 555 123 4567" }
  }
})

-- Example: Delete an attribute from a user
local result, error = nauthilus_ldap.ldap_modify({
  session = request.session,
  dn = "uid=bob,ou=people,dc=acme,dc=com",
  operation = "delete",
  attributes = {
    telephoneNumber = { "+1 555 123 4567" }
  }
})

-- Example: Replace an attribute value
local result, error = nauthilus_ldap.ldap_modify({
  session = request.session,
  dn = "uid=bob,ou=people,dc=acme,dc=com",
  operation = "replace",
  attributes = {
    mail = { "bob.new@acme.com" }
  }
})
```

::::warning
LDAP modify requests are blocking operations!
::::