-- backend.lua
-- The smallest useful Lua backend: it checks the demo accounts of demo_users.lua. The recipes "Flat-file users" and
-- "SQL users" show real account sources.

local nauthilus_password = require("nauthilus_password")
local demo_users = require("demo_users")

function nauthilus_backend_verify_password(request)
    local backend_result = nauthilus_backend_result.new()
    local user = demo_users.find(request.username)

    if user == nil then
        backend_result:user_found(false)
        backend_result:authenticated(false)

        return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
    end

    local match = request.no_auth or nauthilus_password.compare_passwords(user.password, request.password or "")

    backend_result:user_found(true)
    backend_result:authenticated(match == true)
    backend_result:account_field("account")
    backend_result:attributes({
        account = request.username,
        mail = user.mail,
        allowed_protocols = user.allowed_protocols,
    })

    return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
end
