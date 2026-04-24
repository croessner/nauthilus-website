---
title: "Tutorial: OpenLDAP"
description: Beginner-friendly OpenLDAP tutorial for a first Nauthilus deployment
keywords: [Tutorial, OpenLDAP, LDAP, Nauthilus, Valkey]
sidebar_position: 11
---

# Tutorial: OpenLDAP

This is the smallest useful Nauthilus setup in these tutorials. It gives you a running authentication stack with three services:

- Valkey for cache and operational state
- OpenLDAP as the user directory
- Nauthilus as the HTTP-facing authentication service

Use this tutorial first if you want to understand how Nauthilus talks to a directory backend, how the backchannel API is called, and how the current configuration structure is organized.

## What You Build

The stack exposes:

- `http://127.0.0.1:18080` for Nauthilus
- `ldap://127.0.0.1:18389` for OpenLDAP

The demo user is:

- Username: `alice`
- Login request username: `alice@workshop.local`
- Password: `workshopSecret1!`

## Start the Stack

Create the files shown below in one directory, then start the services:

```bash
docker compose up -d
```

When the services are healthy, run the direct authentication check:

```bash
docker compose exec nauthilus curl -i -sS \
  -u workshop-backchannel:workshop-backchannel-secret \
  http://127.0.0.1:8080/api/v1/auth/json \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice@workshop.local","password":"workshopSecret1!","protocol":"http","service":"workshop"}'
```

Expected result:

- HTTP `200`
- `Auth-Status: OK`
- a JSON response with `"ok": true`

Try the failing path as well:

```bash
docker compose exec nauthilus curl -i -sS \
  -u workshop-backchannel:workshop-backchannel-secret \
  http://127.0.0.1:8080/api/v1/auth/json \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice@workshop.local","password":"definitely-wrong","protocol":"http","service":"workshop"}'
```

Expected result:

- HTTP `403`
- `Auth-Status: Invalid login or password`

## Service Definition

`docker-compose.yml` starts the three containers and wires Nauthilus to OpenLDAP and Valkey. The important part is that Nauthilus receives its configuration from `/etc/nauthilus/nauthilus.yml`, while OpenLDAP imports the bootstrap LDIF at startup.

```yaml title="docker-compose.yml"
name: workshop-openldap

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

  openldap:
    image: chrroessner/openldap:latest
    environment:
      LDAP_DOMAIN: workshop.local
      LDAP_BASE_DN: dc=workshop,dc=local
      LDAP_ORGANISATION: Workshop Org
      LDAP_ADMIN_PASSWORD: workshopAdmin
      LDAP_ENABLE_TLS: "false"
      LDAP_ENABLE_LDAPS: "false"
    ports:
      - "18389:389"
    volumes:
      - openldap_data:/var/lib/openldap/openldap-data
      - openldap_accesslog:/var/lib/openldap/accesslog
      - ./openldap/bootstrap:/docker-entrypoint-initdb.d:ro

  nauthilus:
    image: ghcr.io/croessner/nauthilus:v3.0.0
    depends_on:
      valkey:
        condition: service_healthy
      openldap:
        condition: service_started
    ports:
      - "18080:8080"
    volumes:
      - ./nauthilus/nauthilus.yml:/etc/nauthilus/nauthilus.yml:ro
    healthcheck:
      test: ["CMD", "/usr/app/healthcheck", "--url", "http://127.0.0.1:8080/healthz"]
      interval: 10s
      timeout: 5s
      retries: 20

volumes:
  openldap_data:
  openldap_accesslog:
```

## Nauthilus Configuration

This file is the main learning target. It shows the current root sections:

- `runtime` for listener and instance identity
- `observability` for logging
- `storage.redis` for Valkey
- `auth.backchannel` for API access used by the checks
- `auth.backends.ldap` for LDAP lookup and password verification

```yaml title="nauthilus/nauthilus.yml"
runtime:
  instance_name: "workshop-openldap"

  listen:
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
    password_nonce: "workshopPasswordNonce01"
    encryption_secret: "workshopEncryption01"

auth:
  backchannel:
    basic_auth:
      enabled: true
      username: "workshop-backchannel"
      password: "workshop-backchannel-secret"

  backends:
    order:
      - "cache"
      - "ldap"

    ldap:
      default:
        server_uri:
          - "ldap://openldap:389"
        bind_dn: "cn=admin,dc=workshop,dc=local"
        bind_pw: "workshopAdmin"
        lookup_pool_size: 5
        lookup_idle_pool_size: 2
        auth_pool_size: 5
        auth_idle_pool_size: 2

      search:
        - protocol:
            - "http"
          cache_name: "ldap"
          base_dn: "ou=people,dc=workshop,dc=local"
          filter:
            user: "(uid=%{username})"
            list_accounts: "(uid=*)"
          mapping:
            account_field: "uid"
            display_name_field: "cn"
            unique_user_id_field: "uid"
          attribute:
            - "uid"
            - "cn"
            - "mail"
```

Notice the backend order:

```yaml
auth:
  backends:
    order:
      - "cache"
      - "ldap"
```

Nauthilus checks its cache first. If no reusable result exists, it queries LDAP.

## LDAP Bootstrap Data

The LDIF creates one user and one group. The user has the attributes Nauthilus later returns from LDAP.

```ldif title="openldap/bootstrap/20-workshop-user.ldif"
dn: uid=alice,ou=people,dc=workshop,dc=local
changetype: add
objectClass: top
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: posixAccount
cn: Alice Workshop
sn: Workshop
givenName: Alice
uid: alice
uidNumber: 10001
gidNumber: 10001
homeDirectory: /home/alice
mail: alice@workshop.local
userPassword: workshopSecret1!

dn: cn=mail-users,ou=groups,dc=workshop,dc=local
changetype: add
objectClass: top
objectClass: groupOfNames
cn: mail-users
member: uid=alice,ou=people,dc=workshop,dc=local
```

The important match is between the request username and the LDAP search filter:

```yaml
filter:
  user: "(uid=%{username})"
```

The demo request sends `alice@workshop.local`. Nauthilus normalizes the username for the lookup context, so the LDAP lookup resolves `uid=alice`.

## Good Experiments

1. Change `observability.log.level` from `debug` to `info`, restart Nauthilus, and compare the logs.
2. Add another LDAP attribute to `auth.backends.ldap.search[0].attribute`.
3. Change the LDAP `user` filter and check how authentication fails.
4. Change `positive_cache_ttl` to a short value and repeat the same login several times.

## What You Should Understand

After this tutorial, you should be able to explain:

- why Valkey is present even in a small setup
- how Nauthilus finds the LDAP server
- how backchannel basic auth protects the direct API check
- where LDAP attributes are mapped into the authentication response

Continue with [Tutorial: MariaDB + Lua](tutorial-mariadb-lua.md) when you want to see the same idea without LDAP.
