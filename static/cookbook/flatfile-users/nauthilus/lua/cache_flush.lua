-- cache_flush.lua
-- Cache-flush callback of the flat-file recipe. Nauthilus calls it for DELETE /api/v1/cache/flush. It tells Nauthilus
-- which account belongs to the user, so no backend lookup is needed, and names one extra Redis key to delete.
-- The recipe writes that key ("<prefix>cookbook:flush-marker:<user>") in test.sh to show that the flush removes it.

local flatfile_users = require("flatfile_users")

function nauthilus_cache_flush(request)
    local additional_keys = {
        request.redis_prefix .. "cookbook:flush-marker:" .. request.username,
    }

    local record = flatfile_users.find(request.username)
    local account = ""

    if record ~= nil then
        account = record.username
    end

    return additional_keys, account
end
