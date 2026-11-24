-- environment/privileged_account.lua
-- Environment source of the "Learning IP reputation" recipe. It marks privileged accounts, such as administrators or
-- service accounts, that an administrator listed in a Valkey set:
--   valkey-cli SADD cookbook:privileged alice
-- It emits the policy attribute lua.plugin.cookbook.account.privileged. The script knows nothing about the client's
-- reputation; the native reputation plugin provides that, and the policy rules in nauthilus.yml combine both.

local nauthilus_redis = require("nauthilus_redis")
local nauthilus_policy = require("nauthilus_policy")

function nauthilus_call_environment(request)
    local member, err = nauthilus_redis.redis_sismember("default", "cookbook:privileged", request.username or "")

    if err ~= nil then
        return nauthilus_builtin.ENVIRONMENT_TRIGGER_NO,
            nauthilus_builtin.ENVIRONMENT_ABORT_NO,
            nauthilus_builtin.ENVIRONMENT_RESULT_FAIL
    end

    local privileged = member == 1 or member == true

    if privileged then
        nauthilus_builtin.custom_log_add("privileged_account", "yes")
    end

    nauthilus_policy.emit_attribute({ id = "lua.plugin.cookbook.account.privileged", value = privileged })

    return nauthilus_builtin.ENVIRONMENT_TRIGGER_NO,
        nauthilus_builtin.ENVIRONMENT_ABORT_NO,
        nauthilus_builtin.ENVIRONMENT_RESULT_OK
end
