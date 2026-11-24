-- policy/registry.lua
-- Policy registry script of the "Admin toolkit" recipe. Nauthilus runs it when it builds the policy snapshot, at
-- startup and after every reload. It declares the attributes that the environment sources emit, so that the policy
-- rules in nauthilus.yml can test them. Lua may only emit attributes that a registry script declared.

nauthilus_policy.register_attribute({
    id = "lua.plugin.cookbook.maintenance.active",
    stage = "pre_auth",
    operations = { "authenticate" },
    category = "environment",
    type = "bool",
    description = "Whether maintenance mode blocks this login.",
    details = {
        -- The message an administrator stored with the maintenance hook. "public" and "response_message"
        -- allow the policy rule to send it to the client.
        status_message = {
            type = "string",
            sensitivity = "public",
            purpose = "response_message",
            max_length = 256,
        },
    },
})

nauthilus_policy.register_attribute({
    id = "lua.plugin.cookbook.blocklist.matched",
    stage = "pre_auth",
    operations = { "authenticate" },
    category = "environment",
    type = "bool",
    description = "Whether the client address is on the administrator blocklist.",
})
