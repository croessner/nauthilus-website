---
title: Lua Backend
description: Lua backend configuration in Nauthilus
keywords: [Configuration, Lua, Backend]
sidebar_position: 7
---

# Lua Backend

The Lua backend allows Nauthilus to authenticate users using custom Lua scripts. This provides a flexible way to integrate with various data sources and implement custom authentication logic.

The Lua backend is described in detail in the [Lua API](/docs/lua-api/introduction).

## Configuration Options

### lua::features

Features are scripts that are run before the actual authentication process is taken. A Lua feature has a name and a script 
path.

Scripts are run in order and the first script that triggers, aborts the execution for all remaining scripts.

#### Definition of a "feature" list

| Key          | Required | Description                         | Example |
|--------------|:--------:|-------------------------------------|---------|
| name         |   yes    | A unique name for the Lua feature   | demo    |
| script\_path |   yes    | Full path to the Lua feature script | -       |

### lua::filters

Filters run after all backends have completed their work. A filter can override the existing result of an authentication request.
The idea is to have some post checks (maybe remote REST calls, database queries...) that will lead to a different final result.

It is important that script honor the backend result, if they do not wish to change it! In that case they **must** pass
the same result back to Nauthilus.

#### Definition of a "filter" list

| Key          | Required | Description                         | Example       |
|--------------|:--------:|-------------------------------------|---------------|
| name         |   yes    | A unique name for the Lua feature   | geoip-policyd |
| script\_path |   yes    | Full path to the Lua feature script | -             |

### lua::actions

Actions have a type and script path element for each Lua script. An incoming request is waiting for all actions to be 
completed except of **post** actions. The latter run afterward, when the client already may have been disconnected.

#### Definition of an "actions" list

| Key          | Required | Description                                     | Example     |
|--------------|:--------:|-------------------------------------------------|-------------|
| type         |   yes    | The type of action. Can be repeated many times. | brute_force |
| name         |   yes    | A unique name for the Lua action                | logging     |
| script\_path |   yes    | Full path to the Lua action script              | -           |

The following **type**s are known:

| Type            | Description                                                                    |
|-----------------|--------------------------------------------------------------------------------|
| brute\_force    | Run after a brute force attack has been detected                               |
| rbl             | Runs after a requesting client IP was found on a real time blackhole list.     |
| tls\_encryption | Runs, if a client connection was not encrypted.                                |
| relay\_domains  | Runs, if the login name equals an e-mail address and the domain is not served. |
| lua             | Runs, if any of the Lua features triggered.                                    |
| post            | Run always in background after the request already finished.                   |

### lua::custom_hooks

Custom hooks allow you to define HTTP endpoints that execute Lua scripts. When JWT authentication is enabled, you can restrict access to these endpoints based on user roles.

#### Definition of a "custom_hooks" list

| Key           | Required | Description                                                                 | Example                                       |
|---------------|:--------:|-----------------------------------------------------------------------------|-----------------------------------------------|
| http_location |   yes    | The URL path for the hook (relative to /api/v1/custom/)                     | status                                        |
| http_method   |   yes    | The HTTP method for the hook (GET, POST, PUT, DELETE, PATCH)                | GET                                           |
| script_path   |   yes    | Full path to the Lua script that will be executed                           | /etc/nauthilus/lua-plugins.d/hooks/status.lua |
| roles         |    no    | List of roles that are allowed to access this hook when JWT auth is enabled | ["admin", "monitoring"]                       |

Example configuration:

```yaml
lua:
  custom_hooks:
    - http_location: "status"
      http_method: "GET"
      script_path: "/etc/nauthilus/lua-plugins.d/hooks/status_check.lua"
      roles: ["admin", "monitoring"]
    - http_location: "user-info"
      http_method: "GET"
      script_path: "/etc/nauthilus/lua-plugins.d/hooks/user_info.lua"
      roles: ["user_info"]
```

When JWT authentication is enabled, the roles specified for a hook are checked against the roles in the user's JWT token. If the user doesn't have any of the required roles, the request is rejected with a 403 Forbidden status.

If no roles are specified for a hook, any authenticated user can access it when JWT is enabled.

### lua::config

| Key                    | Required | Description                                  | Example                                       |
|------------------------|:--------:|----------------------------------------------|-----------------------------------------------|
| backend\_script\_path  |   yes    | Full path to the Lua backend script          | ./server/lua-plugins.d/backend/backend.lua    |
| init\_script\_path     |    no    | Full path to the Lua initialization script   | ./server/lua-plugins.d/init/init.lua          |
| package_path           |    no    | Set a Lua module path for custom Lua modules | /usr/local/etc/nauthilus/lualib/?.lua         |
| number\_of\_workers    |    no    | Number of Lua workers to use                 | 10                                            |

### lua::optional_lua_backends

_New in version 1.5.0_

This section allows you to define additional Lua backends with different configurations. This is useful when you need to use multiple Lua backends with different settings.

```yaml
lua:
  optional_lua_backends:
    backend1:
      number_of_workers: 5
    backend2:
      number_of_workers: 3
```

You can then reference these backends in your search configurations using the `backend_name` parameter:

```yaml
lua:
  search:
    - protocol: imap
      cache_name: dovecot
      backend_name: backend1
```

:::note
The **callback** script can be used to provide additional information. If you use Dovecot, you might use this script to
track a users' session and cleanup things on Redis. Look at the callback.lua script that is bundled with Nauthilus.
:::

### lua::search

This section defines blocks that combine protocols and Redis cache namespaces. Here is a table of keys that are known:

#### Definition of a "search" list

| Key           | Required | Description                                                                                                | Example  |
|---------------|:--------:|------------------------------------------------------------------------------------------------------------|----------|
| protocol      |   yes    | A protocol name or a list of protocols in YAML format                                                      | imap     |
| cache\_name   |    no    | A namespace for the Redis cache                                                                            | dovecot  |
| backend\_name |    no    | The name of the Lua backend to use for this search. If not specified, the default backend is used.         | backend1 |

## Example Configuration

```yaml
lua:
  features:
    - name: demo
      script_path: ./server/lua-plugins.d/features/demo.lua
    - name: comm
      script_path: ./server/lua-plugins.d/features/comm.lua

  filters:
    - name: geoip-policyd
      script_path: /some/path/to/lua/script.lua

  actions:
    - type: brute_force
      name: brute_force
      script_path: ./server/lua-plugins.d/actions/bruteforce.lua
    - type: post
      name: demoe
      script_path: ./server/lua-plugins.d/actions/demo.lua
    - type: post
      name: haveibeenpwnd
      script_path: ./server/lua-plugins.d/actions/haveibeenpwnd.lua
    - type: post
      name: telegram
      script_path: ./server/lua-plugins.d/actions/telegram.lua

  config:
    script_path: ./server/lua-plugins.d/backend/backend.lua

  search:
    - protocol:
        - imap
        - pop3
        - lmtp
        - sieve
        - doveadm
        - indexer-worker
        - default
      cache_name: dovecot

    - protocol:
        - smtp
        - submission
      cache_name: submission

    - protocol: ory-hydra
      cache_name: oidc
```

## Implementing a Lua Backend

To implement a Lua backend, you need to create a Lua script that implements the required functions. Here's a basic example:

```lua
-- Required modules
local nauthilus_util = require("nauthilus_util")

-- Load modules with dynamic_loader
dynamic_loader("nauthilus_password")
local nauthilus_password = require("nauthilus_password")

dynamic_loader("nauthilus_gll_db")
local db = require("db")

-- Database configuration
local config = {
    shared = true,
    max_connections = 100,
    read_only = false,
}

-- Required functions for a Lua backend
function nauthilus_backend_verify_password(request)
    local b = nauthilus_backend_result.new()

    -- Example: Connect to a database
    local mysql, err_open = db.open("mysql", "user:password@tcp(127.0.0.1)/database", config)
    nauthilus_util.if_error_raise(err_open)

    -- Query the database for the user
    local result, err_query = mysql:query(
        "SELECT account, password FROM users WHERE username = \"" .. request.username .. "\";"
    )
    nauthilus_util.if_error_raise(err_query)

    local attributes = {}

    for _, row in pairs(result.rows) do
        for id, name in pairs(result.columns) do
            if name == "password" then
                if not request.no_auth then
                    -- Compare the password (assuming encrypted passwords in the database)
                    local match, err = nauthilus_password.compare_passwords(row[id], request.password)
                    nauthilus_util.if_error_raise(err)

                    b:authenticated(match)
                end
            else
                if name == "account" then
                    b:account_field("account")
                    b:user_found(true)
                end

                attributes[name] = row[id]
            end
        end
    end

    b:attributes(attributes)

    return nauthilus_builtin.BACKEND_RESULT_OK, b
end

function nauthilus_backend_list_accounts()
    -- Connect to the database
    local mysql, err_open = db.open("mysql", "user:password@tcp(127.0.0.1)/database", config)
    nauthilus_util.if_error_raise(err_open)

    -- Query the database for accounts
    local result, err_query = mysql:query("SELECT account FROM users LIMIT 100;")
    nauthilus_util.if_error_raise(err_query)

    local accounts = {}

    for _, row in pairs(result.rows) do
        for id, _ in pairs(result.columns) do
            table.insert(accounts, row[id])
        end
    end

    return nauthilus_builtin.BACKEND_RESULT_OK, accounts
end

-- Optional function for adding TOTP secrets
function nauthilus_backend_add_totp(request)
    local mysql, err_open = db.open("mysql", "user:password@tcp(127.0.0.1)/database", config)
    nauthilus_util.if_error_raise(err_open)

    local _, err_exec = mysql:exec("UPDATE users SET totp_secret=\"" .. request.totp_secret .. "\" WHERE username=\"" .. request.username .. "\";")
    nauthilus_util.if_error_raise(err_exec)

    return nauthilus_builtin.BACKEND_RESULT_OK
end
```

For more details on implementing Lua backends, refer to the [Lua API documentation](/docs/lua-api/introduction).

## Implementing a Lua Feature

Features are scripts that run before the authentication process. Here's an example of a feature implementation:

```lua
-- Define a name for logging purposes
local N = "blocklist"

-- Define a constant for Prometheus metrics
local HCCR = "http_client_concurrent_requests_total"

function nauthilus_call_feature(request)
    -- Skip processing for non-auth requests
    if request.no_auth then
        return nauthilus_builtin.FEATURE_TRIGGER_NO, nauthilus_builtin.FEATURES_ABORT_NO, nauthilus_builtin.FEATURE_RESULT_YES
    end

    -- Load required modules
    local nauthilus_util = require("nauthilus_util")

    dynamic_loader("nauthilus_context")
    local nauthilus_context = require("nauthilus_context")

    dynamic_loader("nauthilus_prometheus")
    local nauthilus_prometheus = require("nauthilus_prometheus")

    dynamic_loader("nauthilus_gluahttp")
    local http = require("glua_http")

    dynamic_loader("nauthilus_gll_json")
    local json = require("json")

    -- Get result table from context
    local rt = nauthilus_context.context_get("rt")
    if rt == nil then
        rt = {}
    end

    -- Prepare request data
    local t = {
        ip = request.client_ip
    }

    local payload, json_encode_err = json.encode(t)
    nauthilus_util.if_error_raise(json_encode_err)

    -- Track metrics
    nauthilus_prometheus.increment_gauge(HCCR, { service = N })

    -- Make HTTP request to blocklist service
    local timer = nauthilus_prometheus.start_histogram_timer(N .. "_duration_seconds", { http = "post" })
    local result, request_err = http.post(os.getenv("BLOCKLIST_URL"), {
        timeout = "10s",
        headers = {
            Accept = "*/*",
            ["User-Agent"] = "Nauthilus",
            ["Content-Type"] = "application/json",
        },
        body = payload,
    })
    nauthilus_prometheus.stop_timer(timer)
    nauthilus_prometheus.decrement_gauge(HCCR, { service = N })
    nauthilus_util.if_error_raise(request_err)

    -- Check response status
    if result.status_code ~= 200 then
        nauthilus_util.if_error_raise(N .. "_status_code=" .. tostring(result.status_code))
    end

    -- Parse response
    local response, err_jdec = json.decode(result.body)
    nauthilus_util.if_error_raise(err_jdec)

    -- Handle error in response
    if response.error then
        return nauthilus_builtin.FEATURE_TRIGGER_NO, nauthilus_builtin.FEATURES_ABORT_NO, nauthilus_builtin.FEATURE_RESULT_FAILURE
    end

    -- If IP is found in blocklist, trigger the feature
    if response.found then
        -- Store result in context
        if nauthilus_util.is_table(rt) then
            rt.feature_blocklist = true
            nauthilus_context.context_set("rt", rt)
        end

        -- Add custom log entries
        nauthilus_builtin.custom_log_add(N .. "_ip", request.client_ip)
        nauthilus_builtin.status_message_set("IP address blocked")

        -- Return: trigger=yes, abort=yes, result=ok
        return nauthilus_builtin.FEATURE_TRIGGER_YES, nauthilus_builtin.FEATURES_ABORT_YES, nauthilus_builtin.FEATURE_RESULT_OK
    end

    -- Return: trigger=no, abort=no, result=ok
    return nauthilus_builtin.FEATURE_TRIGGER_NO, nauthilus_builtin.FEATURES_ABORT_NO, nauthilus_builtin.FEATURE_RESULT_OK
end
```

## Implementing a Lua Filter

Filters run after the authentication process and can override the result. Here's an example:

```lua
-- Define a name for logging purposes
local N = "geoippolicyd"

-- Define a constant for Prometheus metrics
local HCCR = "http_client_concurrent_requests_total"

function nauthilus_call_filter(request)
    -- Skip processing for non-auth requests
    if request.no_auth then
        return nauthilus_builtin.FILTER_ACCEPT, nauthilus_builtin.FILTER_RESULT_OK
    end

    local nauthilus_util = require("nauthilus_util")

    -- Check if the IP is routable
    local is_routable = false
    if request.client_ip then
        is_routable = nauthilus_util.is_routable_ip(request.client_ip)
    end

    -- Early termination for non-routable addresses
    if not is_routable then
        if request.authenticated then
            return nauthilus_builtin.FILTER_ACCEPT, nauthilus_builtin.FILTER_RESULT_OK
        else
            return nauthilus_builtin.FILTER_REJECT, nauthilus_builtin.FILTER_RESULT_OK
        end
    end

    -- Helper function to add custom logs
    local function add_custom_logs(object)
        for item, values in pairs(object) do
            if type(values) == "table" then
                local log_str = ""
                for _, value in pairs(values) do
                    if string.len(log_str) == 0 then
                        log_str = value
                    else
                        log_str = log_str .. "," .. value
                    end
                end
                nauthilus_builtin.custom_log_add(N .. "_" .. item, log_str)
            end
        end
    end

    -- Only proceed if authentication was successful
    if request.authenticated then
        dynamic_loader("nauthilus_context")
        local nauthilus_context = require("nauthilus_context")

        dynamic_loader("nauthilus_prometheus")
        local nauthilus_prometheus = require("nauthilus_prometheus")

        dynamic_loader("nauthilus_gluahttp")
        local http = require("glua_http")

        dynamic_loader("nauthilus_gll_json")
        local json = require("json")

        -- Prepare request data
        local t = {
            key = "client",
            value = {
                address = request.client_ip,
                sender = request.account
            }
        }

        local payload, json_encode_err = json.encode(t)
        nauthilus_util.if_error_raise(json_encode_err)

        -- Track metrics
        nauthilus_prometheus.increment_gauge(HCCR, { service = N })

        -- Make HTTP request to GeoIP policy service
        local timer = nauthilus_prometheus.start_histogram_timer(N .. "_duration_seconds", { http = "post" })
        local result, request_err = http.post(os.getenv("GEOIP_POLICY_URL"), {
            timeout = "10s",
            headers = {
                Accept = "*/*",
                ["User-Agent"] = "Nauthilus",
                ["Content-Type"] = "application/json",
            },
            body = payload,
        })
        nauthilus_prometheus.stop_timer(timer)
        nauthilus_prometheus.decrement_gauge(HCCR, { service = N })
        nauthilus_util.if_error_raise(request_err)

        -- Check response status
        if result.status_code ~= 202 then
            nauthilus_util.if_error_raise(N .. "_status_code=" .. tostring(result.status_code))
        end

        -- Parse response
        local response, err_jdec = json.decode(result.body)
        nauthilus_util.if_error_raise(err_jdec)

        -- Process response
        if response.err == nil then
            local current_iso_code = ""

            -- Add GUID to custom logs
            nauthilus_builtin.custom_log_add(N .. "_guid", response.guid)

            -- Process object data if present
            if response.object then
                add_custom_logs(response.object)

                -- If policy violation, reject the request
                if nauthilus_util.is_table(response.object) and response.object.policy_reject then
                    -- Track metrics
                    nauthilus_prometheus.increment_counter(N .. "_count", {
                        country = current_iso_code,
                        status = "reject",
                    })

                    -- Add to custom logs
                    nauthilus_builtin.custom_log_add(N, "blocked")

                    -- Store result in context
                    local rt = nauthilus_context.context_get("rt")
                    if rt == nil then
                        rt = {}
                    end
                    if nauthilus_util.is_table(rt) then
                        rt.filter_geoippolicyd = true
                        nauthilus_context.context_set("rt", rt)
                    end

                    -- Set status message
                    nauthilus_builtin.status_message_set("Policy violation")

                    -- Reject the request
                    return nauthilus_builtin.FILTER_REJECT, nauthilus_builtin.FILTER_RESULT_OK
                end

                -- Track metrics for accepted requests
                nauthilus_prometheus.increment_counter(N .. "_count", {
                    country = current_iso_code,
                    status = "accept",
                })
            end
        else
            -- Return failure if there was an error
            return nauthilus_builtin.FILTER_ACCEPT, nauthilus_builtin.FILTER_RESULT_FAIL
        end
    else
        -- Reject if authentication failed
        return nauthilus_builtin.FILTER_REJECT, nauthilus_builtin.FILTER_RESULT_OK
    end

    -- Accept the request by default
    return nauthilus_builtin.FILTER_ACCEPT, nauthilus_builtin.FILTER_RESULT_OK
end
```

## Implementing a Lua Action

Actions run in response to specific events. Here's an example:

```lua
-- Load required modules
local nauthilus_util = require("nauthilus_util")

dynamic_loader("nauthilus_context")
local nauthilus_context = require("nauthilus_context")

dynamic_loader("nauthilus_gll_tcp")
local tcp = require("tcp")

function nauthilus_call_action(request)
    -- Connect to HAProxy stats socket
    local conn, err = tcp.open(os.getenv('HAPROXY_STATS'))

    -- Add IP to appropriate block map based on protocol
    if request.protocol == "smtps" or request.protocol == "submission" then
        -- Use smtp-sink map for email protocols
        err = conn:write("add map " .. os.getenv('HAPROXY_SMTP_MAP') .. " " .. request.client_net .. " block_smtp\n")
    else
        -- Use generic map for other protocols
        err = conn:write("add map " .. os.getenv('HAPROXY_GENERIC_MAP') .. " " .. request.client_net .. " block_" .. request.protocol .. "\n")
    end

    -- Handle errors
    nauthilus_util.if_error_raise(err)

    -- Store result in context
    local rt = nauthilus_context.context_get("rt")
    if rt == nil then
        rt = {}
    end
    if nauthilus_util.is_table(rt) then
        rt.brute_force_haproxy = true
        nauthilus_context.context_set("rt", rt)
    end

    -- Return success
    return nauthilus_builtin.ACTION_RESULT_OK
end
```

## Implementing a Lua Custom Hook

Custom hooks provide HTTP endpoints that execute Lua scripts. Here's an example:

```lua
-- Load required modules
local nauthilus_util = require("nauthilus_util")

dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

dynamic_loader("nauthilus_http_request")
local nauthilus_http_request = require("nauthilus_http_request")

dynamic_loader("nauthilus_gll_json")
local json = require("json")

-- Define a name for logging purposes
local N = "callback"

-- Define categories to process
local CATEGORIES = {
    ["service:imap-login"] = true,
    ["service:pop3-login"] = true,
    ["service:lmtp"] = true,
    ["service:managesieve-login"] = true,
}

function nauthilus_run_hook(logging, session)
    -- Initialize result table
    local result = {
        level = "info",
        caller = N .. ".lua",
        session = session
    }

    -- Get Redis connection
    local custom_pool = "default"
    local custom_pool_name = os.getenv("CUSTOM_REDIS_POOL_NAME")
    if custom_pool_name ~= nil and custom_pool_name ~= "" then
        local err_redis_client
        custom_pool, err_redis_client = nauthilus_redis.get_redis_connection(custom_pool_name)
        nauthilus_util.if_error_raise(err_redis_client)
    end

    -- Verify content type
    local header = nauthilus_http_request.get_http_request_header("Content-Type")
    local body = nauthilus_http_request.get_http_request_body()

    if nauthilus_util.table_length(header) == 0 or header[1] ~= "application/json" then
        nauthilus_util.print_result(logging, result, "HTTP request header: Wrong 'Content-Type'")
        return
    end

    -- Parse JSON body
    local body_table, err_jdec = json.decode(body)
    nauthilus_util.if_error_raise(err_jdec)

    if not nauthilus_util.is_table(body_table) then
        nauthilus_util.print_result(logging, result, "HTTP request body: Result is not a table")
        return
    end

    -- Process the request
    result.state = "client disconnected"

    -- Extract information from the request
    for k, v in pairs(body_table) do
        if k == "categories" and nauthilus_util.is_table(v) then
            for _, category in ipairs(v) do
                if CATEGORIES[category] then
                    result.category = category
                end
            end
        elseif k == "fields" and nauthilus_util.is_table(v) then
            for field_name, field_value in pairs(v) do
                if field_name == "user" then
                    result.user = field_value
                elseif field_name == "remote_ip" then
                    result.remote_ip = field_value
                elseif field_name == "remote_port" then
                    result.remote_port = field_value
                end
            end
        end
    end

    -- Process the category if it's one we care about
    if CATEGORIES[result.category] then
        local target = result.remote_ip .. ":" .. result.remote_port

        -- Clean up Redis entries
        local account, err_redis_hget = nauthilus_redis.redis_hget(custom_pool, "ntc:DS_ACCOUNT", target)
        if not err_redis_hget and account then
            local _, err_redis_hdel = nauthilus_redis.redis_hdel(custom_pool, "ntc:DS_ACCOUNT", target)
            if not err_redis_hdel then
                -- Clean up session data
                local redis_key = "ntc:DS:" .. account
                local _, err_redis_hdel = nauthilus_redis.redis_hdel(custom_pool, redis_key, target)
                if err_redis_hdel then
                    result.remove_dovecot_target_error = err_redis_hdel
                end
            end
        end

        -- Log the result if debug or info level is enabled
        if logging.log_level == "debug" or logging.log_level == "info" then
            nauthilus_util.print_result(logging, result)
        end
    end

    return result
end
```

For more details on implementing Lua components, refer to the [Lua API documentation](/docs/lua-api/introduction).
