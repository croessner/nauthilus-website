-- environment/ip_blocklist.lua
-- Environment source of the "Admin toolkit" recipe. It finds logins from addresses and networks that an
-- administrator put on the blocklist with the blocklist hook. It emits the registered attribute
-- lua.plugin.cookbook.blocklist.matched, and the policy rule blocklist_deny in nauthilus.yml rejects the login.

local nauthilus_redis = require("nauthilus_redis")
local nauthilus_policy = require("nauthilus_policy")
local toolkit = require("admin_toolkit")

function nauthilus_call_environment(request)
    local entries, err = nauthilus_redis.redis_smembers("default", toolkit.KEY_BLOCKLIST)

    if err ~= nil then
        return nauthilus_builtin.ENVIRONMENT_TRIGGER_NO,
            nauthilus_builtin.ENVIRONMENT_ABORT_NO,
            nauthilus_builtin.ENVIRONMENT_RESULT_FAIL
    end

    local blocked, entry = toolkit.contains(entries or {}, request.client_ip)

    if not blocked then
        return nauthilus_builtin.ENVIRONMENT_TRIGGER_NO,
            nauthilus_builtin.ENVIRONMENT_ABORT_NO,
            nauthilus_builtin.ENVIRONMENT_RESULT_OK
    end

    nauthilus_builtin.custom_log_add("blocklist_match", entry)
    nauthilus_policy.emit_attribute({ id = "lua.plugin.cookbook.blocklist.matched", value = true })

    -- Also report the classic "triggered" result. The policy rule decides the login either way.
    return nauthilus_builtin.ENVIRONMENT_TRIGGER_YES,
        nauthilus_builtin.ENVIRONMENT_ABORT_NO,
        nauthilus_builtin.ENVIRONMENT_RESULT_OK
end
