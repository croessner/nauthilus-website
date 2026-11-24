#!/usr/bin/env bash
# Shared helpers for the test.sh scripts of the Nauthilus Lua Cookbook.
# A recipe sets NAUTHILUS_URL and the backchannel credentials, sources this file, and calls the check functions.
# Every check prints one line; finish prints a summary and sets the exit code.

set -u

COOKBOOK_PASSED=0
COOKBOOK_FAILED=0
COOKBOOK_KNOWN=0

# Defaults used by auth(); a recipe may override them before calling auth().
AUTH_CREDENTIAL="${AUTH_CREDENTIAL:-mailserver:mailserver-backchannel-secret}"

# last_status, last_headers, and last_body hold the parts of the most recent HTTP response.
last_status=""
last_headers=""
last_body=""

# http sends one request and stores status, headers, and body. Arguments: method path [curl options...]
http() {
    local method="$1" path="$2"
    shift 2

    local header_file
    header_file="$(mktemp)"

    last_body="$(curl -sS -X "$method" -D "$header_file" -o - "$@" "${NAUTHILUS_URL}${path}")"
    last_headers="$(tr -d '\r' < "$header_file")"
    last_status="$(printf '%s\n' "$last_headers" | awk 'NR == 1 { print $2 }')"

    rm -f "$header_file"
}

# auth checks one login through /api/v1/auth/json. Arguments: username password protocol client_ip
auth() {
    http POST /api/v1/auth/json \
        -u "$AUTH_CREDENTIAL" \
        -H 'Content-Type: application/json' \
        -d "{\"username\":\"$1\",\"password\":\"$2\",\"protocol\":\"$3\",\"client_ip\":\"$4\"}"
}

# header prints the value of one response header of the last response.
header() {
    printf '%s\n' "$last_headers" | awk -v name="$1" 'BEGIN { IGNORECASE = 1 }
        tolower($0) ~ "^" tolower(name) ":" { sub(/^[^:]*: */, ""); print; exit }'
}

# pass and fail record the outcome of one check.
pass() {
    COOKBOOK_PASSED=$((COOKBOOK_PASSED + 1))
    printf '  ok    %s\n' "$1"
}

fail() {
    COOKBOOK_FAILED=$((COOKBOOK_FAILED + 1))
    printf '  FAIL  %s\n' "$1"
    printf '        status=%s auth-status=%s body=%s\n' "$last_status" "$(header Auth-Status)" "${last_body:0:300}"
}

# expect_status checks the HTTP status of the last response. Arguments: expected description
expect_status() {
    if [ "$last_status" = "$1" ]; then pass "$2"; else fail "$2 (expected HTTP $1)"; fi
}

# expect_auth_status checks the Auth-Status header of the last response. Arguments: expected description
expect_auth_status() {
    if [ "$(header Auth-Status)" = "$1" ]; then pass "$2"; else fail "$2 (expected Auth-Status: $1)"; fi
}

# expect_body_contains checks that the last response body contains a string. Arguments: needle description
expect_body_contains() {
    case "$last_body" in
        *"$1"*) pass "$2" ;;
        *) fail "$2 (expected body to contain $1)" ;;
    esac
}

# expect_equal compares two values. Arguments: expected actual description
expect_equal() {
    if [ "$1" = "$2" ]; then
        pass "$3"
    else
        COOKBOOK_FAILED=$((COOKBOOK_FAILED + 1))
        printf '  FAIL  %s\n        expected: %s\n        actual:   %s\n' "$3" "$1" "$2"
    fi
}

# known_issue records a check that is expected to fail because of a reported Nauthilus bug. It does not fail the
# run, but says so loudly when the check starts to pass. Arguments: description result(0 = check passed)
known_issue() {
    if [ "$2" -eq 0 ]; then
        pass "$1 (known issue is fixed in this release)"
    else
        COOKBOOK_KNOWN=$((COOKBOOK_KNOWN + 1))
        printf '  known %s\n' "$1"
    fi
}

# valkey runs a valkey-cli command inside the valkey service of the recipe.
valkey() {
    docker compose exec -T valkey valkey-cli "$@"
}

# wait_until re-evaluates a shell condition up to 20 times, half a second apart. POST-actions run after the answer,
# so their effects appear with a short delay. Argument: condition as one string, e.g. '[ "$(valkey GET k)" = 1 ]'
wait_until() {
    local attempt

    for attempt in $(seq 1 20); do
        if eval "$1" >/dev/null 2>&1; then
            return 0
        fi

        sleep 0.5
    done

    return 1
}

# section prints a heading for a group of checks.
section() {
    printf '\n%s\n' "$1"
}

# finish prints the summary and exits non-zero if any check failed.
finish() {
    printf '\n%d checks passed, %d failed, %d known issues\n' "$COOKBOOK_PASSED" "$COOKBOOK_FAILED" "$COOKBOOK_KNOWN"

    [ "$COOKBOOK_FAILED" -eq 0 ]
}
