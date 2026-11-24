#!/usr/bin/env bash
# Checks the "Admin toolkit" recipe. Start the stack first: docker compose up -d --wait
cd "$(dirname "$0")" || exit 1
. ../lib/cookbook.sh

NAUTHILUS_URL="${NAUTHILUS_URL:-http://127.0.0.1:28083}"
ADMIN="admin:admin-backchannel-secret"

# hook calls one custom hook as the administrator. Arguments: method location [json]
hook() {
    if [ $# -ge 3 ]; then
        http "$1" "/api/v1/custom/$2" -u "$ADMIN" -H 'Content-Type: application/json' -d "$3"
    else
        http "$1" "/api/v1/custom/$2" -u "$ADMIN"
    fi
}

# Start from a clean state, so the script can run more than once.
valkey DEL cookbook:maintenance cookbook:blocklist >/dev/null

section "Normal operation"
auth alice alice-secret imap 192.0.2.10
expect_auth_status "OK" "alice logs in"

section "Hook access control"
http GET /api/v1/custom/maintenance -u mailserver:mailserver-backchannel-secret
expect_status 403 "the mail server credential may not call the hooks"
http GET /api/v1/custom/maintenance
expect_status 401 "an anonymous caller may not call the hooks"

section "Maintenance mode"
hook POST maintenance '{"enabled": true, "message": "Mail server upgrade until 22:00"}'
expect_status 200 "the hook switches maintenance on"
expect_body_contains '"enabled":true' "the hook reports the new state"

hook GET maintenance
expect_body_contains 'Mail server upgrade until 22:00' "GET shows the stored message"

auth alice alice-secret imap 192.0.2.10
expect_status 500 "a login from the internet gets a temporary failure"
expect_auth_status "Mail server upgrade until 22:00" "the client sees the message stored by the administrator"

auth alice alice-secret imap 10.20.30.40
expect_auth_status "OK" "a login from the admin network 10.0.0.0/8 still works"

hook POST maintenance '{"enabled": "yes"}'
expect_status 400 "the hook rejects a malformed body"
expect_body_contains 'expected a JSON body' "the error explains the expected body"

hook POST maintenance '{"enabled": false}'
auth alice alice-secret imap 192.0.2.10
expect_auth_status "OK" "after switching maintenance off, logins work again"

section "IP blocklist"
hook POST blocklist '{"add": ["198.51.100.0/24", "203.0.113.7"]}'
expect_status 200 "the hook adds a network and an address"
expect_body_contains '"198.51.100.0/24"' "the list contains the network"

auth alice alice-secret imap 198.51.100.77
expect_auth_status "Access from your network is blocked" "a client inside 198.51.100.0/24 is rejected"

auth bob bob-secret imap 203.0.113.7
expect_auth_status "Access from your network is blocked" "the single blocked address is rejected"

auth bob bob-secret imap 203.0.113.8
expect_auth_status "OK" "the neighbour address is not blocked"

hook POST blocklist '{"add": ["300.1.1.1"]}'
expect_status 400 "the hook refuses an invalid address"
expect_body_contains '"300.1.1.1"' "the error names the invalid entry"

hook POST blocklist '{"remove": ["203.0.113.7"]}'
auth bob bob-secret imap 203.0.113.7
expect_auth_status "OK" "after removing the address, bob logs in again"

section "Many requests against a long blocklist"
# 50 networks make environment/ip_blocklist.lua loop for every login; 200 logins reuse the pooled Lua VMs.
networks=""
for i in $(seq 1 50); do networks="$networks\"10.$i.0.0/16\","; done
hook POST blocklist "{\"add\": [${networks%,}]}"

wrong=0
for i in $(seq 1 100); do
    auth alice alice-secret imap "10.$(( (i % 50) + 1 )).$i.1"
    [ "$(header Auth-Status)" = "Access from your network is blocked" ] || wrong=$((wrong + 1))
    auth bob bob-secret imap "192.0.2.$(( (i % 200) + 1 ))"
    [ "$(header Auth-Status)" = "OK" ] || wrong=$((wrong + 1))
done
expect_equal 0 "$wrong" "200 logins got the expected answer"

valkey DEL cookbook:maintenance cookbook:blocklist >/dev/null

finish
