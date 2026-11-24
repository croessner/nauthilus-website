-- hooks/blocklist.lua
-- Custom hook of the "Admin toolkit" recipe, served at /api/v1/custom/blocklist.
--   GET                                                      lists the blocked addresses and networks
--   POST {"add": ["198.51.100.0/24"], "remove": ["192.0.2.7"]}   changes the list
-- The environment source environment/ip_blocklist.lua checks every login against this list.

local json = require("json")
local nauthilus_redis = require("nauthilus_redis")
local nauthilus_http_request = require("nauthilus_http_request")
local toolkit = require("admin_toolkit")

-- list_entries returns the sorted members of the blocklist set.
local function list_entries()
    local members, err = nauthilus_redis.redis_smembers("default", toolkit.KEY_BLOCKLIST)

    if err ~= nil then
        error(err)
    end

    members = members or {}
    table.sort(members)

    return members
end

function nauthilus_run_hook(request)
    if nauthilus_http_request.get_http_method() == "GET" then
        return { entries = list_entries() }
    end

    local ok, body = pcall(json.decode, nauthilus_http_request.get_http_request_body() or "")

    if not ok or type(body) ~= "table" then
        return toolkit.reply_error(400, { error = 'expected a JSON body like {"add": ["198.51.100.0/24"], "remove": []}' })
    end

    -- Validate everything first, so a typo does not leave the list half changed.
    local invalid = {}

    for _, entry in ipairs(body.add or {}) do
        if toolkit.parse_network(entry) == nil then
            invalid[#invalid + 1] = entry
        end
    end

    if #invalid > 0 then
        return toolkit.reply_error(400, { error = "invalid IPv4 address or network", invalid = invalid })
    end

    for _, entry in ipairs(body.add or {}) do
        nauthilus_redis.redis_sadd("default", toolkit.KEY_BLOCKLIST, entry)
    end

    for _, entry in ipairs(body.remove or {}) do
        nauthilus_redis.redis_srem("default", toolkit.KEY_BLOCKLIST, entry)
    end

    return { entries = list_entries() }
end
