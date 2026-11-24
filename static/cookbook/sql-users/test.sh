#!/usr/bin/env bash
# Checks the "SQL users" recipe. Start the stack first: docker compose up -d --wait
cd "$(dirname "$0")" || exit 1
. ../lib/cookbook.sh

NAUTHILUS_URL="${NAUTHILUS_URL:-http://127.0.0.1:28082}"
ADMIN="admin:admin-backchannel-secret"

# sql runs one statement as the MariaDB root user and prints the result without headers.
sql() {
    docker compose exec -T mariadb mariadb -uroot -pcookbook-root -N -B cookbook -e "$1"
}

# mfa calls the MFA backchannel API. Arguments: method path json
mfa() {
    http "$1" "/api/v1/mfa-backchannel$2" -u "$ADMIN" -H 'Content-Type: application/json' -d "$3"
}

section "Lua backend: password checks"
auth alice alice-secret imap 192.0.2.10
expect_auth_status "OK" "alice logs in with her username ({SSHA512} hash)"
expect_body_contains '"account":["alice@example.test"]' "the account field is the mail address"

auth alice@example.test alice-secret imap 192.0.2.10
expect_auth_status "OK" "alice logs in with her mail address"

auth bob bob-secret smtp 192.0.2.10
expect_auth_status "OK" "bob logs in (bcrypt hash)"

auth bob not-bobs-password imap 192.0.2.11
expect_auth_status "Invalid login or password" "a wrong password is rejected"

auth dave dave-secret imap 192.0.2.12
expect_auth_status "Invalid login or password" "the disabled account dave is rejected"

section "Lua backend: account listing"
http GET '/api/v1/auth/json?mode=list-accounts' -u "$ADMIN" -H 'Accept: application/json'
expect_body_contains '"alice@example.test"' "list-accounts contains alice"
expect_body_contains '"bob@example.test"' "list-accounts contains bob"
case "$last_body" in
    *dave*) fail "list-accounts must not contain the disabled account dave" ;;
    *) pass "list-accounts leaves out the disabled account dave" ;;
esac

section "Lua backend: MFA callbacks"
mfa POST /totp/recovery-codes '{"backend":"lua","username":"bob@example.test","codes":["aaaa-1111","bbbb-2222"]}'
expect_status 200 "recovery codes are accepted"
expect_equal "2" "$(sql 'SELECT COUNT(*) FROM recovery_codes')" "nauthilus_backend_add_totp_recovery_codes stored two codes"

mfa DELETE /totp/recovery-codes '{"backend":"lua","username":"bob@example.test"}'
expect_equal "0" "$(sql 'SELECT COUNT(*) FROM recovery_codes')" "nauthilus_backend_delete_totp_recovery_codes removed them"

mfa POST /totp '{"backend":"lua","username":"bob@example.test","totp_secret":"JBSWY3DPEHPK3PXP"}'
expect_status 200 "a TOTP secret is accepted"
[ "$(sql "SELECT totp_secret FROM accounts WHERE username = 'bob'")" = "JBSWY3DPEHPK3PXP" ]
known_issue "nauthilus_backend_add_totp stores the secret (request.totp_secret is not passed to Lua)" $?

sql "UPDATE accounts SET totp_secret = 'JBSWY3DPEHPK3PXP' WHERE username = 'bob'"
mfa DELETE /totp '{"backend":"lua","username":"bob@example.test"}'
expect_equal "NULL" "$(sql "SELECT totp_secret FROM accounts WHERE username = 'bob'")" "nauthilus_backend_delete_totp removed the secret"

section "Prepared statements are closed"
for i in $(seq 1 30); do auth "bob" "bob-secret-$i" imap "192.0.2.$((i + 20))"; done
expect_equal "0" "$(sql "SHOW GLOBAL STATUS LIKE 'Prepared_stmt_count'" | awk '{ print $2 }')" "MariaDB holds no open prepared statements"

finish
