-- policy/registry.lua
-- Policy registry script of the "Account rules" recipe. It declares the attributes that the two subject sources
-- emit, so that the policy rules in nauthilus.yml can test them.

local function register(id, value_type, description, details)
    nauthilus_policy.register_attribute({
        id = id,
        stage = "subject_analysis",
        operations = { "authenticate" },
        category = "subject",
        type = value_type,
        description = description,
        details = details,
    })
end

register("lua.plugin.cookbook.protocol.denied", "bool", "Whether the account may not use the requested protocol.")
register("lua.plugin.cookbook.lock.active", "bool", "Whether an administrator locked the account.")
register("lua.plugin.cookbook.lock.until", "string", "Until when the account is locked (UTC, RFC 3339).")
