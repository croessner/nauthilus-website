-- policy/registry.lua
-- Policy registry script of the "Country rules per account" recipe. It declares the attribute that
-- environment/account_region.lua emits, so that the rules in nauthilus.yml can test it.

nauthilus_policy.register_attribute({
    id = "lua.plugin.cookbook.account.region",
    stage = "pre_auth",
    operations = { "authenticate" },
    category = "environment",
    type = "string",
    description = "Region from which the account may log in (eu or us).",
})
