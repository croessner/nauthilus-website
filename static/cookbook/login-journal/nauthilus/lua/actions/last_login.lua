-- actions/last_login.lua
-- POST-action of the "Login journal" recipe. Nauthilus runs it after the answer has been sent, once for every
-- authentication request, so it cannot slow down or change a login. For every successful login it records:
--   cookbook:last_login:<account>   hash with time, client_ip, protocol of the latest login
--   cookbook:logins:<account>       list of the last 10 logins, newest first
-- Helpdesk question "when did bob last log in, and from where?" -> valkey-cli HGETALL cookbook:last_login:bob

local nauthilus_redis = require("nauthilus_redis")

local HISTORY_LENGTH = 10

function nauthilus_call_action(request)
    if not request.authenticated then
        return nauthilus_builtin.ACTION_RESULT_OK
    end

    local account = request.account

    if account == nil or account == "" then
        account = request.username
    end

    local now = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local protocol = request.protocol or "unknown"
    local client_ip = request.client_ip or "unknown"

    local last_key = "cookbook:last_login:" .. account
    local history_key = "cookbook:logins:" .. account

    nauthilus_redis.redis_hset("default", last_key, "time", now)
    nauthilus_redis.redis_hset("default", last_key, "client_ip", client_ip)
    nauthilus_redis.redis_hset("default", last_key, "protocol", protocol)

    local length = nauthilus_redis.redis_lpush("default", history_key, table.concat({ now, client_ip, protocol }, " "))

    -- Keep only the newest entries: drop the oldest ones from the end of the list.
    while length ~= nil and length > HISTORY_LENGTH do
        nauthilus_redis.redis_rpop("default", history_key)
        length = length - 1
    end

    return nauthilus_builtin.ACTION_RESULT_OK
end
