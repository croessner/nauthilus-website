-- actions/brute_force_alert.lua
-- Brute-force action of the "Login journal" recipe. A policy rule in nauthilus.yml runs it when the brute-force
-- check blocks a client. It mails the administrator once per blocked network and hour; further blocked attempts in
-- that hour only increase a counter, so an attack does not flood the mailbox.

local nauthilus_mail = require("nauthilus_mail")
local nauthilus_redis = require("nauthilus_redis")

local MAIL_TO = os.getenv("COOKBOOK_ALERT_TO") or "admin@example.test"
local SMTP_SERVER = os.getenv("COOKBOOK_SMTP_SERVER") or "mailpit"
local SMTP_PORT = tonumber(os.getenv("COOKBOOK_SMTP_PORT") or "1025")
local QUIET_SECONDS = 3600

-- describe formats the request fields that help the administrator, one "name: value" per line.
local function describe(request)
    local lines = {}

    for _, field in ipairs({ "client_ip", "client_net", "username", "protocol", "brute_force_bucket" }) do
        lines[#lines + 1] = string.format("%-20s %s", field .. ":", tostring(request[field] or "-"))
    end

    return table.concat(lines, "\n")
end

function nauthilus_call_action(request)
    local network = request.client_net

    if network == nil or network == "" then
        network = request.client_ip or "unknown"
    end

    local key = "cookbook:bf_alert:" .. network
    local first, err = nauthilus_redis.redis_set("default", key, "1", { nx = true, ex = QUIET_SECONDS })

    if err ~= nil then
        return nauthilus_builtin.ACTION_RESULT_FAIL
    end

    nauthilus_redis.redis_incr("default", key .. ":count")

    -- redis_set with nx answers "OK" only for the first attempt of the hour.
    if first ~= "OK" then
        return nauthilus_builtin.ACTION_RESULT_OK
    end

    local err_mail = nauthilus_mail.send_mail({
        server = SMTP_SERVER,
        port = SMTP_PORT,
        helo_name = "nauthilus.example.test",
        from = '"Nauthilus" <nauthilus@example.test>',
        to = { MAIL_TO },
        subject = "Brute-force block for " .. network,
        body = "Nauthilus blocked a client because of too many failed logins.\n\n" .. describe(request) .. "\n",
    })

    if err_mail ~= nil then
        nauthilus_builtin.custom_log_add("brute_force_alert_error", err_mail)

        return nauthilus_builtin.ACTION_RESULT_FAIL
    end

    nauthilus_builtin.custom_log_add("brute_force_alert", MAIL_TO)

    return nauthilus_builtin.ACTION_RESULT_OK
end
