-- demo_users.lua
-- Shared module of the "Account rules" recipe: the demo accounts and the protocols each one may use. backend.lua
-- checks passwords with it, and subject/protocol_access.lua reads the protocol list from it. In a real installation
-- this would be a lookup in your directory or database.

local M = {}

-- Passwords: alice = alice-secret, bob = bob-secret (bcrypt hashes).
M.USERS = {
    alice = {
        password = "$2y$10$ngKMNlOnSLGDyr0hoKOr3.H2WNwc2hSU.ht8m2HB8TVPZZdxuTlYC",
        mail = "alice@example.test",
        allowed_protocols = "imap,smtp,pop3",
    },
    bob = {
        password = "$2y$10$vUNCt8LDP9xgBCJkIRd7k.RzPdWOIqbK2ijZTTDEVb6blyR.KLJQC",
        mail = "bob@example.test",
        allowed_protocols = "imap",
    },
}

-- find returns the record of one account or nil.
function M.find(account)
    return M.USERS[account or ""]
end

return M
