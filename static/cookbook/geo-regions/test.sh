#!/usr/bin/env bash
# Checks the "Country rules per account" recipe. Start the stack first: docker compose up -d --wait
cd "$(dirname "$0")" || exit 1
. ../lib/cookbook.sh

NAUTHILUS_URL="${NAUTHILUS_URL:-http://127.0.0.1:28087}"

# Addresses of the demo GeoIP database (nauthilus/geoip/geoip.json) and one it does not know.
GERMANY=192.0.2.10
USA=198.51.100.10
BRAZIL=203.0.113.10
UNKNOWN=10.9.9.9

NOT_ALLOWED="Login from this country is not allowed for this account"
UNKNOWN_LOCATION="Login location unknown, login not allowed for this account"

# Start from a clean state: no regions, no cached logins.
valkey FLUSHALL >/dev/null

section "Native plugin loaded"
if docker compose logs nauthilus 2>/dev/null | grep -q "Required plugin module registration failed"; then
    fail "the GeoIP plugin failed to register"
else
    pass "the GeoIP plugin registered"
fi

section "Accounts without a region"
for ip in $GERMANY $USA $BRAZIL $UNKNOWN; do
    auth bob bob-secret imap "$ip"
    expect_auth_status "OK" "bob logs in from $ip"
done

section "Account with region eu"
valkey SET cookbook:region:alice eu >/dev/null

auth alice alice-secret imap $GERMANY
expect_auth_status "OK" "alice (eu) logs in from Germany"

auth alice alice-secret imap $USA
expect_auth_status "$NOT_ALLOWED" "alice (eu) is refused from the USA"

auth alice alice-secret imap $BRAZIL
expect_auth_status "$NOT_ALLOWED" "alice (eu) is refused from Brazil"

auth alice alice-secret imap $UNKNOWN
expect_auth_status "$UNKNOWN_LOCATION" "alice (eu) is refused from an address without a known location"

auth alice wrong-password imap $USA
expect_auth_status "$NOT_ALLOWED" "the rule answers before the password is checked"

section "The administrator changes the region"
valkey SET cookbook:region:alice us >/dev/null

auth alice alice-secret imap $USA
expect_auth_status "OK" "alice (us) logs in from the USA at once"

auth alice alice-secret imap $GERMANY
expect_auth_status "$NOT_ALLOWED" "alice (us) is now refused from Germany"

valkey SET cookbook:region:alice mars >/dev/null
auth alice alice-secret imap $BRAZIL
expect_auth_status "OK" "an unknown region value is ignored instead of locking the account"

valkey DEL cookbook:region:alice >/dev/null
auth alice alice-secret imap $BRAZIL
expect_auth_status "OK" "without a region alice logs in from everywhere again"

section "Many requests"
valkey SET cookbook:region:alice eu >/dev/null
wrong=0
for i in $(seq 1 100); do
    auth alice alice-secret imap "192.0.2.$(( (i % 200) + 1 ))"
    [ "$(header Auth-Status)" = "OK" ] || wrong=$((wrong + 1))
    auth alice alice-secret imap "198.51.100.$(( (i % 200) + 1 ))"
    [ "$(header Auth-Status)" = "$NOT_ALLOWED" ] || wrong=$((wrong + 1))
done
expect_equal 0 "$wrong" "200 logins got the expected answer"
valkey DEL cookbook:region:alice >/dev/null

finish
