#!/usr/bin/env bash
# Checks the "Account rules" recipe. Start the stack first: docker compose up -d --wait
cd "$(dirname "$0")" || exit 1
. ../lib/cookbook.sh

NAUTHILUS_URL="${NAUTHILUS_URL:-http://127.0.0.1:28084}"

# Start from a clean state: no locks, no cached logins.
valkey FLUSHALL >/dev/null

section "Protocol access (subject/protocol_access.lua)"
auth bob bob-secret imap 192.0.2.10
expect_auth_status "OK" "bob may use IMAP"

auth bob bob-secret smtp 192.0.2.10
expect_auth_status "This account may not use this service" "bob may not use SMTP, even with the right password"

auth bob wrong-password smtp 192.0.2.10
expect_auth_status "Invalid login or password" "a wrong password still gives the normal answer"

auth alice alice-secret smtp 192.0.2.11
expect_auth_status "OK" "alice may use SMTP"

auth alice alice-secret pop3 192.0.2.11
expect_auth_status "OK" "alice may use POP3"

section "Account lock (subject/account_lock.lua)"
valkey HSET cookbook:lock:alice until 2030-01-01T00:00:00Z reason offboarding >/dev/null
auth alice alice-secret imap 192.0.2.11
expect_auth_status "This account is locked" "a locked account is refused, even from the login cache"

auth bob bob-secret imap 192.0.2.10
expect_auth_status "OK" "other accounts are not affected"

valkey HSET cookbook:lock:alice until 2020-01-01T00:00:00Z >/dev/null
auth alice alice-secret imap 192.0.2.11
expect_auth_status "OK" "an expired lock is ignored"
expect_equal 0 "$(valkey EXISTS cookbook:lock:alice)" "the expired lock was deleted"

section "Many requests"
wrong=0
for i in $(seq 1 100); do
    auth bob bob-secret smtp "192.0.2.$(( (i % 200) + 1 ))"
    [ "$(header Auth-Status)" = "This account may not use this service" ] || wrong=$((wrong + 1))
    auth alice alice-secret imap "198.51.100.$(( (i % 200) + 1 ))"
    [ "$(header Auth-Status)" = "OK" ] || wrong=$((wrong + 1))
done
expect_equal 0 "$wrong" "200 logins got the expected answer"

finish
