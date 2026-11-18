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
job polling, OIDC session administration, reputation administration, read-only support history lookups, JSON
authentication tests, and arbitrary management requests.

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
Without `NAUTHILUS_SCOPES`, the client requests `nauthilus:authenticate nauthilus:admin nauthilus:security`. The
[support history](#support-history) commands need `nauthilus:history_read` (and optionally
`nauthilus:history_detail`) in that list; administrative scopes do not grant history access.

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
Repeated `--resolve` flags replace `NAUTHILUS_RESOLVE` instead of adding to it; without CLI overrides, the process
environment takes precedence over the env file.

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

`bruteforce list` requests a bounded page of 100 entries by default. The IP and account filters apply to separate
result sections, so `--ip` alone still lists affected accounts. An unbounded account listing can exceed a reverse
proxy's response-header timeout. For an incident, use both filters, or inspect `page.has_more` and request further
pages with `--limit 100 --offset 100` and then the returned `next_offset` values. A page is not the complete list.
Affected accounts age out: an account stays listed for at least
`auth.controls.brute_force.affected_accounts.retention` (default `24h`) after its last counted failed or blocked
request, and while it still has an IP history.

By default, `--account` names are checked literally. With `--via-mapping`, the client asks the server to also check
the accounts Nauthilus stored for each login name (`account_resolution: account_mapping`, 1 to 100 names, at least
one `--account`):

```bash
python3 contrib/client/nauthilus-admin.py \
  bruteforce list --account alias@example.test --via-mapping
```

The JSON response stays on standard output. Standard error receives one line per name that leads with whether
brute-force state was found, followed by the mapping status: a stored mapping to an account, `AMBIGUOUS` (all mapped
accounts were checked; verify the owner), no stored mapping (only the literal name was checked), or `UNDECIDED` (the
mapping could not be read). A stored mapping exists only for names that were used for a login and is not re-verified
against the backend; an alias that was never used, or a different spelling, is reported as unmapped. The client exits
with status 1 when a name stays undecided (an HTTP 500 body is still printed), when the server reports no resolution
for a requested name, when the server ignores the mode, or when an older server rejects it.

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

### Reputation

The `reputation` commands call the management operations of the bundled reputation plugin below
`/api/v1/custom/reputation/`. They require a bearer token or OIDC client credentials with `nauthilus:admin`; the client
refuses to send backchannel Basic credentials for them.

```bash
# Inspect one exact subject (kinds: ip, network, asn, dns_domain, account, service).
python3 contrib/client/nauthilus-admin.py reputation lookup ip 192.0.2.8
python3 contrib/client/nauthilus-admin.py reputation lookup account --subject-file /run/private/account.txt

# Set an audited operator override; --ttl-seconds 0 means no expiry.
python3 contrib/client/nauthilus-admin.py reputation override put ip 192.0.2.8 \
  --band blocked --ttl-seconds 3600 --reason incident --origin operator --audit-id ticket-123

# Remove it; --previous-audit must name the current override's audit ID.
python3 contrib/client/nauthilus-admin.py reputation override delete ip 192.0.2.8 \
  --previous-audit ticket-123 --reason resolved --origin operator --audit-id ticket-124

# Apply the overrides of a reputation-static-import.v1 artifact; add --continue-on-error to keep going after a failure.
python3 contrib/client/nauthilus-admin.py reputation override import /run/private/static-import.json

# Inspect or drain the allocation before a manifest-key rotation.
python3 contrib/client/nauthilus-admin.py reputation allocation status
python3 contrib/client/nauthilus-admin.py reputation allocation drain \
  --reason key_rotation --origin operator --audit-id rotation-123
```

`--band` accepts `blocked`, `trusted`, or `neutral`, and `--ttl-seconds` accepts `0` to `31536000`. `--subject-file`
keeps the subject out of process arguments and shell history; it must contain 1 to 512 UTF-8 bytes, and one trailing
newline is removed. Override commands address the active key generation by default; `--slot previous` addresses the
previous one. The client never retries a mutation: after a transport error or timeout it reports that the outcome may
be unknown, so inspect the state with `lookup` or `allocation status` before repeating the same change. See
[Reputation Operations](./reputation-operations.md) for the operational procedures.

### Support History

The `support` commands are read-only lookups in the recorded authentication and brute-force ban history of the
[Support Authentication History](./support-authentication-history.md) API. Each command sends one `POST` with a JSON
body below `/api/v1/support/`; logins, accounts, addresses, and filters never appear in the URL.

They need a bearer token or OIDC client credentials with `nauthilus:history_read`. `nauthilus:history_detail` widens
the projection, allows `attempts detail` without `--login` or `--account`, and allows `--login` or `--account` in
`bans search`. The server rejects backchannel Basic credentials and tokens that carry only `nauthilus:admin`; the
client refuses Basic-only credentials, and client credentials without `nauthilus:history_read` in the requested
scopes, before sending anything:

```dotenv
NAUTHILUS_SCOPES=nauthilus:authenticate nauthilus:history_read
```

```bash
# Attempts of one login during the last two hours.
python3 contrib/client/nauthilus-admin.py \
  support attempts search --login alice@example.test --since 2h

# One attempt; --around is any instant of it, for example started_at from the search.
python3 contrib/client/nauthilus-admin.py \
  support attempts detail --attempt-id fl1.0123456789abcdef0123456789abcdef \
  --around 2026-11-17T08:15:02Z --login alice@example.test

# Telephone support: why was the attempt rejected, and which recorded attempts fed the ban?
python3 contrib/client/nauthilus-admin.py \
  support attempts search --login kunde@example.test --since 30m \
  --client-ip 203.0.113.42 --include-ban-context --response-mode compact

# Bans of one client IP during the last week, all pages.
python3 contrib/client/nauthilus-admin.py \
  support bans search --ip 203.0.113.10 --since 7d --all

# Bans of one network in a fixed window, linked to a ticket in the server audit log.
python3 contrib/client/nauthilus-admin.py \
  support bans search --network 203.0.113.0/24 \
  --from 2026-11-01T00:00:00Z --until 2026-11-08T00:00:00Z --audit-reference INC-4711
```

| Option | Commands | Meaning |
| --- | --- | --- |
| `--login` or `--account` | all | Mutually exclusive subject; required for `attempts search`. |
| `--since DURATION` | `attempts search`, `bans search` | Window from now minus `30m`, `2h`, `7d`, … until now. |
| `--from`, `--until` | `attempts search`, `bans search` | RFC 3339 window instead of `--since`; `--from` must be earlier than `--until`. |
| `--client-ip`, `--protocol`, `--oidc-client-id`, `--saml-entity-id` | `attempts search` | Optional filters. |
| `--include-ban-context` | `attempts search` | Ask the server to link every brute-force rejected attempt to the ban that was recorded at that time (`ban_contexts`). |
| `--response-mode MODE` | `attempts search` | `detailed` asks the server for the full attempts; `compact` asks for `attempt_summaries` with an empty `attempts` list. |
| `--attempt-id`, `--around` | `attempts detail` | `fl1.<32 hex>` or `rq1.<request id>`, and any instant of the attempt. |
| `--ip` or `--network`, `--ban-ref` | `bans search` | Exactly one target; optional ban instance (32 hex characters). |
| `--limit` | `attempts search`, `bans search` | 1 to 50 attempts or 1 to 20 bans per page. |
| `--cursor` | `attempts search`, `bans search` | `next_cursor` of an earlier page of the same query. |
| `--all` | `attempts search`, `bans search` | Follow `next_cursor` for at most 20 pages and print one merged answer. |
| `--audit-reference` | all | Ticket reference matching `[A-Za-z0-9._:/-]{1,64}`. |
| `--summary` | `attempts search`, `attempts detail` | Local text rendering instead of JSON. It does not replace `--response-mode`. |

`--include-ban-context` and `--response-mode` are request fields that the server evaluates; they are sent in the body and
never change the token's rights. The server answers them as described in
[Ban context and compact answers](./support-authentication-history.md#ban-context-and-compact-answers).

The client checks the window locally: it must not exceed 31 days. `--all` deduplicates attempts by `attempt_id` and
bans by `ban_ref`, takes the other blocks from the last page, keeps `history` `partial` if any page was partial, and
adds `"pages": n`. With the two options above, `attempt_summaries` are deduplicated by `attempt_id` and `ban_contexts` by
`request_id`; a partial `ban_history` block prints a warning on standard error but does not change the exit code. When
20 pages are not enough, a warning on standard error names the cursor to continue with.

| Exit code | Meaning |
| --- | --- |
| `0` | Processed and `history.availability` is `available`. |
| `3` | Processed, but the history is `partial`; a warning on standard error lists `history.conditions`. |
| `4` | History unavailable or busy (HTTP 503 or 429). |
| `5` | Query too broad (HTTP 422); narrow the window or add filters. |
| `1` | Any other error: local validation, HTTP 400, 401, 403, or 500, or a transport error. |
| `2` | Command-line usage error. |

The JSON `error.code` decides the exit code when the server sends one; the message is only displayed. A login failure
recorded in the history is data, never a non-zero exit by itself. An empty search result, or a detail lookup without an
attempt, prints a note with `result_basis` and `history.conditions` on standard error: it does not prove that no login
or ban happened.

`--summary` renders the JSON answer as text locally; the `--response-mode` option, by contrast, changes what the server
returns. `--summary` prints a header line (`result_basis`, `availability`, `completion_since`), one line per attempt with
`outcome/outcome_basis`, `final`, `progress`, the four steps (`primary`, `second_factor`, `code_issuance`,
`code_redemption`), the OIDC `completion` state and `authentication`, finding codes, and known gaps, and for `detail`
one line per event with stage, code, the stored decision status (`answered`, `message`), and the committed `transport`
status. A field that the answer does not carry, for example from an older server, prints as `-`; it never defaults to
a success. `completion=tokens_issued` means Nauthilus redeemed the code and issued tokens; a webmail session is not
observed. `redemption_pending` and `code_expired_redemption_not_observed` mean that no redemption was observed, never
proof of an abort, and `not_recorded` means the flow predates completion recording. `answered=200 message="OK"` is
the stored host decision status, not the HTTP status the browser received (`transport`, for example `302`). A compact
answer prints one line per `attempt_summaries` entry, and every ban context prints a `ban-context` line followed by one
`ban` line with the network, rule, activation, planned end, end reason, relation, attribution code, other contributors,
subject and other-account counts, completeness, and limitations.

The JSON output always carries the complete answer. A `jq` view of the same fields that also copes with older answers:

```bash
python3 contrib/client/nauthilus-admin.py --output json \
  support attempts search --login alice@example.test --since 2h |
  jq -r '.attempts[] | [.attempt_id, .outcome, .outcome_basis, .progress,
         (.completion.state // "-"), (.completion.authentication // "-"),
         ((.recording.known_gaps // []) | join(",") | if . == "" then "-" else . end)] | @tsv'
```

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

## Installing a Standalone Copy

Operators who run the client outside a source checkout, for example as `/usr/local/sbin/nauthilus-admin`, can
replace that copy with `contrib/client/install-admin-client.sh`. The script replaces exactly one existing file;
wrappers, env files, and token caches are never touched. Every step is guarded by SHA-256 hashes:

```bash
# Verify and print the plan only.
contrib/client/install-admin-client.sh install \
  --source contrib/client/nauthilus-admin.py \
  --target /usr/local/sbin/nauthilus-admin \
  --expect-source "$NEW_SHA256" \
  --expect-current "$CURRENT_SHA256" \
  --dry-run

# Install; the output prints the matching rollback command.
contrib/client/install-admin-client.sh install \
  --source contrib/client/nauthilus-admin.py \
  --target /usr/local/sbin/nauthilus-admin \
  --expect-source "$NEW_SHA256" \
  --expect-current "$CURRENT_SHA256"

# Check the installed copy.
contrib/client/install-admin-client.sh check \
  --target /usr/local/sbin/nauthilus-admin \
  --expect-current "$NEW_SHA256"
```

`install` checks both hashes and that the new client parses and answers `--help` and `bruteforce list --help` without
network access. It keeps a copy of the current file as `<target>.previous-<UTC timestamp>`, replaces the target
atomically, and restores the backup automatically when the post-install check fails. `rollback --target PATH --backup
PATH --expect-backup SHA256 --expect-current SHA256` restores a saved copy. `--owner` (default `root:root`), `--mode`
(default `0755`), and `--python` (default `python3`) adjust the installed file and the interpreter used for the
checks. The script refuses symbolic-link targets and does not create a new installation.
