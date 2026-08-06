---
title: Admin Client
description: Operate the protected Nauthilus REST API with the bundled Python client
keywords: [Administration, REST API, OIDC, Cache, Brute Force, Sessions]
sidebar_position: 30
---

# Admin Client

`contrib/client/nauthilus-admin.py` is a dependency-free Python 3 client for Nauthilus backchannel operations. It can
obtain an OIDC Client Credentials token, use a pre-issued Bearer token, or authenticate with configured backchannel
Basic credentials.

Run it from a Nauthilus source checkout:

```bash
python3 contrib/client/nauthilus-admin.py --help
```

The client supports token-cache inspection, OpenAPI download, cache flushes, brute-force administration, asynchronous
job polling, OIDC session administration, JSON authentication tests, and arbitrary management requests.

## Authentication Configuration

Settings can come from command-line flags, process environment variables, or an env-style file. Precedence is command
line, process environment, env file, then built-in default.

### OIDC Client Credentials

Create a confidential OIDC client with the `client_credentials` grant. Every protected backchannel request needs
`nauthilus:authenticate`; add only the route-specific scopes the operator needs.

Example `/etc/nauthilus/admin-client.env`:

```dotenv
NAUTHILUS_URL=https://nauthilus.example.com
NAUTHILUS_TOKEN_URL=https://nauthilus.example.com/oidc/token
NAUTHILUS_CLIENT_ID=operations-client
NAUTHILUS_CLIENT_SECRET_FILE=/etc/nauthilus/secrets/operations-client-secret
NAUTHILUS_CLIENT_AUTH_METHOD=basic
NAUTHILUS_SCOPES=nauthilus:authenticate nauthilus:admin nauthilus:security
```

Protect both files from other users:

```bash
chmod 0600 /etc/nauthilus/admin-client.env
chmod 0600 /etc/nauthilus/secrets/operations-client-secret
```

`NAUTHILUS_CLIENT_AUTH_METHOD` accepts `basic` and `post`. Do not add `openid` to the client-credentials scope list.

Run a command with the file:

```bash
python3 contrib/client/nauthilus-admin.py \
  --env-file /etc/nauthilus/admin-client.env \
  openapi json
```

You can also set `NAUTHILUS_ENV_FILE` instead of repeating `--env-file`.

### Pre-issued Bearer Token

Use `--bearer-token-file` or `NAUTHILUS_BEARER_TOKEN_FILE` to read a token without placing it in the process arguments:

```dotenv
NAUTHILUS_URL=https://nauthilus.example.com
NAUTHILUS_BEARER_TOKEN_FILE=/run/secrets/nauthilus-admin-token
```

### Backchannel Basic Authentication

For deployments that use `auth.backchannel.basic_auth`, configure:

```dotenv
NAUTHILUS_URL=https://nauthilus.example.com
NAUTHILUS_BASIC_USER=operator
NAUTHILUS_BASIC_PASSWORD_FILE=/etc/nauthilus/secrets/admin-basic-password
```

Backchannel Basic authentication is an administrative credential and is not restricted by Bearer scopes. Prefer a
least-privilege OIDC client where scope separation is required.

## TLS and Address Overrides

TLS certificate verification is enabled by default. `--insecure` or `NAUTHILUS_INSECURE=true` disables it and should be
limited to isolated development environments.

If the client must connect to an internal address while verifying the public certificate and preserving TLS SNI, use a
resolve override:

```dotenv
NAUTHILUS_RESOLVE=nauthilus.example.com:443:192.0.2.10
```

The format is `host:port:address`. Multiple CLI `--resolve` flags or comma-separated environment values are supported.

## Token Cache

OIDC access tokens are cached until shortly before expiry. The default cache path is:

- `$XDG_RUNTIME_DIR/nauthilus-admin-token.json` when `XDG_RUNTIME_DIR` is available;
- otherwise `~/.cache/nauthilus-admin/token.json`.

The client writes the cache with mode `0600`. Override it with `--token-cache` or `NAUTHILUS_TOKEN_CACHE`; use `off` to
disable caching.

```bash
# Show metadata without printing the access token.
python3 contrib/client/nauthilus-admin.py \
  --env-file /etc/nauthilus/admin-client.env \
  token status

# Remove the cached token.
python3 contrib/client/nauthilus-admin.py \
  --env-file /etc/nauthilus/admin-client.env \
  token clear
```

## Common Operations

The examples below omit the repeated `--env-file /etc/nauthilus/admin-client.env` option for readability.

### OpenAPI

```bash
python3 contrib/client/nauthilus-admin.py openapi json
python3 contrib/client/nauthilus-admin.py --output body openapi yaml
```

### Cache Flush

```bash
# Synchronous single-user flush.
python3 contrib/client/nauthilus-admin.py cache flush alice@example.test

# Enqueue and wait for an asynchronous flush.
python3 contrib/client/nauthilus-admin.py \
  cache flush alice@example.test --async --wait

# Read users from a file, show live progress, and aggregate failures.
python3 contrib/client/nauthilus-admin.py \
  cache flush-file users.txt \
  --async --wait --live --continue-on-error
```

Use `-` instead of the filename to read users from standard input. `--pending-ok` leaves unfinished batch jobs as
`PENDING` instead of turning them into timeout failures.

### Brute-force State

```bash
python3 contrib/client/nauthilus-admin.py \
  bruteforce list --account alice@example.test --limit 100

python3 contrib/client/nauthilus-admin.py \
  bruteforce flush \
  --ip 203.0.113.10 \
  --rule rule-a \
  --protocol imap
```

Add `--async --wait` to enqueue a brute-force flush and wait for its result.

### Asynchronous Jobs

```bash
python3 contrib/client/nauthilus-admin.py async status JOB_ID
python3 contrib/client/nauthilus-admin.py async wait JOB_ID
```

`--wait-timeout` and `--wait-interval` control polling.

### OIDC Sessions

```bash
# List token-safe session metadata for a user.
python3 contrib/client/nauthilus-admin.py oidc sessions list alice

# Delete all sessions for a user.
python3 contrib/client/nauthilus-admin.py oidc sessions delete alice

# Delete one session using the non-secret id returned by the list command.
python3 contrib/client/nauthilus-admin.py \
  oidc sessions delete alice --token "$SESSION_ID"
```

The option remains named `--token` for compatibility, but its value is the non-secret session-list `id`. Raw access
tokens are not returned by the management API. Use the all-sessions delete operation for complete user-wide access and
refresh-token revocation, including dynamic-client token families.

### Authentication Test

Avoid passwords in shell history. Use `--ask-pass` or `--password-file`:

```bash
python3 contrib/client/nauthilus-admin.py \
  auth json \
  --user alice@example.test \
  --ask-pass \
  --protocol imap \
  --method plain
```

The same helper can test `--mode no-auth` or `--mode list-accounts`. `--no-cache` and `--no-memory` disable the
corresponding lookup layers for the request.

## Raw Requests

The `raw` command reaches a management route that does not yet have a convenience subcommand:

```bash
python3 contrib/client/nauthilus-admin.py \
  raw GET /api/v1/openapi.json

python3 contrib/client/nauthilus-admin.py \
  raw DELETE /api/v1/cache/flush \
  --data '{"user":"alice@example.test"}'
```

Use `--data-file` for sensitive or larger JSON bodies, repeat `--query key=value` for query parameters, and repeat
`--header key=value` for extra headers. `--no-auth` deliberately suppresses the authorization header.

## Output Formats

`--output` accepts:

- `pretty`: formatted JSON or text, the default;
- `json`: compact JSON;
- `body`: response body only;
- `headers`: status and response headers as JSON.

For route requirements and response contracts, see [REST API](../rest-api.md) and the generated
[API Reference](../api-reference/index.md).
