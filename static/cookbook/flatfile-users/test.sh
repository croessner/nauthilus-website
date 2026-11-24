#!/usr/bin/env bash
# Checks the "Flat-file users" recipe. Start the stack first: docker compose up -d --wait
cd "$(dirname "$0")" || exit 1
. ../lib/cookbook.sh

NAUTHILUS_URL="${NAUTHILUS_URL:-http://127.0.0.1:28081}"
ADMIN="admin:admin-backchannel-secret"

section "Init script"
if docker compose logs nauthilus 2>/dev/null | grep -q 'flat-file users loaded'; then
    pass "init.lua loaded users.txt at startup"
else
    fail "init.lua did not log 'flat-file users loaded'"
fi

section "Lua backend: password checks"
auth alice alice-secret imap 192.0.2.10
expect_auth_status "OK" "alice logs in (bcrypt hash)"
expect_body_contains '"display_name":["Alice Example"]' "backend returns the display name"
expect_body_contains '"allowed_protocols":["imap,smtp"]' "backend returns the protocol list"

auth bob bob-secret imap 192.0.2.10
expect_auth_status "OK" "bob logs in (SHA512-crypt hash)"

auth bob wrong-password imap 192.0.2.11
expect_auth_status "Invalid login or password" "bob with a wrong password is rejected"

auth mallory secret imap 192.0.2.12
expect_auth_status "Invalid login or password" "an unknown user is rejected"

section "Lua backend: account listing"
http GET '/api/v1/auth/json?mode=list-accounts' -u "$ADMIN" -H 'Accept: application/json'
expect_status 200 "list-accounts answers"
for account in alice bob carol; do
    expect_body_contains "\"$account\"" "list-accounts contains $account"
done

section "Cache flush callback"
valkey SET nt:cookbook:flush-marker:alice 1 >/dev/null
http DELETE /api/v1/cache/flush -u "$ADMIN" -H 'Content-Type: application/json' -d '{"user":"alice"}'
expect_status 200 "cache flush answers"
expect_body_contains 'nt:cookbook:flush-marker:alice' "the flush removed the key named by cache_flush.lua"
expect_equal 0 "$(valkey EXISTS nt:cookbook:flush-marker:alice)" "the marker key is gone from Valkey"

section "Prometheus counter created by init.lua"
http GET /metrics
expect_body_contains 'cookbook_flatfile_password_checks_total{result="ok"}' "the backend counts successful checks"
expect_body_contains 'cookbook_flatfile_password_checks_total{result="wrong_password"}' "the backend counts wrong passwords"

finish
