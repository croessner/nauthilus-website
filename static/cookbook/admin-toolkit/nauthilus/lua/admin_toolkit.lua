-- admin_toolkit.lua
-- Shared module of the "Admin toolkit" recipe. The hooks write the state, the environment sources read it, and
-- both use the key names and the IPv4 network matching from this one place.

local json = require("json")
local nauthilus_http_response = require("nauthilus_http_response")

local M = {}

-- Redis keys. A hash holds the maintenance state; a set holds the blocked addresses and networks.
M.KEY_MAINTENANCE = "cookbook:maintenance"
M.KEY_BLOCKLIST = "cookbook:blocklist"

-- ipv4_to_number turns "192.0.2.10" into a 32-bit number, or returns nil for anything else.
function M.ipv4_to_number(address)
    local a, b, c, d = string.match(address or "", "^(%d+)%.(%d+)%.(%d+)%.(%d+)$")

    if a == nil then
        return nil
    end

    local value = 0

    for _, octet in ipairs({ tonumber(a), tonumber(b), tonumber(c), tonumber(d) }) do
        if octet > 255 then
            return nil
        end

        value = value * 256 + octet
    end

    return value
end

-- parse_network turns "198.51.100.0/24" or a single address into the first and last address of the range.
-- It returns nil for an invalid entry.
function M.parse_network(entry)
    local address, bits = string.match(entry or "", "^([%d%.]+)/(%d+)$")

    if address == nil then
        address, bits = entry, "32"
    end

    local base = M.ipv4_to_number(address)
    local prefix = tonumber(bits)

    if base == nil or prefix == nil or prefix > 32 then
        return nil
    end

    local size = 2 ^ (32 - prefix)
    local first = math.floor(base / size) * size

    return first, first + size - 1
end

-- contains reports whether the client address lies in one of the networks of the list.
function M.contains(networks, client_ip)
    local ip = M.ipv4_to_number(client_ip)

    if ip == nil then
        return false, nil
    end

    for _, entry in ipairs(networks) do
        local first, last = M.parse_network(entry)

        if first ~= nil and ip >= first and ip <= last then
            return true, entry
        end
    end

    return false, nil
end

-- split_list turns "10.0.0.0/8, 192.168.0.0/16" into { "10.0.0.0/8", "192.168.0.0/16" }.
function M.split_list(value)
    local list = {}

    for item in string.gmatch(value or "", "[^,%s]+") do
        list[#list + 1] = item
    end

    return list
end

-- reply_error answers a hook request with an HTTP error status and a JSON body. A hook that changes the status
-- writes its body itself; returning a table only works for 200 answers.
function M.reply_error(status, body)
    nauthilus_http_response.set_http_status(status)
    nauthilus_http_response.set_http_content_type("application/json")
    nauthilus_http_response.write_http_response_body(json.encode(body))
end

return M
