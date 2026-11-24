-- flatfile_users.lua
-- Shared module of the flat-file recipe. It parses users.txt and keeps the accounts in nauthilus_cache, the in-process
-- cache that every Lua VM of this Nauthilus instance shares. The init script calls load() once at startup; the
-- backend calls ensure_loaded() so it also works when the init script did not run.

local nauthilus_cache = require("nauthilus_cache")

local M = {}

M.USERS_FILE = os.getenv("COOKBOOK_USERS_FILE") or "/etc/nauthilus/users.txt"

local KEY_LOADED = "flatfile:loaded_at"
local KEY_ACCOUNTS = "flatfile:accounts"
local KEY_USER_PREFIX = "flatfile:user:"

-- split returns the fields of a line separated by sep. Empty fields are kept, so "a::b" gives three fields.
local function split(line, sep)
    local fields = {}
    local start = 1

    while true do
        local stop = string.find(line, sep, start, true)

        if stop == nil then
            fields[#fields + 1] = string.sub(line, start)

            return fields
        end

        fields[#fields + 1] = string.sub(line, start, stop - 1)
        start = stop + 1
    end
end

-- trim removes leading and trailing white space.
local function trim(value)
    return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

-- parse_protocols turns "imap, smtp" into a set: { imap = true, smtp = true }.
local function parse_protocols(value)
    local protocols = {}

    for protocol in string.gmatch(value or "", "[^,]+") do
        protocol = string.lower(trim(protocol))

        if protocol ~= "" then
            protocols[protocol] = true
        end
    end

    return protocols
end

-- parse_line returns one account record, or nil for comments, empty lines, and broken lines.
local function parse_line(line)
    line = trim(line)

    if line == "" or string.sub(line, 1, 1) == "#" then
        return nil
    end

    local fields = split(line, ":")

    if #fields < 2 or fields[1] == "" or fields[2] == "" then
        return nil
    end

    return {
        username = fields[1],
        password = fields[2],
        display_name = fields[3] or fields[1],
        mail = fields[4] or "",
        protocols = parse_protocols(fields[5]),
    }
end

-- load reads the users file and replaces the cached accounts. It returns the number of accounts or nil and an error.
function M.load(path)
    path = path or M.USERS_FILE

    local file, err_open = io.open(path, "r")

    if file == nil then
        return nil, "cannot open " .. path .. ": " .. tostring(err_open)
    end

    local accounts = {}

    for line in file:lines() do
        local record = parse_line(line)

        if record ~= nil then
            nauthilus_cache.cache_set(KEY_USER_PREFIX .. record.username, record)
            accounts[#accounts + 1] = record.username
        end
    end

    file:close()

    -- Remove accounts that were deleted from the file since the last load.
    local previous = nauthilus_cache.cache_get(KEY_ACCOUNTS) or {}
    local current = {}

    for _, username in ipairs(accounts) do
        current[username] = true
    end

    for _, username in ipairs(previous) do
        if not current[username] then
            nauthilus_cache.cache_delete(KEY_USER_PREFIX .. username)
        end
    end

    nauthilus_cache.cache_set(KEY_ACCOUNTS, accounts)
    nauthilus_cache.cache_set(KEY_LOADED, os.time())

    return #accounts, nil
end

-- ensure_loaded loads the file once if no init script did it before.
function M.ensure_loaded()
    if nauthilus_cache.cache_exists(KEY_LOADED) then
        return true, nil
    end

    local _, err = M.load()

    return err == nil, err
end

-- find returns the cached record of one user or nil.
function M.find(username)
    local record = nauthilus_cache.cache_get(KEY_USER_PREFIX .. tostring(username or ""))

    if type(record) ~= "table" then
        return nil
    end

    return record
end

-- accounts returns the list of all usernames in file order.
function M.accounts()
    return nauthilus_cache.cache_get(KEY_ACCOUNTS) or {}
end

-- loaded_at returns the Unix time of the last load or nil.
function M.loaded_at()
    return nauthilus_cache.cache_get(KEY_LOADED)
end

return M
