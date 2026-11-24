-- init.lua
-- Init script of the flat-file recipe. Nauthilus runs it once when the process starts; a configuration reload does
-- not run it again. It loads users.txt into the shared in-process cache and creates the Prometheus counter that the
-- backend increments for every password check.

local nauthilus_util = require("nauthilus_util")
local nauthilus_prometheus = require("nauthilus_prometheus")
local flatfile_users = require("flatfile_users")

function nauthilus_run_hook(request)
    nauthilus_prometheus.create_counter_vec(
        "cookbook_flatfile_password_checks_total",
        "Password checks of the flat-file Lua backend by result",
        { "result" }
    )

    local count, err = flatfile_users.load()

    if err ~= nil then
        nauthilus_util.log_error(request.logging, { caller = "init.lua", message = "loading users failed" }, err)

        return
    end

    nauthilus_util.log_info(request.logging, {
        caller = "init.lua",
        message = "flat-file users loaded",
        file = flatfile_users.USERS_FILE,
        accounts = count,
    })
end
