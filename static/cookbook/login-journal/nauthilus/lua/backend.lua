-- backend.lua
-- The smallest useful Lua backend: two demo accounts in a Lua table. It only exists so that this recipe has
-- someone to log in as. The recipes "Flat-file users" and "SQL users" show real account sources.

local nauthilus_password = require("nauthilus_password")

-- Passwords: alice = alice-secret, bob = bob-secret (bcrypt hashes).
local USERS = {
    alice = { password = "$2y$10$ngKMNlOnSLGDyr0hoKOr3.H2WNwc2hSU.ht8m2HB8TVPZZdxuTlYC", mail = "alice@example.test" },
    bob = { password = "$2y$10$vUNCt8LDP9xgBCJkIRd7k.RzPdWOIqbK2ijZTTDEVb6blyR.KLJQC", mail = "bob@example.test" },
}

function nauthilus_backend_verify_password(request)
    local backend_result = nauthilus_backend_result.new()
    local user = USERS[request.username]

    if user == nil then
        backend_result:user_found(false)
        backend_result:authenticated(false)

        return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
    end

    local match = request.no_auth or nauthilus_password.compare_passwords(user.password, request.password or "")

    backend_result:user_found(true)
    backend_result:authenticated(match == true)
    backend_result:account_field("account")
    backend_result:attributes({ account = request.username, mail = user.mail })

    return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
end
