-- backend.lua
-- Lua backend of the "SQL users" recipe. Accounts live in MariaDB. Logins and lookups use a read-only database
-- user; the MFA callbacks use a second user that may only change the TOTP column and the recovery-code table.

local nauthilus_util = require("nauthilus_util")
local nauthilus_password = require("nauthilus_password")
local db = require("db")

local READ_DSN = os.getenv("COOKBOOK_DB_READ_DSN") or "nauthilus_ro:cookbook-ro@tcp(mariadb:3306)/cookbook"
local MFA_DSN = os.getenv("COOKBOOK_DB_MFA_DSN") or "nauthilus_mfa:cookbook-mfa@tcp(mariadb:3306)/cookbook"

-- shared = true keeps one connection pool per DSN for the whole Nauthilus process instead of one per request.
local READ_OPTIONS = { shared = true, max_connections = 8, read_only = true }
local MFA_OPTIONS = { shared = true, max_connections = 2, read_only = false }

-- run executes one prepared statement and closes it. kind is "query" (returns rows) or "exec" (returns counts).
-- Closing matters: MariaDB keeps every prepared statement of a connection until it is closed.
local function run(dsn, options, kind, sql, ...)
    local conn, err_open = db.open("mysql", dsn, options)
    nauthilus_util.if_error_raise(err_open)

    local statement, err_prepare = conn:stmt(sql)
    nauthilus_util.if_error_raise(err_prepare)

    local result, err_run = statement[kind](statement, ...)
    statement:close()
    nauthilus_util.if_error_raise(err_run)

    return result
end

-- first_row returns the first row of a query result as a table keyed by column name, or nil.
local function first_row(result)
    if result.rows == nil or #result.rows == 0 then
        return nil
    end

    local record = {}

    for index, column in ipairs(result.columns) do
        record[column] = result.rows[1][index]
    end

    return record
end

-- find_account looks a user up by login name or by mail address.
local function find_account(username)
    return first_row(run(READ_DSN, READ_OPTIONS, "query",
        "SELECT id, username, account, password, display_name, mail, enabled, totp_secret " ..
        "FROM accounts WHERE username = ? OR account = ? LIMIT 1",
        username, username))
end

-- is_enabled reads the BOOLEAN column, which the driver may return as a number or a string.
local function is_enabled(value)
    return value == 1 or value == "1" or value == true
end

function nauthilus_backend_verify_password(request)
    local backend_result = nauthilus_backend_result.new()
    local record = find_account(request.username)

    if record == nil or not is_enabled(record.enabled) then
        backend_result:user_found(false)
        backend_result:authenticated(false)

        return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
    end

    local authenticated = true

    if not request.no_auth then
        local match, err_compare = nauthilus_password.compare_passwords(record.password, request.password or "")
        nauthilus_util.if_error_raise(err_compare)

        authenticated = match
    end

    local attributes = {
        account = record.account,
        display_name = record.display_name,
        mail = record.mail,
    }

    -- Nauthilus reads the TOTP secret from the field named by totp_secret_field below.
    if record.totp_secret ~= nil and record.totp_secret ~= "" then
        attributes.totp_secret = record.totp_secret
    end

    backend_result:user_found(true)
    backend_result:authenticated(authenticated)
    backend_result:account_field("account")
    backend_result:display_name_field("display_name")
    backend_result:totp_secret_field("totp_secret")
    backend_result:attributes(attributes)

    return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
end

function nauthilus_backend_list_accounts(request)
    local result = run(READ_DSN, READ_OPTIONS, "query",
        "SELECT account FROM accounts WHERE enabled = TRUE ORDER BY id")
    local accounts = {}

    for _, row in ipairs(result.rows or {}) do
        accounts[#accounts + 1] = row[1]
    end

    return nauthilus_builtin.BACKEND_RESULT_OK, accounts
end

-- MFA callbacks. Nauthilus calls them when a user enrolls or removes TOTP, for example through the identity
-- provider or the MFA backchannel API.

function nauthilus_backend_add_totp(request)
    run(MFA_DSN, MFA_OPTIONS, "exec",
        "UPDATE accounts SET totp_secret = ? WHERE username = ? OR account = ?",
        request.totp_secret, request.username, request.username)

    return nauthilus_builtin.BACKEND_RESULT_OK
end

function nauthilus_backend_delete_totp(request)
    run(MFA_DSN, MFA_OPTIONS, "exec",
        "UPDATE accounts SET totp_secret = NULL WHERE username = ? OR account = ?",
        request.username, request.username)

    return nauthilus_builtin.BACKEND_RESULT_OK
end

function nauthilus_backend_add_totp_recovery_codes(request)
    local record = find_account(request.username)

    if record == nil then
        return nauthilus_builtin.BACKEND_RESULT_FAIL
    end

    -- New codes replace the old ones.
    run(MFA_DSN, MFA_OPTIONS, "exec", "DELETE FROM recovery_codes WHERE account_id = ?", record.id)

    for _, code in ipairs(request.totp_recovery_codes or {}) do
        run(MFA_DSN, MFA_OPTIONS, "exec",
            "INSERT INTO recovery_codes (account_id, code) VALUES (?, ?)", record.id, code)
    end

    return nauthilus_builtin.BACKEND_RESULT_OK
end

function nauthilus_backend_delete_totp_recovery_codes(request)
    local record = find_account(request.username)

    if record ~= nil then
        run(MFA_DSN, MFA_OPTIONS, "exec", "DELETE FROM recovery_codes WHERE account_id = ?", record.id)
    end

    return nauthilus_builtin.BACKEND_RESULT_OK
end
