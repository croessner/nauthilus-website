-- subject/protocol_access.lua
-- Subject source of the "Account rules" recipe. It runs after the backend checked the password and looks up which
-- protocols the account may use. A user who may only read mail over IMAP is refused for SMTP, even with the right
-- password. The lookup also runs when Nauthilus answered the password check from its cache.

local nauthilus_policy = require("nauthilus_policy")
local demo_users = require("demo_users")

-- allows reports whether the comma-separated list contains the protocol.
local function allows(list, protocol)
    for item in string.gmatch(list or "", "[^,%s]+") do
        if string.lower(item) == protocol then
            return true
        end
    end

    return false
end

function nauthilus_call_subject(request)
    -- Only a successful login is interesting: a wrong password is rejected anyway.
    if not request.authenticated then
        return nauthilus_builtin.SUBJECT_ACCEPT, nauthilus_builtin.SUBJECT_RESULT_OK
    end

    local account = request.account

    if account == nil or account == "" then
        account = request.username
    end

    local user = demo_users.find(account)
    local protocol = string.lower(request.protocol or "")

    -- Accounts without a list may use every protocol.
    if user == nil or user.allowed_protocols == nil or allows(user.allowed_protocols, protocol) then
        return nauthilus_builtin.SUBJECT_ACCEPT, nauthilus_builtin.SUBJECT_RESULT_OK
    end

    nauthilus_builtin.custom_log_add("protocol_denied", protocol)
    nauthilus_policy.emit_attribute({ id = "lua.plugin.cookbook.protocol.denied", value = true })

    return nauthilus_builtin.SUBJECT_REJECT, nauthilus_builtin.SUBJECT_RESULT_OK
end
