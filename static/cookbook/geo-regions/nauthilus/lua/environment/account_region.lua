-- environment/account_region.lua
-- Environment source of the "Country rules per account" recipe. It reads the region an administrator assigned to the
-- account and emits it as the policy attribute lua.plugin.cookbook.account.region:
--   valkey-cli SET cookbook:region:alice eu
-- An account without a region is not emitted and may log in from everywhere. The script does not know the client's
-- country: the native GeoIP plugin provides that fact, and the policy rules in nauthilus.yml combine both.

local nauthilus_redis = require("nauthilus_redis")
local nauthilus_policy = require("nauthilus_policy")

-- Regions the policy rules know. Anything else is ignored, so a typo cannot lock an account out by accident.
local KNOWN_REGIONS = { eu = true, us = true }

function nauthilus_call_environment(request)
    local region, err = nauthilus_redis.redis_get("default", "cookbook:region:" .. (request.username or ""))

    if err ~= nil then
        return nauthilus_builtin.ENVIRONMENT_TRIGGER_NO,
            nauthilus_builtin.ENVIRONMENT_ABORT_NO,
            nauthilus_builtin.ENVIRONMENT_RESULT_FAIL
    end

    if type(region) == "string" and KNOWN_REGIONS[string.lower(region)] then
        region = string.lower(region)

        nauthilus_builtin.custom_log_add("account_region", region)
        nauthilus_policy.emit_attribute({ id = "lua.plugin.cookbook.account.region", value = region })
    end

    return nauthilus_builtin.ENVIRONMENT_TRIGGER_NO,
        nauthilus_builtin.ENVIRONMENT_ABORT_NO,
        nauthilus_builtin.ENVIRONMENT_RESULT_OK
end
