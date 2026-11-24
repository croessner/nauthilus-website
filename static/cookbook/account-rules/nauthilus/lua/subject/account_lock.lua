-- subject/account_lock.lua
-- Subject source of the "Account rules" recipe. An administrator locks an account for a while, for example during
-- offboarding or after a phishing incident, by writing a Redis hash:
--   valkey-cli HSET cookbook:lock:bob until 2030-01-01T00:00:00Z reason "offboarding"
-- Until that time every login of the account is refused, even with the right password. After the time has passed
-- the lock is ignored and the script deletes it.

local nauthilus_redis = require("nauthilus_redis")
local nauthilus_policy = require("nauthilus_policy")

-- parse_utc turns "2030-01-01T00:00:00Z" into seconds since 1970, or nil.
local function parse_utc(value)
    local year, month, day, hour, min, sec =
        string.match(value or "", "^(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d):(%d%d)Z$")

    if year == nil then
        return nil
    end

    -- Days from 1970-01-01 to the given date (proleptic Gregorian calendar).
    local y, m = tonumber(year), tonumber(month)

    if m <= 2 then
        y, m = y - 1, m + 12
    end

    local days = 365 * y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400)
        + math.floor((153 * (m - 3) + 2) / 5) + tonumber(day) - 719469

    return days * 86400 + tonumber(hour) * 3600 + tonumber(min) * 60 + tonumber(sec)
end

function nauthilus_call_subject(request)
    local account = request.account

    if account == nil or account == "" then
        account = request.username
    end

    local key = "cookbook:lock:" .. account
    local lock, err = nauthilus_redis.redis_hgetall("default", key)

    if err ~= nil then
        return nauthilus_builtin.SUBJECT_ACCEPT, nauthilus_builtin.SUBJECT_RESULT_FAIL
    end

    if lock == nil or lock["until"] == nil then
        return nauthilus_builtin.SUBJECT_ACCEPT, nauthilus_builtin.SUBJECT_RESULT_OK
    end

    local locked_until = parse_utc(lock["until"])

    if locked_until == nil or locked_until <= os.time() then
        nauthilus_redis.redis_del("default", key)

        return nauthilus_builtin.SUBJECT_ACCEPT, nauthilus_builtin.SUBJECT_RESULT_OK
    end

    nauthilus_builtin.custom_log_add("account_lock", lock.reason or "locked")
    nauthilus_policy.emit_attribute({ id = "lua.plugin.cookbook.lock.active", value = true })
    nauthilus_policy.emit_attribute({ id = "lua.plugin.cookbook.lock.until", value = lock["until"] })

    return nauthilus_builtin.SUBJECT_REJECT, nauthilus_builtin.SUBJECT_RESULT_OK
end
