---
title: LDAP
description: LDAP related functions
keywords: [Lua]
sidebar_position: 6
---
# Backend LDAP

It is possible to send LDAP search requests to the main LDAP worker pool, if the **ldap** backend is enabled.

```lua
local nauthilus_ldap = require("nauthilus_ldap")
```

## nauthilus_ldap.ldap_endpoint

Resolves the LDAP endpoint (host and port) for a given LDAP worker pool.

This helper inspects the configured server_uri list of the selected pool and returns the hostname and port derived from the first URI. If the URI does not specify a port, a default is applied based on the scheme (ldaps → 636, otherwise 389). The function also ensures the pool is currently active (has workers registered).

### Syntax

```lua
local server, port, err = nauthilus_ldap.ldap_endpoint(pool_name)
```

### Parameters

- `pool_name` (string, optional): The name of the LDAP connection pool. If omitted, the main/default pool is used.

### Returns

- `server` (string or nil): Hostname of the LDAP endpoint on success; `nil` on error
- `port` (number or nil): TCP port of the LDAP endpoint on success; `nil` on error
- `err` (string or nil): Error message when resolution fails; `nil` on success

### Possible errors

- `ldap pool not active: <name>` — The requested pool has no active workers
- `ldap pool config not found: <name>` — The named pool has no configuration
- `no LDAP server_uri configured for pool: <name>` — The pool has no server URIs configured
- `invalid LDAP server_uri: <uri>` — The first configured URI is malformed

### Example

```lua
local nauthilus_ldap = require("nauthilus_ldap")

-- Default pool
local host, port, err = nauthilus_ldap.ldap_endpoint()
if err ~= nil then
  error("ldap_endpoint failed: " .. err)
end
print("LDAP host:", host, "port:", port)

-- Optional named pool "directory_eu"
local host2, port2, err2 = nauthilus_ldap.ldap_endpoint("directory_eu")
if err2 == nil then
  print("EU LDAP host:", host2, "port:", port2)
end
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
  - `raw_result` (boolean, optional): When set to `true`, returns the raw LDAP entries instead of the processed result (available since version 1.7.10)

### Returns

When `raw_result` is `false` or not specified:
- `result` (table): A Lua table where:
  - **Keys** are the LDAP attribute names
  - **Values** are tables containing all values for that attribute (multi-value support)
- `error` (string): An error message if the search fails

When `raw_result` is `true`:
- `result` (table): A Lua table containing the raw LDAP entries, where each entry is a table with:
  - `dn` (string): The distinguished name of the entry
  - `attributes` (table): A table where keys are attribute names and values are tables containing all values for that attribute
- `error` (string): An error message if the search fails

### Example

```lua
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

### Example with raw_result

```lua
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
  scope = "sub",
  raw_result = true
})

if result then
  for i, entry in ipairs(result) do
    print("DN: " .. entry.dn)
    for attr_name, attr_values in pairs(entry.attributes) do
      print("Attribute: " .. attr_name)
      for j, value in ipairs(attr_values) do
        print("  Value " .. j .. ": " .. value)
      end
    end
  end
end
```

When using `raw_result = true`, the result is a table of entries, where each entry contains the DN and all attributes with their values. This format preserves the structure of the LDAP entries and can be useful when you need to process multiple entries or need to know which attributes belong to which entry.

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
