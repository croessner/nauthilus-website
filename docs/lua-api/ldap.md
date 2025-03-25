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

The LDAP search function receives a Lua table with the search request and returns a result table and an error stirng.

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

:::warning
LDAP search requests are blocking operations!
:::
