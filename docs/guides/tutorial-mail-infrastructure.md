---
title: "Tutorial: Mail Infrastructure"
description: Beginner-friendly tutorial for using Nauthilus with Dovecot, Postfix, pfxhttp, Valkey, and Lua hooks
keywords: [Tutorial, Mail, Dovecot, Postfix, pfxhttp, Lua, Nauthilus]
sidebar_position: 13
---

# Tutorial: Mail Infrastructure

This tutorial shows Nauthilus as a central decision point in a small mail stack. It is the most complete example in this tutorial path and combines:

- Dovecot authentication through Nauthilus
- Postfix policy checks through `pfxhttp`
- Postfix socket-map lookups through `pfxhttp`
- SMTP authentication through the `pfxhttp` Dovecot-SASL bridge
- LMTP delivery into Dovecot
- IMAP verification after delivery

Nauthilus does not replace Postfix or Dovecot. It centralizes authentication, account mapping, policy logic, and hook-based integration so the mail components can ask one consistent service for decisions.

## What You Build

The stack contains:

- Valkey for cache and operational state
- Nauthilus with a Lua backend and Lua hooks
- Dovecot for IMAP and LMTP
- Postfix for SMTP
- `pfxhttp` as the bridge between Postfix-style protocols and HTTP endpoints

It exposes:

- `http://127.0.0.1:38080` for Nauthilus
- `127.0.0.1:31143` for IMAP
- `127.0.0.1:30024` for LMTP
- `127.0.0.1:31025` for SMTP
- `127.0.0.1:33450` for the socket-map listener
- `127.0.0.1:33451` for the policy listener

Demo account:

- Username: `testuser`
- Password: `testpassword`
- Mail address: `testuser@example.test`

The diagram shows the exact services used by this tutorial and the relevant request paths between them.

![Docker-based mail stack](assets/docker-mail-stack.svg)

## Start the Stack

This example builds `pfxhttp` locally. The helper script clones `pfxhttp`, checks out `v1.2.0`, and builds the Docker image.

```bash
./setup.sh
docker compose up -d
```

If you already have a local `pfxhttp` checkout, point the helper to it:

```bash
PFXHTTP_REPO_URL="$HOME/src/pfxhttp" ./setup.sh
docker compose up -d
```

## End-to-End Checks

Check Dovecot authentication:

```bash
docker compose exec dovecot doveadm auth test testuser testpassword
```

Check the Postfix policy service:

```bash
printf 'request=smtpd_access_policy\nprotocol_state=RCPT\nprotocol_name=SMTP\nsender=alice@example.test\nrecipient=bob@example.test\nclient_address=127.0.0.1\nclient_name=localhost\n\n' | nc 127.0.0.1 33451
```

Check the socket map:

```bash
docker compose exec postfix postmap -q example.test socketmap:inet:pfxhttp:23450:demo_map
```

Send a message through SMTP:

```bash
cat <<'EOF' >/tmp/workshop-mail.txt
From: Demo Sender <alice@example.test>
To: Demo Recipient <testuser@example.test>
Subject: Workshop demo

This message is accepted for the demo and then delivered to Dovecot over LMTP.
EOF

curl --verbose --user testuser:testpassword \
  --mail-from alice@example.test \
  --mail-rcpt testuser@example.test \
  --upload-file /tmp/workshop-mail.txt \
  smtp://127.0.0.1:31025
```

Find the message through IMAP:

```bash
curl --silent --show-error \
  --user testuser:testpassword \
  --url 'imap://127.0.0.1:31143/INBOX' \
  --request 'SEARCH ALL'
```

Fetch the first message:

```bash
curl --silent --show-error \
  --user testuser:testpassword \
  --url 'imap://127.0.0.1:31143/INBOX/;MAILINDEX=1'
```

## Service Definition

The Compose file creates two internal networks:

- `nauthilus` for Valkey, Nauthilus, Postfix, Dovecot, and pfxhttp
- `dovecot` for the mail-facing relationship between Postfix, Dovecot, and Nauthilus

```yaml title="docker-compose.yml"
name: workshop-mail

services:
  valkey:
    image: valkey/valkey:8-alpine
    command:
      - valkey-server
      - --bind
      - 0.0.0.0
      - --save
      - ""
      - --appendonly
      - "no"
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 10
    networks:
      - nauthilus

  nauthilus:
    image: ghcr.io/croessner/nauthilus:v3.0.0
    depends_on:
      valkey:
        condition: service_healthy
    ports:
      - "38080:8080"
    volumes:
      - ./nauthilus/nauthilus.yml:/etc/nauthilus/nauthilus.yml:ro
      - ./nauthilus/lua:/etc/nauthilus/lua:ro
    healthcheck:
      test: ["CMD", "/usr/app/healthcheck", "--url", "http://127.0.0.1:8080/healthz"]
      interval: 10s
      timeout: 5s
      retries: 20
    networks:
      - dovecot
      - nauthilus

  dovecot:
    image: dovecot/dovecot:2.4.3
    depends_on:
      nauthilus:
        condition: service_started
    ports:
      - "31143:143"
      - "30024:24"
    volumes:
      - ./dovecot:/etc/dovecot:ro
    networks:
      - dovecot
      - nauthilus

  postfix:
    image: chrroessner/postfix:3.11.1
    depends_on:
      pfxhttp:
        condition: service_started
      dovecot:
        condition: service_started
    ports:
      - "31025:25"
    environment:
      POSTFIX_alias_database: ""
      POSTFIX_alias_maps: ""
      POSTFIX_myhostname: "postfix.workshop.local"
      POSTFIX_transport_maps: "regexp:/etc/postfix/transport.regexp"
      POSTFIX_smtpd_sasl_auth_enable: "yes"
      POSTFIX_smtpd_sasl_type: "dovecot"
      POSTFIX_smtpd_sasl_path: "inet:pfxhttp:23453"
      POSTFIX_smtpd_sasl_security_options: "noanonymous"
      POSTFIX_broken_sasl_auth_clients: "yes"
      POSTFIX_smtpd_relay_restrictions: "permit_mynetworks,permit_sasl_authenticated,reject_unauth_destination"
      POSTFIX_smtpd_recipient_restrictions: "check_policy_service inet:pfxhttp:23451"
    volumes:
      - ./postfix/transport.regexp:/etc/postfix/transport.regexp:ro
    networks:
      - dovecot
      - nauthilus

  pfxhttp:
    build:
      context: ${PFXHTTP_BUILD_CONTEXT:-./.cache/pfxhttp}
    depends_on:
      nauthilus:
        condition: service_started
    ports:
      - "33450:23450"
      - "33451:23451"
    volumes:
      - ./pfxhttp/pfxhttp.yml:/etc/pfxhttp/pfxhttp.yml:ro
    networks:
      - nauthilus

networks:
  dovecot:
  nauthilus:
```

## Nauthilus Configuration

This configuration enables three important pieces:

- a Lua backend for Dovecot and SMTP authentication
- Lua hooks for Postfix socket-map and policy requests
- backend health checks for Dovecot IMAP and LMTP

```yaml title="nauthilus/nauthilus.yml"
runtime:
  instance_name: "workshop-mail"

  servers:
    http:
      address: "0.0.0.0:8080"

  clients:
    dns:
      timeout: "2s"
      resolve_client_ip: false

observability:
  log:
    color: true
    level: "debug"
    debug_modules:
      - "feature"

storage:
  redis:
    database_number: 0
    prefix: "ntc:"
    pool_size: 10
    idle_pool_size: 4
    positive_cache_ttl: "1h"
    negative_cache_ttl: "5m"
    password_nonce: "workshopPasswordNonce03"
    encryption_secret: "workshopEncryption03"
    primary:
      address: "valkey:6379"

auth:
  request:
    headers:
      username: "X-Nauthilus-Username"
      password: "X-Nauthilus-Password"
      protocol: "X-Nauthilus-Protocol"
      local_ip: "X-Nauthilus-Local-IP"
      local_port: "X-Nauthilus-Local-Port"
      client_ip: "X-Nauthilus-Client-IP"
      client_port: "X-Nauthilus-Client-Port"
      client_host: "X-Nauthilus-Client-Host"
      ssl: "X-Nauthilus-SSL"

  backchannel:
    basic_auth:
      enabled: true
      username: "workshop-backchannel"
      password: "workshop-backchannel-secret"

  pipeline:
    max_concurrent_requests: 100

  backends:
    order:
      - "cache"
      - "lua"

    lua:
      backend:
        default:
          backend_script_path: "/etc/nauthilus/lua/backend.lua"
          package_path: "/usr/app/lua-plugins.d/share/?.lua;/etc/nauthilus/lua/?.lua"
          backend_number_of_workers: 8
          action_number_of_workers: 8
          environment_vm_pool_size: 8
          subject_vm_pool_size: 8
          hook_vm_pool_size: 8

        search:
          - protocol:
              - "doveadm"
              - "imap"
              - "lmtp"
              - "smtp"
              - "http"
            cache_name: "dovecot"

  controls:
    enabled:
      - "lua"

    lua:
      hooks:
        - http_location: "postfix/socket-map"
          http_method: "POST"
          script_path: "/etc/nauthilus/lua/postfix_socket_map.lua"

        - http_location: "postfix/policy"
          http_method: "POST"
          script_path: "/etc/nauthilus/lua/postfix_policy.lua"

  policy:
    attribute_sources:
      lua:
        subject:
          - name: "backend_health_checks"
            script_path: "/usr/app/lua-plugins.d/subject/monitoring.lua"

  services:
    enabled:
      - "backend_health_checks"

    backend_health_checks:
      targets:
        - protocol: "imap"
          host: "dovecot"
          port: 143
          deep_check: true

        - protocol: "lmtp"
          host: "dovecot"
          port: 24
          deep_check: true

identity:
  frontend:
    enabled: false
```

The `auth.request.headers` block matters because Dovecot sends authentication data to the Nauthilus header endpoint. The names configured here must match the headers created by `dovecot/auth.lua`.

## Lua Backend

The backend is intentionally small. It accepts one user and maps that user to the account name Dovecot should use.

```lua title="nauthilus/lua/backend.lua"
function nauthilus_backend_verify_password(request)
    local backend_result = nauthilus_backend_result.new()
    local attributes = {}

    if request.username == "testuser" then
        backend_result:user_found(true)
        backend_result:account_field("account")

        attributes.account = "testuser"

        if not request.no_auth and request.password == "testpassword" then
            backend_result:authenticated(true)
        end
    end

    backend_result:attributes(attributes)

    return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
end

function nauthilus_backend_list_accounts()
    return nauthilus_builtin.BACKEND_RESULT_OK, { "testuser" }
end
```

## Dovecot Authentication Bridge

Dovecot calls Nauthilus through the header endpoint. For `passdb`, it sends the submitted password. For `userdb`, it adds `?mode=no-auth` so Nauthilus resolves the user and account context without checking a password.

```lua title="dovecot/auth.lua"
local http_uri = "http://nauthilus:8080/api/v1/auth/header"

local PASSDB = "passdb"
local USERDB = "userdb"

local http_client = dovecot.http.client{
    request_timeout = "5s";
    request_max_attempts = 3;
    user_agent = "Dovecot/2.4";
}

local function query_db(request, password, dbtype)
    local username = request.username or request.user or ""
    local remote_ip = request.remote_ip or "0.0.0.0"
    local remote_port = request.remote_port or "0"
    local local_ip = request.local_ip or "0.0.0.0"
    local local_port = request.local_port or "0"
    local protocol = request.protocol or "imap"
    local query_suffix = ""
    local extra_fields = {}

    if dbtype == USERDB then
        query_suffix = "?mode=no-auth"
    end

    local auth_request = http_client:request {
        url = http_uri .. query_suffix;
        method = "POST";
    }

    auth_request:add_header("X-Nauthilus-Service", "Dovecot")
    auth_request:add_header("Authorization", "Basic d29ya3Nob3AtYmFja2NoYW5uZWw6d29ya3Nob3AtYmFja2NoYW5uZWwtc2VjcmV0")
    auth_request:add_header("X-Nauthilus-Username", username)
    auth_request:add_header("X-Nauthilus-Password", password)
    auth_request:add_header("X-Nauthilus-Client-IP", remote_ip)
    auth_request:add_header("X-Nauthilus-Client-Port", remote_port)
    auth_request:add_header("X-Nauthilus-Local-IP", local_ip)
    auth_request:add_header("X-Nauthilus-Local-Port", local_port)
    auth_request:add_header("X-Nauthilus-Protocol", protocol)

    local auth_response = auth_request:submit()
    local auth_status_code = auth_response:status()
    local auth_user = auth_response:header("Auth-User")

    if auth_status_code == 200 then
        if auth_user and auth_user ~= "" then
            extra_fields.user = auth_user
        end

        if dbtype == PASSDB then
            return dovecot.auth.PASSDB_RESULT_OK, extra_fields
        end

        return dovecot.auth.USERDB_RESULT_OK, extra_fields
    end

    if dbtype == PASSDB then
        return dovecot.auth.PASSDB_RESULT_PASSWORD_MISMATCH, ""
    end

    return dovecot.auth.USERDB_RESULT_USER_UNKNOWN, ""
end

function auth_userdb_lookup(request)
    return query_db(request, "", USERDB)
end

function auth_password_verify(request, password)
    return query_db(request, password, PASSDB)
end

function auth_passdb_lookup(request)
    local result, extra_fields = query_db(request, "", USERDB)

    if type(extra_fields) == "table" then
        extra_fields.nopassword = "y"
    else
        extra_fields = { nopassword = "y" }
    end

    return result, extra_fields
end

function script_init()
    return 0
end

function script_deinit()
end

function auth_userdb_iterate()
    return { "testuser" }
end
```

## pfxhttp Configuration

`pfxhttp` listens with Postfix-compatible interfaces and forwards requests to Nauthilus:

- socket map to `/api/v1/custom/postfix/socket-map`
- policy service to `/api/v1/custom/postfix/policy`
- Dovecot-SASL style authentication to `/api/v1/auth/json`

![pfxhttp policy and hook flow](assets/pfxhttp-policy-flow.svg)

```yaml title="pfxhttp/pfxhttp.yml"
server:
  listen:
    - kind: "socket_map"
      name: "demo_map"
      type: "tcp"
      address: "0.0.0.0"
      port: 23450

    - kind: "policy_service"
      name: "demo_policy"
      type: "tcp"
      address: "0.0.0.0"
      port: 23451

    - kind: "dovecot_sasl"
      name: "demo_sasl"
      type: "tcp"
      address: "0.0.0.0"
      port: 23453

  logging:
    json: false
    level: "debug"

  http_client:
    timeout: "10s"
    max_connections_per_host: 10
    max_idle_connections: 4
    max_idle_connections_per_host: 2
    idle_connection_timeout: "30s"

  response_cache:
    enabled: true
    ttl: "1m"

socket_maps:
  defaults:
    http_auth_basic: "workshop-backchannel:workshop-backchannel-secret"

  demo_map:
    target: "http://nauthilus:8080/api/v1/custom/postfix/socket-map"
    payload: >
      {
        "key": "{{ .Key }}"
      }
    status_code: 200
    value_field: "demo_value"
    error_field: "error"
    no_error_value: "not-found"

policy_services:
  defaults:
    http_auth_basic: "workshop-backchannel:workshop-backchannel-secret"

  demo_policy:
    target: "http://nauthilus:8080/api/v1/custom/postfix/policy"
    payload: "{{ .Key }}"
    status_code: 200
    value_field: "result"
    error_field: "error"
    no_error_value: "DUNNO"

dovecot_sasl:
  defaults:
    http_auth_basic: "workshop-backchannel:workshop-backchannel-secret"

  demo_sasl:
    target: "http://nauthilus:8080/api/v1/auth/json"
    default_local_port: "25"
    status_code: 200
```

## Postfix Routing

Postfix routes the demo recipient to Dovecot over LMTP and discards all other recipients. This keeps the setup safe and predictable.

```text title="postfix/transport.regexp"
/^testuser@example\.test$/ lmtp:dovecot:24
/./ discard:
```

## Hook: Socket Map

This hook receives the key from `pfxhttp` and returns a demo route value.

```lua title="nauthilus/lua/postfix_socket_map.lua"
local nauthilus_util = require("nauthilus_util")
local nauthilus_http_request = require("nauthilus_http_request")
local json = require("json")

local N = "postfix-socket-map"

function nauthilus_run_hook(request)
    local key = ""
    local body = nauthilus_http_request.get_http_request_body()
    local decoded, err = json.decode(body or "{}")
    if err == nil and type(decoded) == "table" and type(decoded.key) == "string" then
        key = decoded.key
    end

    local result = {
        demo_value = "workshop-route:" .. key,
    }

    if request.logging.log_level == "debug" or request.logging.log_level == "info" then
        nauthilus_util.print_result(request.logging, {
            level = "info",
            caller = N .. ".lua",
            session = request.session,
            key = key,
            value = result.demo_value,
        })
    end

    return result
end
```

## Hook: Policy Service

This hook receives SMTP policy context from `pfxhttp` and returns `DUNNO`, meaning Postfix should continue with its normal decision flow.

```lua title="nauthilus/lua/postfix_policy.lua"
local nauthilus_util = require("nauthilus_util")
local nauthilus_http_request = require("nauthilus_http_request")
local json = require("json")

local N = "postfix-policy"

function nauthilus_run_hook(request)
    local result = {
        result = "DUNNO",
    }

    local body = nauthilus_http_request.get_http_request_body()
    local decoded, err = json.decode(body or "{}")
    if err == nil and type(decoded) == "table" then
        result.recipient = decoded.recipient
        result.sender = decoded.sender
        result.client_address = decoded.client_address
    end

    if request.logging.log_level == "debug" or request.logging.log_level == "info" then
        nauthilus_util.print_result(request.logging, {
            level = "info",
            caller = N .. ".lua",
            session = request.session,
            decision = result.result,
            recipient = result.recipient or "",
            sender = result.sender or "",
        })
    end

    return result
end
```

## Setup Helper

The helper prepares the `pfxhttp` source tree and builds the local image used by Compose.

```bash title="setup.sh"
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${PFXHTTP_TARGET_DIR:-$SCRIPT_DIR/.cache/pfxhttp}"
REPO_URL="${PFXHTTP_REPO_URL:-https://github.com/croessner/pfxhttp.git}"
REF="${PFXHTTP_REF:-v1.2.0}"

mkdir -p "$(dirname "$TARGET_DIR")"

if [ ! -d "$TARGET_DIR/.git" ]; then
  git clone "$REPO_URL" "$TARGET_DIR"
fi

git -C "$TARGET_DIR" fetch --tags --force origin
git -C "$TARGET_DIR" checkout "$REF"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" build pfxhttp

printf 'pfxhttp source prepared in %s at ref %s\n' "$TARGET_DIR" "$REF"
```

## What You Should Understand

After this tutorial, you should be able to explain:

- why Nauthilus is useful as a central decision service in mail environments
- how Dovecot passes authentication requests to Nauthilus
- how `pfxhttp` translates Postfix policy, socket-map, and SASL-style requests into HTTP calls
- how Nauthilus Lua hooks return values to mail-facing components
- why backend logic, hook logic, health checks, and request headers are separate configuration areas

## Good Experiments

1. Change the policy hook to return `REJECT blocked by tutorial` for a specific sender.
2. Add another user to `backend.lua` and test SMTP and IMAP authentication.
3. Change the transport map so another recipient is delivered to Dovecot over LMTP.
4. Rename one `X-Nauthilus-*` header in `nauthilus.yml`, then adjust `dovecot/auth.lua` to match.
