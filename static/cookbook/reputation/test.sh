#!/usr/bin/env bash
# Checks the "Learning IP reputation" recipe. Start the stack first: ./setup.sh && docker compose up -d --wait
# The plugin keeps its model and allocation state in Valkey, so the test never empties Valkey. It picks addresses
# without history for every run and removes its own overrides.
cd "$(dirname "$0")" || exit 1
. ../lib/cookbook.sh

NAUTHILUS_URL="${NAUTHILUS_URL:-http://127.0.0.1:28088}"
SUSPICIOUS_TEXT="Login from a suspicious address is not allowed for this account"
BLOCKED_TEXT="Access from your network is blocked"

# admin_token asks the built-in identity provider for an administrator token (client credentials grant).
admin_token() {
    curl -sS -u reputation-admin:reputation-admin-secret \
        -d grant_type=client_credentials -d scope=nauthilus:admin \
        "${NAUTHILUS_URL}/oidc/token" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p'
}

TOKEN="$(admin_token)"

# reputation calls the plugin's management API. Arguments: method path json
reputation() {
    http "$1" "/api/v1/custom/reputation/$2" -H "Authorization: Bearer ${TOKEN}" \
        -H 'Content-Type: application/json' -d "$3"
}

# band prints the learned or overridden band of an address in the "fast" profile that the rules use.
band() {
    reputation POST lookup "{\"kind\": \"ip\", \"subject\": \"$1\"}"
    printf '%s' "$last_body" | awk -F'"fast":' '{ print $2 }' | grep -o '"band":"[a-z]*"' | head -1 | cut -d'"' -f4
}

# fresh_ip prints an address of the given /24 prefix that has no history yet. Argument: prefix such as 198.51.100
fresh_ip() {
    local candidate attempt

    for attempt in $(seq 1 40); do
        candidate="$1.$(( (RANDOM % 250) + 1 ))"

        if [ "$(band "$candidate")" = "unknown" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done

    return 1
}

# remove_network_block deletes the network override this test creates, if an earlier run left it behind.
remove_network_block() {
    reputation DELETE override '{"kind": "network", "subject": "203.0.113.0/24", "previous_audit": "cookbook-test-block",
        "audit_id": "cookbook-test-unblock", "reason": "test_cleanup", "origin": "operator"}'
}

section "Plugin and administrator token"
[ -n "$TOKEN" ] && pass "the identity provider issued an administrator token" || fail "no administrator token"
reputation POST lookup '{"kind": "ip", "subject": "192.0.2.1"}'
expect_body_contains '"model_id":"cookbook-v1"' "the plugin answers a lookup with the configured model"

remove_network_block >/dev/null
valkey SADD cookbook:privileged alice >/dev/null
valkey SREM cookbook:privileged bob >/dev/null

section "Learning from wrong passwords"
ATTACKER="$(fresh_ip 198.51.100)" || fail "no address without history found"
expect_equal "unknown" "$(band "$ATTACKER")" "a new address has no reputation"

auth alice alice-secret imap "$ATTACKER"
expect_auth_status "OK" "alice (privileged) logs in from the new address"

for i in 1 2 3 4; do auth bob "wrong-password-$i" imap "$ATTACKER"; done
wait_until "[ \"\$(band $ATTACKER)\" = suspicious ]"
expect_equal "suspicious" "$(band "$ATTACKER")" "four wrong passwords make the address suspicious"

auth alice alice-secret imap "$ATTACKER"
expect_auth_status "$SUSPICIOUS_TEXT" "alice (privileged) is refused from the suspicious address"

auth bob bob-secret imap "$ATTACKER"
expect_auth_status "OK" "bob (not privileged) still logs in from there"

section "Learning from successful logins"
OFFICE="$(fresh_ip 192.0.2)" || fail "no address without history found"
for i in 1 2 3 4 5 6; do auth bob bob-secret imap "$OFFICE"; done
wait_until "[ \"\$(band $OFFICE)\" = trusted ]"
expect_equal "trusted" "$(band "$OFFICE")" "six successful logins make the address trusted"

section "Operator overrides"
reputation PUT override "{\"kind\": \"ip\", \"subject\": \"$ATTACKER\", \"band\": \"trusted\", \"ttl_seconds\": 600,
    \"reason\": \"known_office\", \"origin\": \"operator\", \"audit_id\": \"cookbook-test-trust\", \"previous_audit\": \"\"}"
expect_status 200 "the administrator marks the suspicious address as trusted"
auth alice alice-secret imap "$ATTACKER"
expect_auth_status "OK" "alice logs in from the trusted address again"

reputation PUT override '{"kind": "network", "subject": "203.0.113.0/24", "band": "blocked", "ttl_seconds": 600,
    "reason": "incident", "origin": "operator", "audit_id": "cookbook-test-block", "previous_audit": ""}'
expect_status 200 "the administrator blocks the network 203.0.113.0/24"
auth bob bob-secret imap 203.0.113.99
expect_auth_status "$BLOCKED_TEXT" "everybody is refused from the blocked network"

remove_network_block
expect_status 200 "the administrator removes the block"
auth bob bob-secret imap 203.0.113.99
expect_auth_status "OK" "logins from the network work again"

reputation DELETE override "{\"kind\": \"ip\", \"subject\": \"$ATTACKER\", \"previous_audit\": \"cookbook-test-trust\",
    \"audit_id\": \"cookbook-test-untrust\", \"reason\": \"test_cleanup\", \"origin\": \"operator\"}"

section "Access control of the management API"
http POST /api/v1/custom/reputation/lookup -u mailserver:mailserver-backchannel-secret \
    -H 'Content-Type: application/json' -d '{"kind": "ip", "subject": "192.0.2.1"}'
[ "$last_status" = 401 ] || [ "$last_status" = 403 ] && pass "a Basic credential cannot use the management API" ||
    fail "a Basic credential reached the management API"

section "Many requests"
wrong=0
for i in $(seq 1 100); do
    auth bob bob-secret imap "$OFFICE"
    [ "$(header Auth-Status)" = "OK" ] || wrong=$((wrong + 1))
    auth alice alice-secret imap "$OFFICE"
    [ "$(header Auth-Status)" = "OK" ] || wrong=$((wrong + 1))
done
expect_equal 0 "$wrong" "200 logins from the trusted office address got the expected answer"

valkey SREM cookbook:privileged alice >/dev/null

finish
