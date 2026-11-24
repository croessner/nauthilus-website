-- policy/registry.lua
-- Policy registry script of the "Learning IP reputation" recipe. It declares the attribute that
-- environment/privileged_account.lua emits, so that the rules in nauthilus.yml can test it.

nauthilus_policy.register_attribute({
    id = "lua.plugin.cookbook.account.privileged",
    stage = "pre_auth",
    operations = { "authenticate" },
    category = "environment",
    type = "bool",
    description = "Whether the account is listed as privileged.",
})
