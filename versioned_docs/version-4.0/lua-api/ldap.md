---
title: LDAP
description: Perform bounded LDAP searches and modifications from Lua
keywords: [Lua, LDAP, Security]
sidebar_position: 6
---

# Backend LDAP

Lua scripts can submit searches and modifications to the configured LDAP worker pool when the LDAP backend is enabled.

```lua
local nauthilus_ldap = require("nauthilus_ldap")
```

## Security Model

LDAP operations are bounded by default. An untrusted operation must declare `allowed_base_dn`; the search base or modify
DN must be equal to that DN or a descendant of it.

For searches, prefer `filter_attr` and `filter_value`. Nauthilus validates the attribute description and escapes the
value before constructing an LDAP equality filter. A raw `filter` is accepted only together with `trusted = true`.

::::warning
Do not set `trusted = true` for data derived from requests, users, headers, tokens, or other external input. Trusted mode
removes the mandatory subtree boundary when `allowed_base_dn` is omitted and permits a raw LDAP filter.
::::

The safe and trusted search forms are mutually exclusive in practice:

```lua
-- Safe equality filter: filter_value is escaped by Nauthilus.
filter_attr = "uid"
filter_value = user

-- Raw filter: use only for a static, application-controlled expression.
filter = "(&(objectClass=person)(accountStatus=active))"
trusted = true
```

## `nauthilus_ldap.ldap_endpoint`

Resolves the LDAP endpoint for a worker pool. The helper reads the first configured `server_uri`. If the URI does not
contain a port, it returns 636 for `ldaps` and 389 for other TCP schemes. The selected pool must have active workers.

### Syntax

```lua
local server, port, err = nauthilus_ldap.ldap_endpoint(pool_name)
```

### Parameters

- `pool_name` (string, optional): configured pool name. Omit it for the default pool.

### Returns

- `server` (string or `nil`): endpoint hostname on success.
- `port` (number or `nil`): endpoint port on success.
- `err` (string or `nil`): error message on failure.

For an `ldapi` URI, the helper returns the socket path as `server` and `0` as `port`.

### Possible Errors

- `ldap pool not active: <name>`
- `ldap pool config not found: <name>`
- `no LDAP server_uri configured for pool: <name>`
- `invalid LDAP server_uri: <uri>`

### Example

```lua
local nauthilus_ldap = require("nauthilus_ldap")

local host, port, err = nauthilus_ldap.ldap_endpoint()
if err ~= nil then
  error("ldap_endpoint failed: " .. err)
end

print("LDAP host:", host, "port:", port)

local eu_host, eu_port, eu_err = nauthilus_ldap.ldap_endpoint("directory_eu")
if eu_err == nil then
  print("EU LDAP host:", eu_host, "port:", eu_port)
end
```

## `nauthilus_ldap.ldap_search`

Performs an LDAP search through the selected worker pool.

### Syntax

```lua
local result, err = nauthilus_ldap.ldap_search(search_params)
```

### Parameters

`search_params` is a table with these fields:

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `pool_name` | string | yes | Configured pool name. Use `"default"` for the default pool. |
| `session` | string | yes | Request/session identifier used for correlation. |
| `basedn` | string | yes | Search base DN. |
| `allowed_base_dn` | string | unless trusted | Maximum subtree available to the operation. |
| `filter_attr` | string | for safe form | LDAP attribute description for an equality filter. |
| `filter_value` | string | for safe form | Equality value; Nauthilus escapes it with LDAP filter escaping. |
| `filter` | string | trusted form only | Complete raw LDAP filter. Requires `trusted = true`. |
| `trusted` | boolean | no | Enables the raw-filter form and permits omitting `allowed_base_dn`. Defaults to `false`. |
| `attributes` | table | yes | Array of attribute names to retrieve. |
| `scope` | string | yes | `base`, `one`, or `sub`. |
| `raw_result` | boolean | no | Return entries with their DNs instead of the merged attribute map. |

Only conservative LDAP attribute descriptions are accepted for `filter_attr`. The base DN and allowed DN must both be
valid LDAP DNs, and the base must stay inside the allowed subtree.

### Returns

With `raw_result` omitted or `false`, `result` is a table whose keys are LDAP attribute names and whose values are
arrays containing all values for that attribute.

With `raw_result = true`, `result` is an array of entries:

```lua
{
  {
    dn = "uid=bob,ou=people,dc=example,dc=com",
    attributes = {
      uid = { "bob" },
      mail = { "bob@example.com" }
    }
  }
}
```

On a worker or LDAP error, the function returns `nil, err`.

### Safe Search Example

```lua
local nauthilus_ldap = require("nauthilus_ldap")

local user = request.username
local result, err = nauthilus_ldap.ldap_search({
  pool_name = "default",
  session = request.session,
  basedn = "ou=people,dc=example,dc=com",
  allowed_base_dn = "ou=people,dc=example,dc=com",
  filter_attr = "uid",
  filter_value = user,
  attributes = {
    "uid",
    "mail",
    "displayName",
  },
  scope = "sub"
})

if err ~= nil then
  error("LDAP search failed: " .. err)
end

local first_mail = result.mail and result.mail[1]
```

Even if `user` contains LDAP filter metacharacters, Nauthilus treats it as a value rather than filter syntax.

### Raw Result Example

```lua
local result, err = nauthilus_ldap.ldap_search({
  pool_name = "default",
  session = request.session,
  basedn = "ou=people,dc=example,dc=com",
  allowed_base_dn = "ou=people,dc=example,dc=com",
  filter_attr = "uid",
  filter_value = request.username,
  attributes = { "uid", "mail" },
  scope = "sub",
  raw_result = true
})

if err ~= nil then
  error("LDAP search failed: " .. err)
end

for _, entry in ipairs(result) do
  print("DN: " .. entry.dn)
  for name, values in pairs(entry.attributes) do
    for _, value in ipairs(values) do
      print(name .. ": " .. value)
    end
  end
end
```

::::warning
LDAP search requests are blocking operations. Keep searches narrow and use request timeouts appropriate for the calling
Lua extension point.
::::

## `nauthilus_ldap.ldap_modify`

Performs one LDAP modify operation through the selected worker pool.

### Syntax

```lua
local result, err = nauthilus_ldap.ldap_modify(modify_params)
```

### Parameters

`modify_params` is a table with these fields:

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `pool_name` | string | yes | Configured pool name. Use `"default"` for the default pool. |
| `session` | string | yes | Request/session identifier used for correlation. |
| `dn` | string | yes | Exact entry DN to modify. |
| `allowed_base_dn` | string | unless trusted | Maximum subtree available to the operation. |
| `trusted` | boolean | no | Permits omitting `allowed_base_dn`. Defaults to `false`. |
| `operation` | string | yes | `add`, `delete`, or `replace`. |
| `attributes` | table | yes | Map of attribute name to a single string value for this operation. |
| `assertion_filter` | string | no | LDAP filter sent as a critical RFC 4528 assertion control. The modify is applied only if the entry still matches it. |

The entry DN must be equal to or below `allowed_base_dn`. Prefer a narrow subtree such as an organizational unit rather
than the directory root.

### Returns

- `"OK"` on success.
- `nil, err` when the LDAP worker reports an error.

### Example

```lua
local nauthilus_ldap = require("nauthilus_ldap")

local result, err = nauthilus_ldap.ldap_modify({
  pool_name = "default",
  session = request.session,
  dn = "uid=bob,ou=people,dc=example,dc=com",
  allowed_base_dn = "ou=people,dc=example,dc=com",
  operation = "replace",
  attributes = {
    telephoneNumber = "+1 555 123 4567"
  }
})

if err ~= nil then
  error("LDAP modify failed: " .. err)
end
```

Use separate calls for separate modify operations or values.

## `nauthilus_ldap.ldap_modify_assert`

Performs a conditional LDAP modify. It accepts the same table as `ldap_modify` but requires a non-empty
`assertion_filter`, so an accidental unconditional write is impossible.

### Syntax

```lua
local result, err = nauthilus_ldap.ldap_modify_assert(modify_params)
```

### Behavior

- The filter is compiled and attached as a critical LDAP assertion control (OID `1.3.6.1.1.12`). The directory server
  applies the modification atomically only while the entry matches the filter; the server must support RFC 4528.
- A missing or empty `assertion_filter` raises the Lua error `assertion_filter is required`.
- An invalid filter or a failed assertion is returned as `nil, err`, like any other LDAP worker error. Re-read the entry
  before deciding whether to retry.
- `ldap_modify` accepts the same optional `assertion_filter` field; use `ldap_modify_assert` when the precondition is
  mandatory.

### Example

Update a mail protocol setting only if nobody changed the entry since it was read:

```lua
local nauthilus_ldap = require("nauthilus_ldap")

local result, err = nauthilus_ldap.ldap_modify_assert({
  pool_name = "default",
  session = request.session,
  dn = "uid=bob,ou=people,dc=example,dc=com",
  allowed_base_dn = "ou=people,dc=example,dc=com",
  operation = "replace",
  attributes = {
    mailProtocols = "imap"
  },
  assertion_filter = "(entryCSN=" .. previous_entry_csn .. ")"
})

if err ~= nil then
  -- The entry changed concurrently, the filter was invalid, or the directory rejected the modify.
  return nil, err
end
```

Escape any value that you insert into `assertion_filter`, exactly as for search filters.

The `--test-lua` mock of `nauthilus_ldap` provides `ldap_modify` but not `ldap_modify_assert`; test the conditional path
against a real directory.

::::warning
LDAP modify requests are blocking and mutate directory state. Keep `allowed_base_dn` narrow and never enable trusted mode
for user-controlled DNs.
::::
