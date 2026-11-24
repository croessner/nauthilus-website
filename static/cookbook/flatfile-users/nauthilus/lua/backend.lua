-- backend.lua
-- Lua backend of the flat-file recipe. Nauthilus calls nauthilus_backend_verify_password for every login that is not
-- answered from its Redis cache, and nauthilus_backend_list_accounts for the account listing API.

local nauthilus_util = require("nauthilus_util")
local nauthilus_password = require("nauthilus_password")
local nauthilus_prometheus = require("nauthilus_prometheus")
local flatfile_users = require("flatfile_users")

-- count_check increments the Prometheus counter created by init.lua.
local function count_check(result)
    nauthilus_prometheus.increment_counter("cookbook_flatfile_password_checks_total", { result = result })
end

function nauthilus_backend_verify_password(request)
    local backend_result = nauthilus_backend_result.new()

    local _, err_load = flatfile_users.ensure_loaded()
    nauthilus_util.if_error_raise(err_load)

    local record = flatfile_users.find(request.username)

    if record == nil then
        count_check("unknown_user")

        backend_result:user_found(false)
        backend_result:authenticated(false)

        return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
    end

    -- A no-auth request (for example a Dovecot userdb lookup) only asks whether the user exists.
    local authenticated = false

    if request.no_auth then
        authenticated = true
    else
        local match, err_compare = nauthilus_password.compare_passwords(record.password, request.password or "")
        nauthilus_util.if_error_raise(err_compare)

        authenticated = match
    end

    count_check(authenticated and "ok" or "wrong_password")

    -- Turn the protocol set into a sorted, comma-separated list for the response.
    local protocols = {}

    for protocol in pairs(record.protocols or {}) do
        protocols[#protocols + 1] = protocol
    end

    table.sort(protocols)

    backend_result:user_found(true)
    backend_result:authenticated(authenticated)
    backend_result:account_field("account")
    backend_result:display_name_field("display_name")
    backend_result:attributes({
        account = record.username,
        display_name = record.display_name,
        mail = record.mail,
        allowed_protocols = table.concat(protocols, ","),
    })

    return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
end

function nauthilus_backend_list_accounts(request)
    local _, err_load = flatfile_users.ensure_loaded()
    nauthilus_util.if_error_raise(err_load)

    return nauthilus_builtin.BACKEND_RESULT_OK, flatfile_users.accounts()
end
