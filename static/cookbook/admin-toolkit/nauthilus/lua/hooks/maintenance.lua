-- hooks/maintenance.lua
-- Custom hook of the "Admin toolkit" recipe, served at /api/v1/custom/maintenance.
--   GET                                        shows the current state
--   POST {"enabled": true, "message": "..."}   switches maintenance mode on
--   POST {"enabled": false}                    switches it off
-- The environment source environment/maintenance.lua reads the same Redis hash for every login.

local json = require("json")
local nauthilus_redis = require("nauthilus_redis")
local nauthilus_http_request = require("nauthilus_http_request")
local toolkit = require("admin_toolkit")

-- read_state returns the maintenance hash as a table; an empty table means "off".
local function read_state()
    local state, err = nauthilus_redis.redis_hgetall("default", toolkit.KEY_MAINTENANCE)

    if err ~= nil then
        error(err)
    end

    return state or {}
end

-- describe turns the stored hash into the JSON answer of the hook.
local function describe(state)
    return {
        enabled = state.message ~= nil,
        message = state.message,
        since = state.since,
    }
end

function nauthilus_run_hook(request)
    if nauthilus_http_request.get_http_method() == "GET" then
        return describe(read_state())
    end

    local ok, body = pcall(json.decode, nauthilus_http_request.get_http_request_body() or "")

    if not ok or type(body) ~= "table" or type(body.enabled) ~= "boolean" then
        return toolkit.reply_error(400, { error = 'expected a JSON body like {"enabled": true, "message": "..."}' })
    end

    if body.enabled then
        local message = body.message or "Maintenance in progress, please try again later"

        nauthilus_redis.redis_hset("default", toolkit.KEY_MAINTENANCE, "message", message)
        nauthilus_redis.redis_hset("default", toolkit.KEY_MAINTENANCE, "since", os.date("!%Y-%m-%dT%H:%M:%SZ"))
    else
        nauthilus_redis.redis_del("default", toolkit.KEY_MAINTENANCE)
    end

    return describe(read_state())
end
