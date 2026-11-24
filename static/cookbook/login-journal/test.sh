#!/usr/bin/env bash
# Checks the "Login journal" recipe. Start the stack first: docker compose up -d --wait
cd "$(dirname "$0")" || exit 1
. ../lib/cookbook.sh

NAUTHILUS_URL="${NAUTHILUS_URL:-http://127.0.0.1:28085}"
MAILPIT_URL="${MAILPIT_URL:-http://127.0.0.1:28185}"

# mail_count prints how many mails Mailpit holds with the given subject.
mail_count() {
    curl -sS "${MAILPIT_URL}/api/v1/messages" | grep -o "\"Subject\":\"$1\"" | wc -l | tr -d ' '
}

# Start from a clean state: no journal, no brute-force counters, no mails.
valkey FLUSHALL >/dev/null
curl -sS -X DELETE "${MAILPIT_URL}/api/v1/messages" >/dev/null

section "POST-action: login journal"
auth alice alice-secret imap 192.0.2.10
expect_auth_status "OK" "alice logs in"
# The POST-action runs after the answer, so wait for it.
wait_until '[ "$(valkey HGET cookbook:last_login:alice client_ip)" = "192.0.2.10" ]'
expect_equal "192.0.2.10" "$(valkey HGET cookbook:last_login:alice client_ip)" "the journal records the client address"
expect_equal "imap" "$(valkey HGET cookbook:last_login:alice protocol)" "the journal records the protocol"

auth alice wrong-password smtp 192.0.2.10
sleep 1
expect_equal "imap" "$(valkey HGET cookbook:last_login:alice protocol)" "a failed login does not change the journal"

for i in $(seq 1 12); do auth alice alice-secret smtp "192.0.2.$((i + 20))"; done
wait_until '[ "$(valkey HGET cookbook:last_login:alice client_ip)" = "192.0.2.32" ]'
expect_equal "10" "$(valkey LLEN cookbook:logins:alice)" "the history keeps the newest 10 logins"
printf '        newest entry: %s\n' "$(valkey LINDEX cookbook:logins:alice 0)"

section "Brute-force action: mail alert"
for i in $(seq 1 6); do auth bob "wrong-password-$i" imap "203.0.113.$i"; done
auth bob bob-secret imap 203.0.113.99
expect_auth_status "Invalid login or password" "after 5 wrong passwords the network 203.0.113.0/24 is blocked"

wait_until '[ "$(mail_count "Brute-force block for 203.0.113.0/24")" -ge 1 ]'
expect_equal "1" "$(mail_count 'Brute-force block for 203.0.113.0/24')" "the administrator got exactly one mail"

for i in $(seq 1 5); do auth bob bob-secret imap "203.0.113.$((i + 100))"; done
sleep 1
expect_equal "1" "$(mail_count 'Brute-force block for 203.0.113.0/24')" "further blocked attempts send no more mails"
blocked="$(valkey GET 'cookbook:bf_alert:203.0.113.0/24:count')"
[ "${blocked:-0}" -ge 5 ] && pass "the action counted $blocked blocked attempts" || fail "the action counted ${blocked:-0} blocked attempts"

auth bob bob-secret imap 198.51.100.7
expect_auth_status "OK" "bob still logs in from another network"

finish
