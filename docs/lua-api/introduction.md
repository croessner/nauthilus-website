---
title: Introduction
description: Introduction to the Nauthilus builtin Lua support
keywords: [Lua]
sidebar_position: 1
---
# Lua Support

Nauthilus has Lua 5.1 support in all areas of the service. To understand the interfaces, you must first get an idea of
what happens with an incoming authentication request.

## Authentication workflow

An incoming authentication request first enters the **brute\_force** check. After that it continues with the **environment**
stage. After that has passed, it continues to process the request in a **password backend**. When the final result for the
request was obtained, it passes **subject sources**.

Subject sources may change the backend result in one or the other way (accepting a formerly rejected message or vice versa). This
is especially useful for other remote services that can influence the authentication process.

After all this has finished, it is possible to do some **post actions**, which are run independent
of all other steps in the whole pipeline and therefore can not influence the final result anymore.

## Policy-aware action semantics

Nauthilus distinguishes synchronous Lua actions from Lua POST-Actions.

Synchronous Lua actions are configured with action types such as `brute_force`, `lua`, `tls_encryption`, `relay_domains`, and `rbl`. In policy-authoritative paths, the selected policy decision dispatches them through the registered obligation `auth.obligation.lua_action.dispatch` and Nauthilus waits for the action before the request continues.

The triggering check, environment control, or environment source only emits facts. The action runs only when the selected decision includes the dispatch obligation. This keeps reports, observe-mode comparisons, and mutable side effects aligned with the same policy decision.

Lua POST-Actions use the `post` action type. They run after the request-time decision context is known and must not change the final decision, response marker, response message, or FSM terminal state. In `auth.policy` authoritative paths, POST-Action enqueueing is requested through the registered obligation `auth.obligation.lua_post_action.enqueue`. Brute-force counter and learning updates are requested through `auth.obligation.brute_force.update`.

Observe-mode policy evaluation reports planned custom obligations but never executes them, so it does not dispatch synchronous Lua actions, enqueue custom POST-Actions, or mutate brute-force state.

In the following sequence diagram you can see the processing of the request in more detail.

```mermaid
sequenceDiagram
    actor User
    participant Request
    participant Checks as Policy checks
    participant Policy as Policy decision
    participant Obligations
    participant Backend
    participant Subjects as Subject sources
    participant Post as POST-Actions
    User->>Request: Wants to authenticate
    activate Request
    Note over Request,Subjects:A Lua context is created. Scripts can share data with set, get, and delete operations.
    Request->>Checks: Collect pre-auth facts
    activate Checks
    Checks->>Policy: Evaluate selected decision
    deactivate Checks
    activate Policy
    alt Selected decision has a synchronous Lua action obligation
    Policy->>Obligations: auth.obligation.lua_action.dispatch
    activate Obligations
    Obligations->>Obligations: Run the configured action and wait
    deactivate Obligations
    end
    alt Pre-auth terminal decision
    Policy-->>Request: Return deny or tempfail response
    else Request continues
    Policy->>Backend: Run the main authentication process
    end
    deactivate Policy
    activate Backend
    Backend->>Subjects: Give pre-result to the subject sources
    deactivate Backend
    activate Subjects
    Subjects->>Policy: Evaluate final decision
    activate Policy
    alt Selected decision has POST-Action obligation
    Policy->>Post: auth.obligation.lua_post_action.enqueue
    end
    Policy-->>Request: Return final response
    deactivate Policy
    deactivate Subjects
    deactivate Request
```

## Additional things to know

When starting the server, it is possible to call an init script, which may be used to register prometheus elements, start
connection tracker or define custom redis pools. The latter is interesting, if you prefer using other redis servers for all
your custom Lua scripts.

### While runtime...

When an incoming authentication request is started, a Lua context is created.

All parts of a request share that common request context. Lua scripts can set arbitrary data in the context and read/delete
things from there.

Lua scripts can modify the final log line by adding key-value pairs from each script.

---

## Configuration

For the configuration, please have a look at the [configuration file](../configuration/index.md) document.

---

## Lua components

Each component does provide a set of global functions, constants, ... and requires a well-defined response from each request.

Every Lua script that has been configured is pre-compiled and kept in memory for future use. To make script changes, you
must reload the service.

---

## Lua libraries

Nauthilus does automatically preload Lua modules.

This is the list of modules that are currently available:

| Loader name                                               | Description                                                                            |
|-----------------------------------------------------------|----------------------------------------------------------------------------------------|
| [nauthilus\_mail](/docs/lua-api/mail)                     | E-Mail functions                                                                       |
| [nauthilus\_password](/docs/lua-api/password)             | Password compare and validation functions                                              |
| [nauthilus\_redis](/docs/lua-api/redis)                   | Redis related functions                                                                |
| [nauthilus\_misc](/docs/lua-api/misc)                     | Country code and sleep functions                                                       |
| [nauthilus\_context](/docs/lua-api/context)               | Global Lua context accross all States in Nauthilus                                     |
| [nauthilus\_ldap](/docs/lua-api/ldap)                     | LDAP related functions                                                                 |
| [nauthilus\_backend](/docs/lua-api/backend)               | Backend related functions                                                              |
| [nauthilus\_http_request](/docs/lua-api/http)             | HTTP request header functions                                                          |
| [nauthilus\_http_response](/docs/lua-api/http-response)   | HTTP response functions (headers, status, body; environment/subject sources MUST NOT send a body) |
| [nauthilus\_prometheus](/docs/lua-api/prometheus)         | Prometheus metrics functions                                                           |
| [nauthilus\_soft\_whitelist](/docs/lua-api/softwhitelist) | Soft whitelist functions                                                               |
| [nauthilus\_brute\_force](/docs/lua-api/bruteforce)       | Brute force prevention functions                                                       |
| [nauthilus\_dns](/docs/lua-api/dns)                       | DNS related functions                                                                  |
| [nauthilus\_cache](/docs/lua-api/cache)                   | In-process cache functions                                                             |
| [nauthilus\_psnet](/docs/lua-api/psnet)                   | Network connection manager functions                                                   |
| [nauthilus\_opentelemetry](/docs/lua-api/opentelemetry)   | OpenTelemetry tracing functions                                                        |
| [nauthilus\_util](/docs/lua-api/nauthilus_util)           | Common utility functions                                                               |
| glua\_crypto                                              | gluacrpyto project on Github                                                           |
| glua\_http                                                | gluahttp project on Github                                                             |

In addition to these Nauthilus-specific modules, the [gopher-lua-libs](https://github.com/vadv/gopher-lua-libs) collection is automatically preloaded, providing access to modules like `json`, `yaml`, `time`, `db`, `tcp`, and more.

Example:

```lua
local nauthilus_redis = require("nauthilus_redis")

local nauthilus_builtin_context = require("nauthilus_context")

-- Gopher-Lua-Libs

local crypto = require("crypto")

local db = require("db")

local time = require("time")

-- Glua-Crypto

local crypto = require("glua_crypto") -- provides sha1 and others...
```

### Actions

Whenever a brute froce attack is recognized, **action**s may be called. The request will wait until all requests have
finished. Actions are processed by a central action worker. No results are returned to the regular request, so actions
in general do their own logging!

Lua actions run only when the selected policy decision dispatches the corresponding obligation. Synchronous actions wait for the worker to finish.

### Environment Sources

Lua environment sources run in the pre-auth phase alongside built-in checks such as geoip, rbl, tls\_encryption and relay\_domains. They are useful when the environment context itself should decide whether the request may continue. Lua environment sources
are executed in parallel starting with v1.8.9. As soon as any environment source has triggered, the request will reject the authentication process after all environment sources have finished, and the results are aggregated.

:::note Version change in 1.8.9
Since version 1.8.9, Lua environment and subject sources are executed in parallel. Nauthilus waits for all scripts to finish and then aggregates their results:
- Environment sources: triggered=true if any script reports ENVIRONMENT_TRIGGER_YES; abort flag is set if any script requests ENVIRONMENT_ABORT_YES; the first error aborts the whole operation; the first status_message set is used.
- Subject sources: an action is taken if any subject source requests it; backend_result attributes from multiple subject sources are merged (later keys overwrite earlier ones); remove-attributes are unioned; the first error aborts; the first status_message set is used.
Each script runs with its own Lua state and per-script timeout. Do not rely on execution order between scripts.
:::
Lua environment sources can return an abort flag to skip remaining built-in pre-auth checks.

### Lua backend

The Lua backend can be used for password checks and request modes such as no-auth, list-accounts, and TOTP-aware flows.

The backend can accept a request or reject it. It has full access to all meta information that are delivered from the
incoming request.

### Subject Sources

There may exist remote services that may be contacted after the main backend authentication proccess returned its first  
result. Think of something like GeoIP service or some IP white/blacklisting. Even a request that might have authenticated
correctly may be rejected to a policy violation from such a service. Therefor subject sources have the power to overwrite the
result from a backend.

You can also use subject sources to retrieve additional information from databases or LDAP and add additional attributes to the remaining result.
This is useful for setups, where Nauthilus may also take the role of a Dovecot proxy. Users may get routed to different
mail stores upon successful authentication. For this, you may retrieve the current backend server list with servers that have been
checked as being alive by backend health checks and select one for the current client request.

:::info
Subject sources never affect caching! This is important, because otherwise valid credentials might result in storing them in the
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

---

## Required functions and constants

Every Lua script must provide a pre-defined Lua function with a request parameter. Concerning the actual script, there is
a requried return statement.

Nauthilus will look for these functions and parses the results.

---

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
| client\_host             | string | maybe    | -                                                                 |
| client_net               | string | maybe    | Available in conjunction with brute-force-actions                 |
| client\_id               | string | maybe    | -                                                                 |
| user\_agent              | string | maybe    | -                                                                 |
| local\_ip                | string | always   | -                                                                 |
| local\_port              | string | always   | -                                                                 |
| username                 | string | always   | -                                                                 |
| account                  | string | maybe    | Subject and post actions                                          |
| unique\_user\_id         | string | maybe    | Used with OIDC subject                                            |
| display\_name            | string | maybe    | -                                                                 |
| password                 | string | always   | -                                                                 |
| protocol                 | string | always   | -                                                                 |
| brute\_force\_bucket     | string | maybe    | Available in conjunction with brute-force-actions                 |
| environment              | string | maybe    | In actions, if an environment source or control has triggered     |
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
| ssl\_serial              | string | maybe    | SSL certificate serial number                                     |
| ssl\_fingerprint         | string | maybe    | SSL certificate fingerprint                                       |
| brute\_force\_counter    | number | always   | Current brute force attempt counter                               |
| account\_field           | string | maybe    | The name of the field that contains the account                   |
| method                   | string | maybe    | HTTP method (e.g., "GET", "POST")                                 |
| oidc\_cid                | string | maybe    | OIDC Client ID                                                    |
| saml\_entity\_id         | string | maybe    | SAML Service Provider Entity ID                                   |
| grant\_type              | string | maybe    | OIDC grant/flow type (e.g. `authorization_code`, `device_code`)  |
| oidc\_client\_name       | string | maybe    | Human-readable OIDC client name                                  |
| redirect\_uri            | string | maybe    | OIDC redirect URI from current flow                              |
| mfa\_completed           | bool   | maybe    | Whether MFA was completed in current flow                        |
| mfa\_method              | string | maybe    | MFA method used (`totp`, `webauthn`, `recovery`)                |
| requested\_scopes        | table  | maybe    | Requested OIDC scopes as Lua table                               |
| user\_groups             | table  | maybe    | User group memberships (for example LDAP `memberOf`)             |
| allowed\_client\_scopes  | table  | maybe    | Scopes configured on current OIDC client                         |
| allowed\_client\_grant\_types | table | maybe | Grant types configured on current OIDC client                    |
| log\_format              | string | always   | Configured log format ("default" or "json")                       |
| log\_level               | string | always   | Configured log level                                              |
| logging                  | table  | always   | Table containing `log_format` and `log_level`                     |
| latency                  | number | always   | Request processing latency                                        |
| http\_status             | number | always   | HTTP status code returned to the client                           |
| redis\_prefix            | string | always   | Configured Redis key prefix                                       |

:::note
TLS-related values may be retrieved from Nginx and as a fallback tried to be retrieved from HAproxy headers.
:::

:::tip
It is always a good idea to check the value of a request field, before using it.
:::

### Environment Sources

A Lua environment source script must provide the following function:

```lua
---@param request table
---@return boolean, boolean, number
function nauthilus_call_environment(request)
  return triggered, abort, result -- See details below
end
```

:::important
It must return three values: the trigger state, an abort flag for remaining pre-auth checks, and the script result status.
:::

#### Constants for the returned result

| Constant                                | Meaning                                                         | Value | Category      |
|-----------------------------------------|-----------------------------------------------------------------|-------|---------------|
| nauthilus_builtin.ENVIRONMENT\_TRIGGER\_NO  | The environment source has not been triggered                              | false | trigger       |
| nauthilus_builtin.ENVIRONMENT\_TRIGGER\_YES | The environment source has been triggered and the request must be rejected | true  | trigger       |
| nauthilus_builtin.ENVIRONMENT\_ABORT\_NO   | Process other environment controls and sources                  | false | skip\_flag    |
| nauthilus_builtin.ENVIRONMENT\_ABORT\_YES  | After finishing the script, skip all other environment controls and sources | true  | skip\_flag    |
| nauthilus_builtin.ENVIRONMENT\_RESULT\_OK   | The script finished without errors                              | 0     | failure\_info |
| nauthilus_builtin.ENVIRONMENT\_RESULT\_FAIL | Something went wrong while executing the script                 | 1     | failure\_info |

### Request fields

Only common request fields are present.

### Subject Sources

A Lua subject source script must provide the following function:

```lua
---@param request table
---@return boolean, number
function nauthilus_call_subject(request)
  if request.authenticated then
    -- do something
  end

  return subject_action, result -- See details below
end
```

:::important
It must return two values: the subject action and the script result status.
:::

#### Constants for the returned result

| Constant                                 | Meaning                                         | Value | Category       |
|------------------------------------------|-------------------------------------------------|-------|----------------|
| nauthilus_builtin.SUBJECT\_ACCEPT         | The request must be accepted                    | false | subject\_action |
| nauthilus_builtin.SUBJECT\_REJECT         | The request has to be rejected                  | true  | subject\_action |
| nauthilus_builtin.SUBJECT\_RESULT\_OK     | The script finished without errors              | 0     | subject\_info   |
| nauthilus_builtin.SUBJECT\_RESULT\_FAIL   | Something went wrong while executing the script | 1     | subject\_info   |

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

| Constant                               | Meaning                            | Value | Category      |
|----------------------------------------|------------------------------------|-------|---------------|
| nauthilus_builtin.ACTION\_RESULT\_OK   | The script finished without errors | 0     | failure\_info |
| nauthilus_builtin.ACTION\_RESULT\_FAIL | The script finished with errors    | 1     | failure\_info |

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

| Constant                                | Meaning                            | Value | Category      |
|-----------------------------------------|------------------------------------|-------|---------------|
| nauthilus_builtin.BACKEND\_RESULT\_OK   | The script finished without errors | 0     | failure\_info |
| nauthilus_builtin.BACKEND\_RESULT\_FAIL | The script finished with errors    | 1     | failure\_info |

### Request fields

### Function nauthilus\_backend\_verify\_password request fields

Only common request fields are used.

### Function nauthilus\_backend\_list\_accounts request fields

Only "debug" and "session" from the common requests are available.

#### Function nauthilus\_backend\_add\_totp request fields

Only "debug" and "session" from the common requests as well as "totp\_secret" (string)  are available.

### Cache flush callback

If `auth.backends.lua.backend.default.cache_flush_script_path` is configured, Nauthilus executes a dedicated Lua callback during:

- `DELETE /api/v1/cache/flush`
- `DELETE /api/v1/cache/flush/async`

The script must provide:

```lua
---@param request table
---@return table|nil, string|nil
function nauthilus_cache_flush(request)
  local additional_keys = {
    request.redis_prefix .. ":custom:" .. request.username
  }

  local account_name = "account-value"

  return additional_keys, account_name
end
```

Return contract:

- First return value: `table` (array) with additional Redis keys to delete. Non-string items are ignored.
- Second return value: optional account name (`string`). If non-empty, Nauthilus skips account lookup and uses this value.

### Request fields

Common request fields are available. For cache flush calls, the following are guaranteed to be set:

- `request.username`: user name from the flush request payload
- `request.session`: generated request GUID
- `request.redis_prefix`: configured Redis prefix (`storage.redis.prefix`)

---

## UserData object backend\_result

The **nauthilus\_backend\_result** object can be initialized in the Lua backend and in Lua subject sources. The following methods exist:

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

### subject sources

Subject sources only have an "attributes" method. While Lua backends do return a **nauthlus\_backend\_result** directly, subject sources can only
apply it with a Lua function called "nauthilus_backend.apply\_backend\_result(backend\_result\_object)".

Attributes can not overwrite existing attributes!

### Example usage for nauthilus\_backend\_result

```lua
local attributes = {}
attributes["account"] = "bob"

local b = nauthilus_backend_result.new()
b:attributes(attributes) -- Add the table
b:account_field("account") -- Attributes contain a key "account" for the account field
b:authenticated(true) -- User is authenticated
b:user_found(true) -- The user was found
```

#### Endpoints /api/v1/mail/dovecot, /api/v1/generic/user and /api/v1/generic/json

"attributes" represent a common result store for a backend query. All fields that have been set by \*\_field methods will be
used for further internal processing, while all other attributes will be converted to HTTP-response-headers, which will be
sent back to the client application that talked to Nauthilus. These headeres will be prefixed with **X-Nauthilus-**.

For the generic endpoints, "attributes" will bew returned in the JSON respone.

---

## Additional notes

Nauthilus uses the gopher-lua-libs library in all Lua scripts. Please have a look at their documentation for all the modules
that can directly be used in Nauthilus scripts:

[gopher-lua-libs on Github](https://github.com/vadv/gopher-lua-libs)
