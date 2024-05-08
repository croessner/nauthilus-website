---
title: Lua support
description: Documentation of Lua support built into Nauthilus
keywords: [Lua]
sidebar_position: 5
---
# Lua Support

Nauthilus has Lua 5.1 support in all areas of the service. To understand the interfaces, you must first get an idea of
what happens with an incoming authentication request.

<!-- TOC -->
* [Lua Support](#lua-support)
  * [Authentication workflow](#authentication-workflow)
  * [Additional things to know](#additional-things-to-know)
  * [Configuration](#configuration)
  * [Lua components](#lua-components)
    * [Actions](#actions)
    * [Features](#features)
    * [Lua backend](#lua-backend)
    * [Filters](#filters)
    * [Post actions](#post-actions)
  * [Required functions and constants](#required-functions-and-constants)
  * [Common request fields for all Lua scripts](#common-request-fields-for-all-lua-scripts)
    * [Features](#features-1)
      * [Constants for the returned result](#constants-for-the-returned-result)
    * [Request fields](#request-fields)
    * [Filters](#filters-1)
      * [Constants for the returned result](#constants-for-the-returned-result-1)
    * [Request fields](#request-fields-1)
    * [Actions (including post)](#actions-including-post)
      * [Constants for the returned result](#constants-for-the-returned-result-2)
    * [Request fields](#request-fields-2)
    * [Lua Backend](#lua-backend-1)
      * [Constants for the returned result](#constants-for-the-returned-result-3)
    * [Request fields](#request-fields-3)
    * [Function nauthilus\_backend\_verify\_password request fields](#function-nauthilus_backend_verify_password-request-fields)
    * [Function nauthilus\_backend\_list\_accounts request fields](#function-nauthilus_backend_list_accounts-request-fields)
      * [Function nauthilus\_backend\_add\_totp request fields](#function-nauthilus_backend_add_totp-request-fields)
  * [UserData object backend\_result](#userdata-object-backend_result)
    * [backend](#backend)
    * [filters](#filters-2)
    * [Example usage for backend\_result](#example-usage-for-backend_result)
      * [Endpoints /api/v1/mail/dovecot, /api/v1/generic/user and /api/v1/generic/json](#endpoints-apiv1maildovecot-apiv1genericuser-and-apiv1genericjson)
* [API](#api)
<!-- TOC -->

## Authentication workflow

An incoming authentication request first enters the **brute\_force** check. After that it continues with the **features** 
pipeline. After that has past, it continues to process the request in a **password backend**. When the final result for the 
request was obtained, it passes **filters**. 

Filters may change the backend result in one or the other way (accepting a formely rejected message or vice versa). This 
is especially useful for other remote services that can influence the authentication process. 

After all this has finished, it is possible to do some **post actions**, which are run independent 
of all other steps in the whole pipeline and therefor can not influence the final result anymore. 

In the following sequence diagram you can see the processing of the request in more detail.

```mermaid
sequenceDiagram
    actor User
    participant Request
    participant Brute force check
    participant Features
    participant Actions
    participant Backend
    participant Filters
    participant Finished
    User->>Request: Wants to authenticate
    activate Request
    Note over Request,Filters:A Lua context is created: All scripts can manipulate this context with set, get and delete operations.  
    Request->>Brute force check:Does user triger a brute froce rule?
    activate Brute force check
    alt Brute force attack detected
    activate Actions
    Brute force check->>Actions:Do some actions
    loop Action pipeline
    Actions->>Actions: Run all action one after another
    end
    Actions->>Finished:Request was rejected
    deactivate Actions
    else No brute force attack detected
    Brute force check->>Features:Request continues
    deactivate Brute force check
    end
    activate Features
    loop Features pipeline
    Features->>Features:Run all features one after another
    end
    alt Some featured was triggered
    activate Actions
    Features->>Actions:Do some actions
    loop Action pipeline
      Actions->>Actions:Run all action one after another
    end
    Actions->>Finished:Request was rejected
    deactivate Actions
    else No featured triggered
    Features->>Backend:Do the main authentication process
    deactivate Features
    end
    activate Backend
    Backend->>Filters:Give pre-result to the filters
    deactivate Backend
    activate Filters
    Filters->>Finished:The result is accept or reject 
    Filters-->>Actions:Post actions run in background, while the request was already processed
    deactivate Filters
    deactivate Request
    activate Actions
    loop Post action pipeline
    Actions->>Actions:Run all action one after another
    end
    deactivate Actions
```
## Additional things to know

When an incoming authentication request is started, a Lua context is created.

All parts of a request share that common request context. Lua scripts can set arbitrary data in the context and read/delete
things from there. 

Lua scripts can modify the final log line by adding key-value pairs from each script.

## Configuration

For the configuration please have a look for the [configuration file](configuration-file.md) document.

## Lua components

Each component does provide a set of global functions, constants, ... and requires a well-defined response from each request.

Every Lua script that has been configured, is pre-compiled and kept in memory for future use. To make script changes, you
must reload the service.

### Actions

Whenever a brute froce attack is recognized, **action**s may be called. The request will wait until all requests have 
finished. Actions are processed by a central action worker. No results are returned to the regular request, so actions
in general do their own logging!

Also, **features** may call actions, if they were triggered. The request is waiting to finish all actions by the worker 
process.

### Features

Besides the well known features geoip, rbl, tls\_encryption and relay\_domains, a new feature has been integrated: lua. This
feature is processed before all other features (in fact, you might replace all these features with pure Lua...). Lua-features 
are run one after another. As soon as a feature has triggered, the request will reject the authentication process.
Furthermore, Lua features can set a flag to bypass all built-in features.

### Lua backend

A new backend has been implemented. It can be used for all features that Nauthilus currently supports: Checking passwords,
running different modes (no-auth, list-accounts), adding TOTP...

The backend can accept a request or reject it. It has full access to all meta information that are delivered from the
incoming request.

### Filters

There may exist remote services that may be contacted after the main backend authentication proccess returned its first  
result. Think of something like GeoIP service or some IP white/blacklisting. Even a request that might have authenticated
correctly may be rejected to a policy violation from such a service. Therefor filters have the power to overwrite the
result from a backend.

You can also use filters to retrieve additional information from databases or LDAP and add additional attributes to the remaining result.
This is useful for setups, where Nauthilus may also take the role of a Dovecot proxy. Users may get routed to different
mail stores upon successful authentication. For this, you may retrieve the current backend server list with servers that have been
checked as being alive with the **backend\_server\_monitoring** feature and select nominate it for the current client request.

:::info
Filters never affect caching! This is important, because otherwise valid credentials might result in storing them in the
negative password cache or vice versa for invalid credentials.
:::

:::warning
You always have to deal with the "request.authenticated" flag! If you don't care enough, you might acidentially reject
legitimate authenticated users or allow bad guys.
:::

### Post actions

Post actions are actions, which run after the request hast come to its final result. Its main purpose is to start some
automated things like doing statistics stuff, sending messages to operators or anything else that does not require fast
instant processing.

As an example have a look at the telegram script. Lua scripts in earlier stages of the process may provide some 
information by using the Lua context. The telegram script may pick up these information and decide to send out some 
notifications to an operator channel.

## Required functions and constants

Every Lua script must provide a pre-defined Lua function with a request parameter. Concerning the actual script, there is
a requried return statement.

Nauthilus will look for these functions and parses the results.

## Common request fields for all Lua scripts

The following request fields are supported

| Name                     | Type   | Precense | Additional info                                                   |
|--------------------------|--------|----------|-------------------------------------------------------------------|
| debug                    | bool   | always   | -                                                                 |
| repeating                | bool   | maybe    | -                                                                 |
| user_found               | bool   | maybe    | -                                                                 |
| authenticated            | bool   | maybe    | -                                                                 |
| no_auth                  | bool   | always   | true, if the reuqest is used to retrieve user information         |
| service                  | string | always   | Nauthilus endpoint like "dovecot" or "nginx"                      |
| session                  | string | always   | -                                                                 |
| client\_ip               | string | always   | -                                                                 |
| client\_port             | string | always   | -                                                                 |
| client_net               | string | maybe    | Available in conjunction with brute-force-actions                 |
| client\_id               | string | maybe    | -                                                                 |
| user\_agent              | string | maybe    | -                                                                 |
| local\_ip                | string | always   | -                                                                 |
| local\_port              | string | always   | -                                                                 |
| username                 | string | always   | -                                                                 |
| account                  | string | maybe    | Filter and post actions                                           |
| unique\_user\_id         | string | maybe    | Used with OIDC subject                                            |
| display\_name            | string | maybe    | -                                                                 |
| password                 | string | always   | -                                                                 |
| protocol                 | string | always   | -                                                                 |
| brute\_force\_bucket     | string | maybe    | Available in conjunction with brute-force-actions                 |
| feature                  | string | maybe    | In actions, if a feature has triggered                            |
| status\_message          | string | always   | Current status message returned to client, if auth request failed |
| ssl                      | string | maybe    | HAproxy: %[ssl\_fc]                                               |
| ssl\_session\_id         | string | maybe    | HAproxy: %[ssl\_fc\_session\_id,hex]                              |
| ssl\_client\_verify      | string | maybe    | HAproxy: %[ssl\_c\_verify]                                        |
| ssl\_client\_dn          | string | maybe    | HAproxy: %\{+Q\}[ssl\_c\_s\_dn]                                   |
| ssl\_client\_cn          | string | maybe    | HAproxy: %\{+Q\}[ssl\_c\_s\_dn(cn)]                               |
| ssl\_issuer              | string | maybe    | HAproxy: %\{+Q\}[ssl\_c\_i\_dn]                                   |
| ssl\_client\_not\_before | string | maybe    | HAproxy: %\{+Q\}[ssl\_c\_notbefore]                               |
| ssl\_client\_not\_after  | string | maybe    | HAproxy: %\{+Q\}[ssl\_c\_notafter]                                |
| ssl\_subject\_dn         | string | maybe    | HAproxy: %\{+Q\}[ssl\_c\_s\_dn]                                   |
| ssl\_issuer\_dn          | string | maybe    | HAproxy: %\{+Q\}[ssl\_c\_i\_dn]                                   |
| ssl\_client\_subject\_dn | string | maybe    | HAproxy: %\{+Q\}[ssl\_c\_s\_dn]                                   |
| ssl\_client\_issuer\_dn  | string | maybe    | HAproxy: %\{+Q\}[ssl\_c\_i\_dn]                                   |
| ssl\_protocol            | string | maybe    | HAproxy: %[ssl\_fc\_protocol]                                     |
| ssl\_cipher              | string | maybe    | HAproxy: %[ssl\_fc\_cipher]                                       |

:::note
TLS-related values may be retrieved from Nginx and as a fallback tried to be retrieved from HAproxy headers.
:::

:::tip
It is always a good idea to check the value of a request field, before using it.
:::

### Features

A Lua feature script must provide the following function:

```lua
---@param request table
---@return number, number, number
function nauthilus_call_feature(request)
  return trigger, skip_flag, failure_info -- See details below
end
```

:::important
It must return three values: The trigger state, a flag that indicates, if other features shall be skipped and a third value
which is an indicator for errors that occurred in the script itself.
:::

#### Constants for the returned result

| Constant                        | Meaning                                                         | Value | Category      |
|---------------------------------|-----------------------------------------------------------------|-------|---------------|
| nauthilus.FEATURE\_TRIGGER\_NO  | The feature has not been triggered                              | 0     | trigger       |
| nauthilus.FEATURE\_TRIGGER\_YES | The feature has been triggered and the request must be rejected | 1     | trigger       |
| nauthilus.FEATURES\_ABORT\_NO   | Process other built-in features                                 | 0     | skip\_flag    |
| nauthilus.FEATURES\_ABORT\_YES  | After finishing the script, skip all other built-in features    | 1     | skip\_flag    |
| nauthilus.FEATURE\_RESULT\_OK   | The script finished without errors                              | 0     | failure\_info |
| nauthilus.FEATURE\_RESULT\_FAIL | Something went wrong while executing the script                 | 1     | failure\_info |

### Request fields

Only common request fields are present.

### Filters

A Lua filter script must provide the following function:

```lua
---@param request table
---@return number, number, number
function nauthilus_call_filter(request)
  if request.authenticated then
    -- do something
  end
  
  return filter_action, failure_info -- See details below
end
```

:::important
It must return three values: The trigger state, a flag that indicates, if other features shall be skipped and a third value
which is an indicator for errors that occurred in the script itself.
:::

#### Constants for the returned result

| Constant                         | Meaning                                         | Value | Category       |
|----------------------------------|-------------------------------------------------|-------|----------------|
| nauthilus.FILTER\_ACTION\_ACCEPT | The request must be accepted                    | 0     | filter\_action |
| nauthilus.FILTER\_ACTION\_REJECT | The request has to be rejected                  | 1     | filter\_action |
| nauthilus.FILTER\_RESULT\_OK     | The script finished without errors              | 0     | filter\_info   |
| nauthilus.FILTER\_RESULT\_FAIL   | Something went wrong while executing the script | 1     | filter\_info   |

### Request fields

Only common request fields are present.

### Actions (including post)

A Lua action script must provide the following function:

```lua
---@param request table
---@return number
function nauthilus_call_action(request)
  if request.no_auth then
    -- Example post action: Store request information in database
  end

  return failure_info -- See details below
end
```

:::important
Actions must return the script status constant.
:::

#### Constants for the returned result

| Constant                       | Meaning                            | Value | Category      |
|--------------------------------|------------------------------------|-------|---------------|
| nauthilus.ACTION\_RESULT\_OK   | The script finished without errors | 0     | failure\_info |
| nauthilus.ACTION\_RESULT\_FAIL | The script finished with errors    | 1     | failure\_info |

### Request fields

Only common request fields are available.

### Lua Backend

The Lua backend script must provide the following function:

```lua
---@param request table
---@return number, userdata
function nauthilus_backend_verify_password(request)
  local backend_result_object = backend_result:new()
  -- Do something with backend_result_object
  
  return failure_info, backend_result_object -- See details below
end
```

For user account listing, the following function is required:

```lua
---@param request table
------@return number, table
function nauthilus_backend_list_accounts(request)
  local accounts = {}
  
  return failure_info, accounts -- See details below
end
```

If you plan on adding TOTP-keys for your users, you must provide the follwing function:

```lua
---@param request table
---@return number
function nauthilus_backend_add_totp(request)
  return failure_info -- See details below
end
```

:::important
The backend must return the result status constant and a backend result object
:::

#### Constants for the returned result

| Constant                        | Meaning                            | Value | Category      |
|---------------------------------|------------------------------------|-------|---------------|
| nauthilus.BACKEND\_RESULT\_OK   | The script finished without errors | 0     | failure\_info |
| nauthilus.BACKEND\_RESULT\_FAIL | The script finished with errors    | 1     | failure\_info |

### Request fields

### Function nauthilus\_backend\_verify\_password request fields

Only common request fields are used.

### Function nauthilus\_backend\_list\_accounts request fields

Only "debug" and "session" from the common requests are available.

#### Function nauthilus\_backend\_add\_totp request fields

Only "debug" and "session" from the common requests as well as "totp\_secret" (string)  are available.

## UserData object backend\_result

The **backend\_result** object can be initialized in the Lua backend and in Lua filters. The following methods exist:

### backend

| Name                    | Meaning                                                                                      |
|-------------------------|----------------------------------------------------------------------------------------------|
| authenticated           | Set or get the authentication status                                                         |
| user\_found             | Set or get the user found flag which indicated, if the backend found the user                |
| account\_field          | Set or get the account field name, which must have been added to a list of result attributes |
| totp\_secret\_field     | Set or get the TOTP secret field name, which must have been added to the result attributes   |
| totp\_recovery\_field   | Not yet implemented                                                                          |
| unique\_user\_id\_field | Set or get the unique user id field, which must have been added to the result attributes     |
| display\_name\_field    | Set or get the display name field, which must have been added to the result attributes       |
| attributes              | Set or get the result attributes as a Lua table                                              |

### filters

Filters only have an "attributes" method. While Lua backends do return a **backend\_result** directly, filters can only
apply it with a Lua function called "nauthilus.apply\_backend\_result(backend\_result\_object)".

Attributes can not overwrite existing attributes!

### Example usage for backend\_result

```lua
local attributes = {}
attributes["account"] = "bob"

local b = backend_result.new()
b:attributes(attributes) -- Add the table
b:account_field("account") -- Attributes contain a key "account" for the account field
b:authenticated(true) -- User is authenticated
b:user_found(true) -- The user was found
```

#### Endpoints /api/v1/mail/dovecot, /api/v1/generic/user and /api/v1/generic/json

"attributes" represent a common result store for a backend query. All fields that have been set by \*\_field methods will be
used for further internal processing, while all other attributes will be converted to HTTP-response-headers, which will be
sent back to the client application that talked to Nauthilus. These headeres will be prefixed with **X-NAuthilus-**.

For the generic endpoints, "attributes" will bew returned in the JSON respone.

# API

## Context

### nauthilus.context\_set
Add a value to the shared Lua context. Values can be strings, numbers, booleans and tables. You can not add functions here.

```lua
nauthilus.context_set("key", value)
```

Get a Lua context value:

### nauthilus.context\_get

```lua
local value = nauthilus.context_get("key")
```

If there is no result, nil is returned.

### nauthilus.context\_delete

To delete a key/value pair from the Lua context, use the following function:

```lua
nauthilus.context_delete("key")
```

## Redis

There is basic Redis support in Nauthilus. Most of the time it should be sufficient to use simple Redis keys and string values
as arguments. Type conversion can be done within Lua itself.

### nauthilus.redis\_set\_str

You can store a string value in Redis with the following function:

```lua
local result, error = nauthilus.redis_set("key", "value")
```

If anything went fine, "OK" is returned as **result**. In cases of errors, the **result** equals nil and a string is returned as **error**.

### nauthilus.redis\_incr

You can increment a value in Redis with the following function:

```lua
local number, error = nauthilus.redis_incr("key")
```

If anything went fine, the current **number** is returned. In cases of an **error**, number equals nil and a string is returned.

### nauthilus.redis\_get\_str

To retrieve a value from Redis use the following function:

```lua
local result, error = nauthilus.redis_get_str("key")
```

If anything went fine, the returned value is stored in **result**. In cases of errors, the **result** equals nil and a string is returned to **error*.

### nauthilus.redis\_expire

A Redis key can have an expiration time in seconds. Use the following function to achieve this goal:

```lua
local result, error = nauthilus.redis_expire("key")
```

If anything went fine, "OK" is returned as **result**. In cases of errors, the **result** equals nil and a string is returned as **error**.

### nauthilus.redis\_del

To delete a Redis key, use the following function:

```lua
local result, error = nauthilus.redis_del("key")
```
If anything went fine, "OK" is returned as **result**. In cases of errors, the **result** equals nil and a string is returned as **error**.

## Generic Lua functions

### nauthilus.status\_message\_set

If a client request should be rejected, you can overwrite the returned status message with the following function:

```lua
nauthilus.status_message_set("Reject message here")
```

### nauthilus.get\_all\_http\_request\_headers

It is possible to get the full set of HTTP request headers from a connecting service in Lua with the following function:

```lua
local header_table = nauthilus.get_all_http_request_headers()

for header_key, header_value_table in pair(header_table) do
  print("header key: " .. header_key)
  for index, header_value in ipars(header_value_table) do
    print("header_value[" .. tostring(index) .. "]: " .. header_value)
  end
end 
```

As the example demonstrates, the result is a Lua table. The names for each header are stored in the key of this table, while the values
are also stored in a Lua table as list of strings.

### nauthilus.custom\_log\_add

This function adds key-value pairs to the result log. In case of **features*, **backend** and **filters**, the logs are all added to the final result log line.
In cases of **actions**, logging is appended to the **action** log line. The reason is simple: Actions may run asynchronous to the main request, which
might already have been closed.

You cann call this function as many times as you like. Even with same key-value pairs.

:::note
Logs can not be removed if once set!
:::

```lua
nauthilus.custom_log_add("key", value)
```

A **value** can be a string, number or boolean. Anything else is replaced as "UNSUPPORTED".

## Feature backend\_server\_monitoring enabled

If the feature **backend\_server\_monitoring is turned on, the following functions are available in **filters**:

### nauthilus.get\_backend\_servers

This function returns a **backend\_server** UserData object. 

Usage example:

```lua
local backend_servers = nauthilus.get_backend_servers()

  ---@type table
  local valid_servers = {}

  for _, server in ipairs(backend_servers) do
    -- server.ip
    -- server.port
    -- server.protocol
    -- server.haproxy_v2
    -- server.tls
    -- You may select only HAproxy enabled backends... server.haproxy_v2
    table.insert(valid_servers, server)
  end
```

### nauthilus.select\_backend\_server

If you use the Nginx endpoint in NAuthilus, you can select a backend server with this function:

```lua
-- See nauthilus.get_backend_servers above!
local server = valid_servers[some_number] -- You must define some logic on how to chose a backend server from the list

nauthilus.select_backend_server(server.ip, server.port)
```

This will return the appropriate HTTP response header **Auth-Server** and **Auth-Port**

If you use a different endpoint, you may add the result to the attributes. In case of Dovecot this might look loke this (untested):

```lua
local b = backend_result:new()
local attributes = {}
-- See nauthilus.get_backend_servers above!
local server = valid_servers[some_number] -- You must define some logic on how to chose a backend server from the list

attributes["hostip"] = server.ip
b:attributes(attributes)
nauthilus.apply_backend_result(backend_result)
```

The result will be available as HTTP-response header **X-Nauthilus-Hostip** and can easily be parsed in a Dovecot Lua backend.

This example lacks persistent routing from users to backend servers. But it is a good starting point. Combine it with Redis or
SQL databases...

### nauthilus.check\_backend\_connection

Before using a backend server, you could double-check with the following function:

```lua
local server_ip = "10.10.10.10"
local server_port = 993
local is_haproxy_v2 = true
local uses_tls = true

local error = nauthilus.check_backend_connection(server_ip, server_port, is_haproxy_v2, uses_tls)
```
If anything went fine, **error** equals nil, else it stores a string with an error message.

:::warning
Normally you should not do this, as this will open a connection for each client  request!
:::

## Backend LDAP used

It is possible to send LDAP search requests to the main LDAP worker pool, if the **ldap** backend is enabled.

### nauthilus.ldap\_search

The LDAP search function receives a Lua table with the search request and returns a result table and an error stirng.

```lua
local user = "bob"

local result, error = nauthilus.ldap_search({
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

## Additional notes

Nauthilus uses the gopher-lua-libs library in all Lua scripts. Please have a look at their documentation for all the modules
that can directly be used in Nauthilus scripts:

[gopher-lua-libs on Github](https://github.com/vadv/gopher-lua-libs)