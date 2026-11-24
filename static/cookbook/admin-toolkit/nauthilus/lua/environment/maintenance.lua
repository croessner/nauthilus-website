-- environment/maintenance.lua
-- Environment source of the "Admin toolkit" recipe. While maintenance mode is on, it stops every login before the
-- password is checked, except logins from the administrator networks.
-- The script does not decide the login itself. It emits the registered attribute lua.plugin.cookbook.maintenance.active,
-- and the policy rule maintenance_tempfail in nauthilus.yml answers with a temporary failure, so mail clients retry
-- later instead of asking the user for a new password.

local nauthilus_redis = require("nauthilus_redis")
local nauthilus_policy = require("nauthilus_policy")
local toolkit = require("admin_toolkit")

local ADMIN_NETWORKS = toolkit.split_list(os.getenv("COOKBOOK_ADMIN_NETWORKS") or "10.0.0.0/8")

-- not_triggered is the answer for "nothing to do here": no trigger, no abort, no error.
local function not_triggered()
    return nauthilus_builtin.ENVIRONMENT_TRIGGER_NO,
        nauthilus_builtin.ENVIRONMENT_ABORT_NO,
        nauthilus_builtin.ENVIRONMENT_RESULT_OK
end

function nauthilus_call_environment(request)
    local message, err = nauthilus_redis.redis_hget("default", toolkit.KEY_MAINTENANCE, "message")

    if err ~= nil then
        return nauthilus_builtin.ENVIRONMENT_TRIGGER_NO,
            nauthilus_builtin.ENVIRONMENT_ABORT_NO,
            nauthilus_builtin.ENVIRONMENT_RESULT_FAIL
    end

    if message == nil or message == "" then
        return not_triggered()
    end

    if toolkit.contains(ADMIN_NETWORKS, request.client_ip) then
        nauthilus_builtin.custom_log_add("maintenance_bypass", request.client_ip)

        return not_triggered()
    end

    nauthilus_builtin.custom_log_add("maintenance", "active")
    nauthilus_policy.emit_attribute({
        id = "lua.plugin.cookbook.maintenance.active",
        value = true,
        details = { status_message = message },
    })

    return not_triggered()
end
