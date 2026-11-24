-- office_hours.lua
-- Generic policy provider of the "Policy API" recipe. A VPN gateway asks Nauthilus "may this user connect now?".
-- The gateway sends the user's group and its local weekday and hour; this script looks the group up in a schedule
-- and returns one fact, lua.office_hours.allowed. A policy rule in nauthilus.yml turns that fact into the decision.
--
-- Generic providers run in a small sandbox: a fresh Lua state per call with only the base, table, string, and math
-- libraries. There is no os, io, require, or Nauthilus module, so the caller supplies the time.

-- Which groups may connect when. Hours are "from" inclusive, "to" exclusive.
local SCHEDULE = {
    admins = { days = "mon,tue,wed,thu,fri,sat,sun", from = 0, to = 24 },
    staff = { days = "mon,tue,wed,thu,fri", from = 7, to = 19 },
    contractors = { days = "mon,tue,wed,thu", from = 9, to = 17 },
}

-- fact_values turns the request's fact list into a table: id -> plain Lua value.
local function fact_values(facts)
    local values = {}

    for _, fact in ipairs(facts or {}) do
        local value = fact.value or {}

        if value.kind == "integer" then
            values[fact.id] = tonumber(value.value)
        else
            values[fact.id] = value.value
        end
    end

    return values
end

-- contains reports whether the comma-separated list contains the item.
local function contains(list, item)
    for entry in string.gmatch(list, "[^,]+") do
        if entry == item then
            return true
        end
    end

    return false
end

-- allowed decides one request from the schedule.
local function allowed(group, weekday, hour)
    local rule = SCHEDULE[group or ""]

    if rule == nil or weekday == nil or hour == nil then
        return false
    end

    return contains(rule.days, string.lower(weekday)) and hour >= rule.from and hour < rule.to
end

_G["policy.facts.collect"] = function(request)
    local values = fact_values(request.facts)
    local result = allowed(values["subject.group"], values["environment.weekday"], values["environment.hour"])

    return {
        facts = {
            -- The host turns the local name "allowed" into lua.office_hours.allowed.
            { name = "allowed", value = { kind = "boolean", value = result } },
        },
    }
end

-- The deny rule selects the obligation vpn/audit-denial. Its typed parameters were checked by the host before this
-- callback runs. A sandboxed script cannot write anywhere, so it only validates and reports success.
_G["policy.effects.execute"] = function(request)
    return { state = "succeeded" }
end
