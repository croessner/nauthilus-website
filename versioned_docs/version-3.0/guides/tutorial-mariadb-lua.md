---
title: "Tutorial: MariaDB + Lua"
description: Beginner-friendly tutorial for authenticating through MariaDB and a Lua backend
keywords: [Tutorial, MariaDB, Lua, SQL, Nauthilus, Valkey]
sidebar_position: 12
---

# Tutorial: MariaDB + Lua

This tutorial shows how Nauthilus can authenticate users without LDAP. MariaDB stores the account data, while a Lua backend implements the lookup and password verification logic.

Use this tutorial if your real deployment needs to connect Nauthilus to an existing application database or if you want to understand where custom backend logic belongs.

## What You Build

The stack contains:

- Valkey for cache and operational state
- MariaDB for account data
- Nauthilus with a Lua backend

It exposes:

- `http://127.0.0.1:28080` for Nauthilus
- `127.0.0.1:23306` for MariaDB

Demo accounts:

| Username | Account | Password |
| --- | --- | --- |
| `alice` | `alice@example.test` | `mailsecret` |
| `bob` | `bob@example.test` | `mailsecret` |

The database stores password hashes. The Lua backend verifies them with `nauthilus_password.compare_passwords(...)`.

## Start the Stack

Create the files shown below in one directory, then start the services:

```bash
docker compose up -d
```

Check that MariaDB contains the demo users:

```bash
docker compose exec mariadb mariadb \
  -uworkshop \
  -pworkshop \
  -D workshop \
  -e 'SELECT username, account FROM accounts ORDER BY id ASC;'
```

Authenticate through Nauthilus:

```bash
docker compose exec nauthilus curl -i -sS \
  -u workshop-backchannel:workshop-backchannel-secret \
  http://127.0.0.1:8080/api/v1/auth/json \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice","password":"mailsecret","protocol":"http","service":"workshop"}'
```

Expected result:

- HTTP `200`
- `Auth-Status: OK`
- a JSON response that includes the account attributes returned by Lua

## Service Definition

`docker-compose.yml` starts MariaDB, imports the SQL seed data, mounts the Lua backend, and starts Nauthilus after Valkey and MariaDB are healthy.

```yaml title="docker-compose.yml"
name: workshop-mariadb-lua

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

  mariadb:
    image: mariadb:11.8
    environment:
      MARIADB_DATABASE: workshop
      MARIADB_USER: workshop
      MARIADB_PASSWORD: workshop
      MARIADB_ROOT_PASSWORD: workshop-root
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
    ports:
      - "23306:3306"
    volumes:
      - mariadb_data:/var/lib/mysql
      - ./mariadb/initdb:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD", "mariadb-admin", "ping", "-h", "127.0.0.1", "-uroot", "-pworkshop-root"]
      interval: 10s
      timeout: 5s
      retries: 20

  nauthilus:
    image: ghcr.io/croessner/nauthilus:v3.0.0
    depends_on:
      valkey:
        condition: service_healthy
      mariadb:
        condition: service_healthy
    ports:
      - "28080:8080"
    volumes:
      - ./nauthilus/nauthilus.yml:/etc/nauthilus/nauthilus.yml:ro
      - ./nauthilus/lua:/etc/nauthilus/lua:ro
    healthcheck:
      test: ["CMD", "/usr/app/healthcheck", "--url", "http://127.0.0.1:8080/healthz"]
      interval: 10s
      timeout: 5s
      retries: 20

volumes:
  mariadb_data:
```

## Nauthilus Configuration

The important difference from the OpenLDAP tutorial is `auth.backends.lua.backend`. Nauthilus loads a Lua script and calls it as the authentication backend.

```yaml title="nauthilus/nauthilus.yml"
runtime:
  instance_name: "workshop-mariadb-lua"

  servers:
    http:
      address: "0.0.0.0:8080"

observability:
  log:
    level: "debug"
    json: false
    color: true

storage:
  redis:
    primary:
      address: "valkey:6379"
    database_number: 0
    prefix: "nt:"
    pool_size: 16
    idle_pool_size: 4
    positive_cache_ttl: "1h"
    negative_cache_ttl: "5m"
    password_nonce: "workshopPasswordNonce02"
    encryption_secret: "workshopEncryption02"

auth:
  backchannel:
    basic_auth:
      enabled: true
      username: "workshop-backchannel"
      password: "workshop-backchannel-secret"

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
              - "http"
            cache_name: "mariadb"
```

The `search` entry says that HTTP authentication requests use this Lua backend and cache results under the `mariadb` cache namespace.

## Database Schema and Seed Data

MariaDB creates a small account table. The unique keys make it possible to log in either by `username` or by `account`.

```sql title="mariadb/initdb/01-schema.sql"
CREATE TABLE IF NOT EXISTS accounts (
  id INT NOT NULL AUTO_INCREMENT,
  username VARCHAR(255) NOT NULL,
  account VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  mail VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY username_idx (username),
  UNIQUE KEY account_idx (account)
);

INSERT INTO accounts (username, account, password, display_name, mail)
VALUES
  ('alice', 'alice@example.test', '$1$workshop$pbLzRf8vxEstvCvPOp2Ns1', 'Alice Example', 'alice@example.test'),
  ('bob', 'bob@example.test', '$1$workshop$GOSl9Q0FVHXsURHkMk0fF0', 'Bob Example', 'bob@example.test');
```

## Lua Backend

The Lua backend is where the site-specific logic lives:

- open a read-only MariaDB connection
- find a user by `username` or `account`
- compare the stored hash with the submitted password
- return account attributes to Nauthilus
- provide account enumeration through `nauthilus_backend_list_accounts`

```lua title="nauthilus/lua/backend.lua"
local nauthilus_util = require("nauthilus_util")
local nauthilus_password = require("nauthilus_password")
local db = require("db")

local DB_DSN = os.getenv("WORKSHOP_MARIADB_DSN") or "workshop:workshop@tcp(mariadb:3306)/workshop"

local DB_CONFIG = {
    shared = true,
    max_connections = 10,
    read_only = true,
}

local function sql_string(value)
    return string.format("%q", tostring(value or ""))
end

local function row_to_record(result, row)
    local record = {}

    for index, column in ipairs(result.columns) do
        record[column] = row[index]
    end

    return record
end

function nauthilus_backend_verify_password(request)
    local backend_result = nauthilus_backend_result.new()

    local mysql, err_open = db.open("mysql", DB_DSN, DB_CONFIG)
    nauthilus_util.if_error_raise(err_open)

    local identifier = sql_string(request.username)
    local query = "SELECT username, account, password, display_name, mail FROM accounts WHERE username = " ..
        identifier .. " OR account = " .. identifier .. " LIMIT 1;"

    local result, err_query = mysql:query(query)
    nauthilus_util.if_error_raise(err_query)

    if result.rows == nil or #result.rows == 0 then
        backend_result:user_found(false)
        backend_result:authenticated(false)
        backend_result:attributes({ reason = "user_not_found" })

        return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
    end

    local record = row_to_record(result, result.rows[1])
    local is_authenticated = true

    if not request.no_auth then
        local password_hash = tostring(record.password or "")
        local plain_password = tostring(request.password or "")
        local match, err_password = nauthilus_password.compare_passwords(password_hash, plain_password)
        nauthilus_util.if_error_raise(err_password)

        is_authenticated = match
    end

    backend_result:user_found(true)
    backend_result:authenticated(is_authenticated)
    backend_result:account_field("account")
    backend_result:display_name_field("display_name")
    backend_result:attributes({
        username = record.username,
        account = record.account,
        display_name = record.display_name,
        mail = record.mail,
    })

    return nauthilus_builtin.BACKEND_RESULT_OK, backend_result
end

function nauthilus_backend_list_accounts()
    local mysql, err_open = db.open("mysql", DB_DSN, DB_CONFIG)
    nauthilus_util.if_error_raise(err_open)

    local result, err_query = mysql:query("SELECT account FROM accounts ORDER BY id ASC;")
    nauthilus_util.if_error_raise(err_query)

    local accounts = {}

    for _, row in ipairs(result.rows or {}) do
        accounts[#accounts + 1] = row[1]
    end

    return nauthilus_builtin.BACKEND_RESULT_OK, accounts
end
```

## What to Notice

The Lua backend does not replace Nauthilus. It only owns the part that is specific to this account database. Nauthilus still provides:

- HTTP endpoints
- backchannel authentication
- caching through Valkey
- request parsing
- backend result handling

That split is the main design idea. YAML wires the system together; Lua contains the custom business logic.

## Good Experiments

1. Insert another user into `accounts` and authenticate as that user.
2. Change the Lua query so only `username` is accepted, then try logging in with `alice@example.test`.
3. Add an extra attribute such as `tenant` to the table and return it from Lua.
4. Change `WORKSHOP_MARIADB_DSN` and point the backend at another database.

Continue with [Tutorial: Mail Infrastructure](tutorial-mail-infrastructure.md) when you want to see Nauthilus inside a more realistic mail flow.
