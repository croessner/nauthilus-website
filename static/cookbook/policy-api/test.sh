#!/usr/bin/env bash
# Checks the "Policy API" recipe. Start the stack first: ./setup.sh && docker compose up -d --wait
cd "$(dirname "$0")" || exit 1
. ../lib/cookbook.sh

NAUTHILUS_URL="${NAUTHILUS_URL:-https://127.0.0.1:28086}"
GATEWAY="vpn-gateway:vpn-gateway-policy-secret"

# connect asks whether a user of a group may connect at a weekday and hour. Arguments: group weekday hour
connect() {
    http POST /api/v1/policy/decisions --cacert tls/server.crt -u "$GATEWAY" \
        -H 'Content-Type: application/json' \
        -d "{
              \"version\": \"1\",
              \"target\": {\"namespace\": \"vpn\", \"action\": \"connect\"},
              \"subject\": {\"type\": \"user\", \"id\": \"alice\", \"attributes\": {\"group\": {\"string\": \"$1\"}}},
              \"environment\": {\"service\": \"vpn\", \"attributes\": {
                  \"weekday\": {\"string\": \"$2\"}, \"hour\": {\"integer\": \"$3\"}}}
            }"
}

# expect_effect checks the decision of the last answer. Arguments: effect description
expect_effect() {
    expect_body_contains "\"effect\":\"$1\"" "$2"
}

section "Office hours"
connect staff mon 9
expect_status 200 "the Policy API answers"
expect_effect permit "staff may connect on Monday at 09:00"

connect staff mon 19
expect_effect deny "staff may not connect on Monday at 19:00"
expect_body_contains '"code":"policy_denied"' "the deny comes from the rule, which also runs the audit obligation"

connect staff sat 10
expect_effect deny "staff may not connect on Saturday"

connect admins sun 3
expect_effect permit "admins may connect at any time"

connect contractors thu 16
expect_effect permit "contractors may connect on Thursday at 16:00"

connect contractors fri 10
expect_effect deny "contractors may not connect on Friday"

connect visitors mon 9
expect_effect deny "an unknown group is denied"

section "Admission"
http POST /api/v1/policy/decisions --cacert tls/server.crt -u vpn-gateway:wrong-password-1234 \
    -H 'Content-Type: application/json' -d '{"version": "1", "target": {"namespace": "vpn", "action": "connect"}}'
expect_status 401 "a wrong password is rejected"

http POST /api/v1/policy/decisions --cacert tls/server.crt -u "$GATEWAY" -H 'Content-Type: application/json' \
    -d '{"version": "1", "target": {"namespace": "vpn", "action": "connect"},
         "subject": {"type": "user", "id": "alice", "attributes": {"department": {"string": "it"}}}}'
expect_status 403 "a fact outside the client profile is refused"

section "Many requests"
wrong=0
for hour in $(seq 0 23); do
    for day in mon sat; do
        connect staff "$day" "$hour"
        expected=deny
        [ "$day" = mon ] && [ "$hour" -ge 7 ] && [ "$hour" -lt 19 ] && expected=permit
        case "$last_body" in *"\"effect\":\"$expected\""*) ;; *) wrong=$((wrong + 1)) ;; esac
    done
done
expect_equal 0 "$wrong" "48 decisions over a whole Monday and Saturday are right"

finish
