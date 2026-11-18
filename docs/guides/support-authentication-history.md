---
title: Support Authentication History
description: Answer why a past login failed from recorded ClickHouse evidence with the read-only support history API
keywords: [Support, History, ClickHouse, Authentication attempts, Brute Force, Bans, OIDC, MFA, Audit]
sidebar_position: 31
---

# Support Authentication History

The support history is a read-only management API that answers support questions about **past** authentication
attempts from evidence that the [ClickHouse plugin](../developer/go-plugins/reference-plugins/clickhouse.md) recorded:

- Were the primary credentials rejected, or did the credential check never run?
- Did a second factor (TOTP, recovery code, WebAuthn) fail, and how often?
- Did a control such as a brute-force ban, an RBL, a relay-domain rule, or a TLS requirement reject the request before
  the credential check?
- Was there a technical error (backend, Policy, brute-force state) instead of a deliberate rejection?
- Did Nauthilus finish its part of an OIDC authorization-code login (code issued, code redeemed, tokens issued)?
- Which brute-force ban affected an IP address or network, which rule wrote it, which counted attempts fed it, and
  which later requests only hit the existing ban?

Every answer also states what **cannot** be said: which sources were readable, which part of the window is still
within retention, and which recording gaps always apply. An empty result never means "the user did not try to log in".

The history reads only ClickHouse. It never reads today's ban, GeoIP, reputation, Redis, or configuration state to
explain a past failure, and a query never authenticates, never evaluates Policy, never triggers post-actions, and
never writes anything.

## Prerequisites

| Requirement | Purpose |
| --- | --- |
| Native ClickHouse plugin writing `nauthilus.logins` with a `deployment` label | Authentication requests; the label is the data boundary of the history. |
| `events_insert_url` of the plugin (optional) | Second-factor verifications and OIDC code issuance/redemption in `nauthilus.auth_events`. |
| `bruteforce_lifecycle_insert_url` and `bruteforce_attempts_insert_url` (optional) | Ban activations, releases, counter resets, counted increments, and ban hits for the ban search. |
| Current ClickHouse schema | `schema.sql` for new installations, or the additive migrations for existing tables. |
| Dedicated read-only ClickHouse account | Bounded, provably read-only reader; see [Reader account](#reader-account). |
| `storage.history.clickhouse` | Enables the API on the Nauthilus instance. |
| OIDC bearer authentication for `/api/v1` and a client with history scopes | Callers; Basic credentials grant no history access. |

A login row exists only when the ClickHouse post-action runs for the request, either through a Policy rule obligation
or through `terminal_post_actions` of the authn target; see
[Realistic module and policy configuration](../developer/go-plugins/reference-plugins/clickhouse.md#realistic-module-and-policy-configuration).
Requests that select no analytics effect produce no row.

### Recorded sources and retention

| Source table | Content | Written by | Retention |
| --- | --- | --- | --- |
| `logins` | One row per answered authentication request with the sealed terminal outcome | `insert_url` | 7 days |
| `auth_events` | Second-factor verifications, OIDC code issuance and redemption | `events_insert_url` | 7 days |
| `bruteforce_lifecycle` | Ban activations, unconfirmed activations, releases, counter resets (no claimed names, no client address) | `bruteforce_lifecycle_insert_url` | 400 days |
| `bruteforce_attempts` | Counted increments, tolerated thresholds, ban hits (raw) | `bruteforce_attempts_insert_url` | 14 days |
| `bruteforce_attempt_summary` | Hourly aggregate of the attempts table (distinct-name counts as hash states) | materialized view | 400 days |

Rows written before the diagnostic data contract was deployed carry `contract_version = 0`. The history shows them as
legacy (`LEGACY_UNINTERPRETED`) and never derives a cause from them.

The columns of each table, the component that fills them, the reader's access model, and the schema migrations are
described in the [ClickHouse Data Model Reference](../developer/data-stores/clickhouse-data-model.md).

## Reader account

Provision a dedicated ClickHouse account with `contrib/clickhouse-kubernetes/history-reader.sql`. The script only
creates access control objects and changes no schema:

```sql
CREATE SETTINGS PROFILE IF NOT EXISTS nauthilus_history_profile SETTINGS
  readonly = 2 CONST,
  max_execution_time = 8 MAX 8,
  max_rows_to_read = 5000000 MAX 5000000,
  max_bytes_to_read = 2147483648 MAX 2147483648,
  read_overflow_mode = 'throw' CONST,
  result_overflow_mode = 'throw' CONST,
  timeout_overflow_mode = 'throw' CONST,
  cancel_http_readonly_queries_on_client_close = 1;

CREATE USER IF NOT EXISTS nauthilus_history IDENTIFIED WITH sha256_password BY 'CHANGE_ME_PASSWORD'
  SETTINGS PROFILE 'nauthilus_history_profile';

GRANT SELECT ON nauthilus.logins TO nauthilus_history;
GRANT SELECT ON nauthilus.auth_events TO nauthilus_history;
GRANT SELECT ON nauthilus.bruteforce_lifecycle TO nauthilus_history;
GRANT SELECT ON nauthilus.bruteforce_attempts TO nauthilus_history;
GRANT SELECT ON nauthilus.bruteforce_attempt_summary TO nauthilus_history;
```

- With the default `budget_mode: query_settings`, the profile uses `readonly = 2`, so the service can send its own
  budgets with every query but never raise them above the `MAX` constraints. The profile values must be at least the
  configured `storage.history.clickhouse` budgets.
- With `budget_mode: profile`, use `readonly = 1 CONST`. The service then sends no settings and verifies that the
  effective profile values are set and not larger than the configured budgets.
- Overflow modes must be `throw`: a budget hit must be an error, never silently truncated rows.
- Do not reuse a Grafana or other analytics account. The brute-force tables carry claimed login names and must stay
  limited to this reader and to operators.

Before reading, the service runs a self-check of the effective session settings and caches a positive result for five
minutes. It refuses a writable account (`readonly = 0`), any overflow mode other than `throw`, and, in `profile` mode,
a missing or larger budget. A refused reader answers `503 HISTORY_READER_UNSAFE`.

## Configuration

```yaml
storage:
  history:
    clickhouse:
      url: "https://clickhouse.example.internal:8443/"
      database: nauthilus
      username: nauthilus_history
      password: "${NAUTHILUS_HISTORY_CLICKHOUSE_PASSWORD}"
      deployment: production
      budget_mode: query_settings
      timeout: 15s
      max_execution_time: 8s
      max_rows_to_read: 5000000
      max_bytes_to_read: 2147483648
      max_response_bytes: 8388608
```

| Key | Default | Validation and meaning |
| --- | --- | --- |
| `url` | empty | ClickHouse HTTP interface. Empty disables the capability. Must be an absolute `http` or `https` URL without query parameters or embedded credentials. |
| `database` | `nauthilus` | Database of the diagnostic tables; a plain identifier (`[A-Za-z_][A-Za-z0-9_]{0,63}`). |
| `username` | empty | Reader account; required when `url` is set. Sent in `X-ClickHouse-User`. |
| `password` | empty | Reader password; redacted in configuration dumps. Sent in `X-ClickHouse-Key`. |
| `deployment` | empty | Required when `url` is set. Must equal the `deployment` label of the ClickHouse plugin; every query is bound to it. |
| `budget_mode` | `query_settings` | `query_settings` (reader profile `readonly = 2`) or `profile` (reader profile `readonly = 1`). |
| `timeout` | `15s` | Time budget of one history operation; greater than zero and at most `1m`. |
| `max_execution_time` | `8s` | Per-query ClickHouse execution limit; greater than zero, at most `1m`, and shorter than `timeout`. |
| `max_rows_to_read` | `5000000` | Per-query row read budget; greater than zero. |
| `max_bytes_to_read` | `2147483648` | Per-query byte read budget; greater than zero. |
| `max_response_bytes` | `8388608` | Client-side cap of one query response body; greater than zero and at most `67108864`. |

Use `https` or a comparably protected network: the reader credentials travel in request headers. Typed values such as
logins and addresses are sent as ClickHouse query parameters, never interpolated into SQL.

The service, the reader, and the candidate network prefixes taken from the configured brute-force rules are built at
startup. A change to `storage.history.clickhouse` or to the brute-force bucket prefixes needs a restart; prefixes
recorded in the evidence tables still cover rules that were removed later.

### Behaviour without history

The support routes are always registered. When `storage.history.clickhouse.url` is empty, a caller with a history scope
receives `503 HISTORY_NOT_CONFIGURED`, and a caller without one receives `403 FORBIDDEN`. When the reader cannot be
built at startup, for example because the URL carries a query string, Nauthilus logs `Support history reader disabled`
and answers the same way. Authentication and every other route are unaffected; there is no Redis or in-memory
fallback.

## Access

| Bearer scope | Projection | Grants |
| --- | --- | --- |
| `nauthilus:history_read` | `support` | Attempt search and detail of a **named** subject; ban search with counts and distinct-name counts. |
| `nauthilus:history_detail` | `detail` | Everything above, plus other people's claimed names, accounts, and client IPs behind shared addresses, operator IDs of ban releases, individual factor events of fail-latched flows, detail lookups without a subject, and a `subject` in the ban search. Implies `nauthilus:history_read`. |

`nauthilus:admin`, `nauthilus:security`, and backchannel Basic credentials grant **no** history access and receive
`403 FORBIDDEN`. Unlike other management routes, administrative Basic authentication is not a bypass here. The token
must still satisfy the backchannel rules: OIDC bearer acceptance enabled, audience `nauthilus:backchannel`, and the base
scope `nauthilus:authenticate` (see [OIDC Bearer Access](../rest-api.md#oidc-bearer-access-for-apiv1)).

Register the support console as a confidential client with the Client Credentials Grant and only the scopes it needs:

```yaml
auth:
  backchannel:
    oidc_bearer:
      enabled: true

identity:
  oidc:
    clients:
      - name: "Support history console"
        client_id: "support-history"
        client_secret: "${SUPPORT_HISTORY_CLIENT_SECRET}"
        grant_types: [client_credentials]
        token_endpoint_auth_method: "client_secret_basic"
        access_token_lifetime: 5m
        scopes:
          - nauthilus:authenticate
          - nauthilus:history_read
```

Add `nauthilus:history_detail` only for operators who may see other people's identities. Authorization is checked
before any data access, including the Redis account-mapping read and the reader self-check, and again for every page
and attempt ID.

## Operations

| Route | Purpose | Page size |
| --- | --- | --- |
| `POST /api/v1/support/authentication-attempts/search` | Attempts of one subject (`login` or `account`), optionally filtered by `client_ip`, `protocol`, `oidc_client_id`, or `saml_entity_id`; optional `response_mode` and `include_ban_context` (see [Ban context and compact answers](#ban-context-and-compact-answers)) | 1 to 50, default 20 |
| `POST /api/v1/support/authentication-attempts/detail` | All events of one `attempt_id`; `around` is any instant of the attempt, for example `started_at` from a search | at most 200 events per attempt |
| `POST /api/v1/support/bruteforce-bans/search` | Bans of one `ip` or `network`, optionally one `ban_ref` | 1 to 20, default 10 |

Request rules shared by all three operations:

- `Content-Type: application/json`, a body of at most 16 KiB, and `schema_version: "1"`;
- no query parameters, so logins and addresses never reach access logs;
- unknown fields, duplicate member names, and trailing data are rejected;
- times are RFC 3339; a window is `[from, until)` in event time and at most 31 days;
- optional `audit_reference` matching `[A-Za-z0-9._:/-]{1,64}` annotates the audit record with a ticket number; it is
  not verified;
- every response, including errors, carries `Cache-Control: no-store`.

The request and response schemas are in the API reference:
[Search attempts](../api-reference/management/search-authentication-attempts.api.mdx),
[Attempt detail](../api-reference/management/get-authentication-attempt.api.mdx), and
[Search brute-force bans](../api-reference/management/search-brute-force-bans.api.mdx).

### Attempt search

```json
{
  "schema_version": "1",
  "subject": {"login": "anna@example.org"},
  "filter": {
    "from": "2026-11-16T08:55:00Z",
    "until": "2026-11-16T09:05:00Z",
    "client_ip": "203.0.113.42",
    "protocol": "oidc"
  },
  "page": {"limit": 20},
  "audit_reference": "INC-4711"
}
```

An attempt is one IdP browser flow (`attempt_id` `fl1.<flow_ref>`, all rows and factor events sharing the
non-authorizing flow reference) or one authentication request without flow (`rq1.<request id>`). Correlation never
uses time proximity, accounts, or IP addresses; parallel browser tabs are separate flows. Attempt IDs grant nothing.

Each attempt carries:

| Field | Meaning |
| --- | --- |
| `outcome` | `succeeded`, `rejected`, `technical_error`, `not_observed`, or `unknown`. Never a cause by itself. |
| `outcome_basis` | Why the outcome is known, for example `request_terminal_answer`, `primary_failure_latched`, `oidc_tokens_issued`, `oidc_code_redemption_rejected`, `none`, or `legacy`. |
| `progress` | Furthest recorded step, from `none` and `pre_credential_rejected` up to `authorization_code_issued` and `tokens_issued`. |
| `steps` | `primary`, `second_factor`, `code_issuance`, and `code_redemption`, each `recorded`, `not_recorded`, or a step-specific value such as `session_reused`, `withheld`, or `not_applicable`. |
| `completion` | OIDC authorization-code flows only: `state` (`tokens_issued`, `redemption_rejected`, `redemption_failed`, `redemption_pending`, `code_expired_redemption_not_observed`, `code_issuance_not_observed`, `not_recorded`, `unknown`), `authentication` (`authenticated_in_flow` or `existing_session`), and the code timestamps. |
| `findings[]` | Every observed failure with a stable `code`, `category`, `certainty`, and `uncertainty[]`. There is no invented single main cause. |
| `recording` | `known_gaps[]` such as `PRIMARY_ROW_NOT_RECORDED`, `FLOW_COMPLETION_NOT_OBSERVED`, or `FLOW_COMPLETION_NEVER_RECORDED`, plus counters for merged replays, legacy rows, and truncated or withheld events. |

Typical finding codes are `CREDENTIALS_REJECTED` (unknown user and wrong password are not distinguished),
`REJECTED_BY_BRUTE_FORCE_PROTECTION`, `REJECTED_BY_RBL`, `REJECTED_BY_RELAY_DOMAIN_POLICY`, `REJECTED_TLS_REQUIRED`,
`TECHNICAL_ERROR_BACKEND`, `SECOND_FACTOR_REJECTED`, `SECOND_FACTOR_ATTEMPT_LIMIT`, `AUTHORIZATION_CODE_ISSUED`,
`TOKENS_ISSUED`, and `CODE_REDEMPTION_PKCE_FAILED`. Clients must switch on codes and show unknown codes verbatim:
additive codes and response fields can appear without a schema version change.

Attempts are ordered by their latest subject-matching activity, newest first. The window is scanned in slices of
24 hours that shrink to one hour before the request is rejected as too broad; `page.scanned_until` states the fully
covered part. A page can be short while `next_cursor` is set. There is no snapshot isolation: rows exported late can
repeat an attempt on a later page, so deduplicate by `attempt_id` and repeat a search whose window ends close to now.

Two optional request fields change what the search returns without changing who may see it: `response_mode` selects a
compact presentation, and `include_ban_context` links brute-force rejections to the recorded ban. Both are described in
[Ban context and compact answers](#ban-context-and-compact-answers). A request without them gets the answer described
above, unchanged.

### Attempt detail

```json
{
  "schema_version": "1",
  "attempt_id": "fl1.0123456789abcdef0123456789abcdef",
  "around": "2026-11-16T08:58:12Z",
  "subject": {"login": "anna@example.org"}
}
```

The support projection must name the subject; the detail projection may omit it. The attempt is returned only when
one of its rows belongs to the subject. A guessed or foreign attempt ID answers exactly like an unknown one
(`"attempt": null`).

Events carry the stage, result, stable code, the recorded identity (`supplied_login` as typed, `canonical_account` at
event time, `redacted`), context such as client IP, protocol, and the committed transport status, the recorded Policy
`decision` (`outcome_marker`, `response_marker`, `tempfail_reason`, `decision_sources`, `answered_status_code`,
`answered_status_message`), second-factor results, and structured reputation assessments. `answered_status_code` and
`answered_status_message` are the host status selected for the sealed decision, not the HTTP status the client
received: nginx-style answers commit HTTP 200 also for rejections, and an IdP login page answers with 200 or 302.
`reputation.state: none_recorded` is never a neutral rating.

### Brute-force ban search

```json
{
  "schema_version": "1",
  "target": {"ip": "203.0.113.10"},
  "filter": {"from": "2026-11-01T00:00:00Z", "until": "2026-11-08T00:00:00Z"},
  "page": {"limit": 10}
}
```

Send exactly one of `target.ip` or `target.network`. For an IP address, candidate networks come from the prefix
lengths of the configured brute-force rules and the prefixes recorded in the evidence tables, never from a scan. The
search also finds a ban that started before the window. Each ban instance (`ban_ref` is the activation event ID)
shows:

- the rule and limits **as recorded** at activation, never today's configuration;
- `activation.activating_request: NOT_A_CULPRIT`: behind NAT, the request that wrote the ban can come from an
  uninvolved user;
- the end: `released` is the only recorded end, `superseded_by_new_activation` bounds it, and
  `planned_end_passed_unconfirmed`, `planned_end_after_window`, or `unknown` are not recorded;
- `contributions`: the counted increments of the activating bucket between the counter resets before and after the
  activation, with a completeness `status` per window (`complete`, `loss_detected`, `aggregate_only`, `expired`,
  `not_applicable`) and a `crossing_candidate` that is a heuristic, never a cause. Beyond the 14-day raw retention the
  hourly summary decides the window status. A rule whose windows reach beyond it, for example a 28-day rule, still
  lists the increments that are retained; the caveat `RAW_CONTRIBUTIONS_PARTIALLY_RETAINED` marks that list as a
  subset, and such a ban is never `complete`. A missing or expired item never proves that a request did not
  contribute;
- `hits`: requests rejected by the existing ban inside the window;
- `orphan_hits`, `threshold_tolerated`, `releases`, `counter_resets`, and `unconfirmed_activations` as separate lists;
- `unknowns[]`, for example `ACTIVATION_CREATOR_UNKNOWN`, `END_NOT_RECORDED_EVICTION_OR_SCRIPT_POSSIBLE`, or
  `LIFECYCLE_ROWS_TRUNCATED`.

Orphan hits are rejections that no recorded ban explains, for example bans written by Lua scripts, evicted Redis keys,
or lost lifecycle events. The support projection sees counts and distinct-name counts only. Claimed names, accounts,
client IPs, and operator IDs need the detail projection, and a `subject` in the ban search is accepted only there, so
the search cannot be used to test whether a name was involved. Claimed names are claims, never persons.

### Ban context and compact answers

Telephone support asks one question: why was this attempt rejected, and whose recorded attempts fed the ban? An attempt
search answers it without internal IDs when the request sets `include_ban_context: true`. `response_mode` is a separate
field that only changes how much of the answer is returned. Neither field changes rights; the projection always follows
the token's scopes, and both are available over HTTP, the MCP tool, and the Admin Client. A request without them gets the
unchanged answer.

```json
{
  "schema_version": "1",
  "subject": {"login": "kunde@example.test"},
  "filter": {
    "from": "2026-11-18T08:10:00Z",
    "until": "2026-11-18T08:20:00Z",
    "client_ip": "203.0.113.42"
  },
  "page": {"limit": 5},
  "include_ban_context": true,
  "response_mode": "compact"
}
```

#### Response mode

| `response_mode` | Answer |
| --- | --- |
| `detailed` (default) | Full `attempts`. With ban context, every ban also carries its full explanation as `bans[].detail`. |
| `compact` | `attempts` is an empty list and `attempt_summaries[]` holds one summary per found attempt, in the same order. A summary has the `outcome`, the decisive `reason`, the finding codes, client addresses, protocols, request IDs, the recording gaps, and a `detail` object with the arguments of the attempt lookup. With ban context, `bans[].detail` is `null`. |

The answer states the mode it used in `response_mode`; the field is present only when the request named one. A compact
summary is built from the same projection as the detailed attempt, so it never shows more than the detailed answer
would. Use the `detail` arguments to open the full attempt with the attempt detail operation, and `bans[].ban_history`
to open the full ban explanation with the ban search.

#### Linking a rejection to its ban

For every visible subject login row of the page with the finding `REJECTED_BY_BRUTE_FORCE_PROTECTION`, `ban_contexts[]`
holds one entry with `attempt_id`, `request_id`, `at`, `client_ip`, `status`, `bans[]`, and `limitations[]`. The service
links the request on the server with one lifecycle read over the candidate networks of the rows' client addresses (the
same prefixes as the ban search, with lifecycle retention, so a ban that began before the search window is found) and
one read of the recorded `ban_hit` rows of the request IDs.

| `subject_relation` | Basis |
| --- | --- |
| `HIT_EXISTING_BAN`, `ACTIVATION_RACE` | A recorded hit of this request on the ban network inside the instance interval, with one second of grace. Hits are matched by network and time only, never by their rule or bucket. |
| `ACTIVATING_REQUEST` | The request wrote the activation. It is not a culprit. |
| `ACTIVATION_UNCONFIRMED` | The request recorded an unconfirmed activation because the key already existed. |
| `INTERVAL_OVERLAP` | No hit was recorded, or hits could not be read: only the interval of a ban of a candidate network contains the row. Instances without a recorded or planned end are bounded by their recorded ban time, otherwise never matched. |

| `status` | Meaning |
| --- | --- |
| `matched` | A recorded link. |
| `overlap_only` | Interval only, with `BAN_HIT_NOT_RECORDED` or `BAN_HITS_NOT_READ`. |
| `no_recorded_ban` | No ban explains the request. `BAN_LIFECYCLE_NOT_RECORDED` is added when a recorded hit has no instance: a script, an eviction, or a lost event. |
| `not_evaluated` | A bound, the time budget, or a read failure stopped the evaluation. The search itself never fails because of ban evidence. |

Several matching bans, for example a host ban and a network ban, or two instances of one network inside the one-second
grace of a supersession, are all listed with `MULTIPLE_BANS_MATCH`, newest activation first. None is picked. A row
without a recorded request ID (`REQUEST_ID_NOT_RECORDED`) is linked by interval only and never borrows the hits of other
requests. `ban_history` is omitted when no rejected request could be evaluated. `end` and `planned_end` describe the
instance as recorded up to `queried_at`, not today's Redis state.

#### Attribution

Every ban carries `attribution`, `evidence`, and `ban_history`, the arguments of the ban search for this instance.
Attribution classifies the listed contributions on unredacted rows, deduplicated by event ID:

| Class | Meaning |
| --- | --- |
| `subject_by_account` | The recorded account is the subject's: supplied, recorded at event time, or recorded on a counted row that claims a subject login, so aliases of the same account count as the same account. |
| `subject_by_login_claim` | Only the same login name was typed. That cannot tell the customer from anybody else. |
| `other_accounts` | Another recorded account. Counted only when the subject has a supplied or recorded account to compare against, otherwise the contribution is `unresolved` with `NO_RECORDED_SUBJECT_ACCOUNT_TO_COMPARE`. |
| `no_account` | A claim that resolved to no account at capture time, often a typo. Never "another account". |
| `unresolved` | No account was recorded. An alias of the subject can hide here. Today's mapping is never used to resolve a historical claim. |

| `attribution.code` | Meaning |
| --- | --- |
| `SUBJECT_ACCOUNT` | Contributions were recorded under the requested account (`subject_by_account` is above zero; the same login name alone never suffices). It is exclusive only with `other_contributors: none_observed`. |
| `MULTIPLE_ACCOUNTS` | Contributions under the requested account and at least one other recorded account. |
| `OTHER_ACCOUNTS_ONLY` | Only other accounts, with `completeness: complete` and no unresolved, account-less, or subject-name claim, no truncation, no partial retention, no reset clock skew, no counted-after-activation row, and no late-export window. |
| `NOT_SUFFICIENTLY_ATTRIBUTABLE` | Everything else, including bans without readable contributions. |

`other_contributors` is `observed`, `none_observed` (only on sufficient evidence), or `unknown`, and `person_attribution`
is always `NOT_ESTABLISHED`: the history never names a person. Contributions and uncertainty appear together, so a
`SUBJECT_ACCOUNT` ban can still carry `UNRESOLVED_CONTRIBUTOR_IDENTITIES` or a `CONTRIBUTIONS_*` limitation.
`evidence.completeness` is the contribution status (or `not_read`) and describes coverage only, never a responsible
person, NAT, or VPN; `limitations[]` adds the ban unknowns and caveats.

`subject_contributions[]` lists at most 50 of the subject's own increments with the request ID, the attempt ID when it
is on the page, the window counters, and `ban_active`. It is the subject's own data and visible to both projections.
`contributing_accounts`, the list of all recorded accounts, needs the detail projection: support receives `null` and
`identities_redacted: true`, so hidden identities never shrink to a misleading single account.

#### Bounds

One page evaluates at most 20 rejected requests, 8 client addresses, 32 candidate networks, and 10 explained bans.
Entries beyond a bound say `BAN_CONTEXT_LIMIT_REACHED`, and a low remaining time budget says
`BAN_CONTEXT_BUDGET_EXHAUSTED`. Linking needs one lifecycle read and one read of the recorded `ban_hit` rows per page;
explaining a ban adds the reads of the ban search. The feature changes no schema, retention, capture, or Redis state.

Abridged compact answer for the support projection (envelope, paging, and coverage are the same as in every search):

```json
{
  "response_mode": "compact",
  "attempts": [],
  "attempt_summaries": [
    {
      "attempt_id": "rq1.req-subject",
      "outcome": "rejected",
      "reason": "REJECTED_BY_BRUTE_FORCE_PROTECTION",
      "client_ips": ["203.0.113.42"],
      "request_ids": ["req-subject"],
      "detail": {"attempt_id": "rq1.req-subject", "around": "2026-11-18T08:15:00Z"}
    }
  ],
  "ban_contexts": [
    {
      "request_id": "req-subject",
      "at": "2026-11-18T08:15:00Z",
      "client_ip": "203.0.113.42",
      "reason": "REJECTED_BY_BRUTE_FORCE_PROTECTION",
      "status": "matched",
      "limitations": [],
      "bans": [
        {
          "ban_ref": "0123456789abcdef0123456789abcdef",
          "network": "203.0.113.42/32",
          "scope": "ip",
          "rule": "example_failed_logins",
          "activation_reason": "FAILURE_THRESHOLD_EXCEEDED",
          "activated_at": "2026-11-18T08:10:00Z",
          "planned_end": "2026-11-18T08:25:00Z",
          "end": {"reason": "planned_end_passed_unconfirmed", "at": "2026-11-18T08:25:00Z", "release_source": null},
          "subject_relation": "HIT_EXISTING_BAN",
          "attribution": {
            "code": "OTHER_ACCOUNTS_ONLY",
            "other_contributors": "observed",
            "person_attribution": "NOT_ESTABLISHED",
            "contributing_accounts": null,
            "identities_redacted": true,
            "counts": {
              "listed": 2, "subject_by_account": 0, "subject_by_login_claim": 0, "other_accounts": 2,
              "distinct_other_accounts": 1, "no_account": 0, "unresolved": 0, "counted_while_banned": 0
            },
            "subject_contributions": [],
            "subject_contributions_truncated": false
          },
          "evidence": {"completeness": "complete", "limitations": ["END_NOT_RECORDED_EVICTION_OR_SCRIPT_POSSIBLE"]},
          "ban_history": {
            "ban_ref": "0123456789abcdef0123456789abcdef",
            "network": "203.0.113.42/32",
            "from": "2026-11-18T08:10:00Z",
            "until": "2026-11-18T08:25:02Z"
          },
          "detail": null
        }
      ]
    }
  ]
}
```

Read it as: the attempt was rejected by brute-force protection because the address was already banned, the ban was fed
by two recorded attempts of one other account, and the customer's own account did not contribute. The answer still
claims nothing about a person, a shared network, or a VPN.

## Reading an answer

HTTP 200 means the query was processed. A failed login in the data is not an error. Always read `history` and
`result_basis` together with the results.

| `history` field | Meaning |
| --- | --- |
| `availability` | `available`, or `partial` when a source could not be read, is not installed, or holds no rows of the deployment. |
| `sources[]` | Per table: `state` (`read`, `read_failed`, `not_installed`, `no_rows_for_deployment`) and `window_coverage` (`within_retention`, `partially_expired`, `expired`). |
| `conditions[]` | Limiting conditions of this answer, for example `LEGACY_ROWS_PRESENT`, `NO_CONTRACT_ROWS_IN_WINDOW`, or `COMPLETION_CUTOVER_UNKNOWN`. |
| `known_limits[]` | Limits that always apply, for example `SUCCESS_DEDUPLICATION_MAY_HIDE_REPEATS`, `BOUNDED_BUFFERS_MAY_DROP_ROWS`, `NO_ROW_WITHOUT_ANALYTICS_EFFECT`, `BROWSER_ABORTS_NOT_RECORDED`, `LOGIN_CASE_VARIANTS_NOT_MATCHED`. |
| `contract_rows_since`, `oidc_completion_events_since` | First contract row and first OIDC completion event of the deployment; older data is legacy or predates completion recording. |
| `delivery_completeness`, `late_events_possible` | Always `not_guaranteed`; `late_events_possible` is true when the window ends within five minutes of the query. |

`result_basis` is `matches_found` whenever something matched. Otherwise it names the state of the primary source
(`logins` for attempts, `bruteforce_lifecycle` for bans) in this order: `source_not_installed`, `source_without_rows`,
`source_read_failed`, `window_expired`, `window_partially_expired`, `evidence_truncated`, `identity_unresolved`, and
only then `no_matches`. `no_rows_for_deployment` and `source_without_rows` cannot distinguish a disabled stream from a
quiet one. Suggested wording for an empty answer: "No recorded attempt matches in the readable part of the history".

## Errors

Error bodies are `{"schema_version":"1","error":{"code":"…","message":"…"}}`. The message is a fixed English text per
code; do not parse it or show it as the explanation of a login.

| Status | Code | Meaning and action |
| --- | --- | --- |
| 400 | `INVALID_REQUEST`, `WINDOW_TOO_LARGE`, `INVALID_CURSOR`, `INVALID_ATTEMPT_ID` | Fix the request. A cursor is bound to the same query and projection. |
| 401 | none | Missing or invalid backchannel token; the body is the middleware's `{"error": …}`. |
| 403 | `FORBIDDEN` | Missing history scope, Basic or admin-only credential, or a ban-search `subject` without the detail projection. |
| 422 | `QUERY_TOO_BROAD` | A read or response budget was exceeded even with the smallest scan slice. Narrow the window, add filters, or lower `page.limit`. |
| 429 | `HISTORY_BUSY` | The concurrency gate is full: four operations per process and two per caller. Retry later. |
| 503 | `HISTORY_NOT_CONFIGURED`, `HISTORY_SOURCE_UNAVAILABLE`, `HISTORY_READER_UNSAFE`, `HISTORY_TIMEOUT` | History unavailable. A failed or truncated `logins` read is always 503, never "no attempts". |
| 500 | `INTERNAL_ERROR` | Unexpected failure; the cause is logged on the server only. |

Requests rejected because of their transport shape (query parameters, wrong media type, oversized or non-strict JSON)
receive `400 INVALID_REQUEST` before they reach the service.

## Privacy and audit

- **Projection.** In the support projection, other identities in a flow are `redacted`. On fail-latched flows, where
  the primary step had already failed, every factor event is withheld and replaced by `SECOND_FACTOR_ON_LATCHED_FLOW`,
  because a correct second factor after a wrong password is operator-only information. Counts and `started_at` are then
  computed over the visible events.
- **Never returned.** Password hashes, OTPs, recovery codes, tokens, session or flow handles, WebAuthn payloads, client
  ports, and user agents are never read into an answer, also not in the detail projection.
- **Recorded free text.** Logins, accounts, client values, request IDs, instance names, Policy rule and tempfail texts,
  and answered status messages have control, format, and bidirectional characters replaced and are bounded to
  256 characters before they leave the host. Stored values and subject matching are unchanged.
- **Identity resolution.** `subject.login` is matched literally and in its lower-case form. Accounts come from the
  supplied `account`, today's stored login mapping in Redis (read only, never an authentication), and accounts
  recorded on rows of that login in the window. `subject_resolution` lists each with its provenance. Today's mapping
  cannot prove a historical alias, and an unresolved login is never shown as a verified account.
- **Audit.** Every operation that reaches the service, whether allowed, denied, or invalid, writes one structured
  `info` log record with `audit=support_history`: operation, caller identity and method, projection, `allowed`,
  `result_code`, result count, duration, `audit_reference`, and a domain-separated digest of the subject. The record
  carries no clear-text subject, no filter values, and no evidence. An attempt search with `include_ban_context` is
  audited as `attempt_search_ban_context`, so reads of brute-force evidence stay visible, and a compact answer counts
  its summaries as results.

## Clients

- The [Admin Client](./admin-client.md#support-history) provides `support attempts search`, `support attempts detail`,
  and `support bans search` with documented exit codes, page following, and a compact `--summary` view. Its
  `--include-ban-context` and `--response-mode compact` options send the two request fields described above.
- The Go management client in `server/openapi/client` offers `SearchAuthenticationAttempts`,
  `GetAuthenticationAttempt`, and `SearchBruteForceBans`.
- The same three operations are also available as the tools `authentication_attempts_search`,
  `authentication_attempt_detail`, and `bruteforce_history` of the optional, read-only MCP support endpoint; see
  [Read-only Support Access over MCP](./support-mcp-access.md). Both transports share one operation table, the same
  permission mapping, limits, concurrency gate, and response bytes.

`POST /api/v1/support/operations/diagnostics` (scope `nauthilus:operations_read`) is a separate operational
diagnostics operation over current runtime state and is not part of the history; see
[Diagnostics over the Management API](./support-mcp-access.md#diagnostics-over-the-management-api).

## Known limits

- Analytics is not a complete attempt history: success deduplication, bounded in-memory buffers, process loss, and
  the retention windows remove rows. A request whose rules select no ClickHouse post-action has no row.
- Second-factor events cover the IdP's TOTP, recovery-code, and WebAuthn verification. A recovery code typed into the
  TOTP form is reported as TOTP, recovery-code reuse is indistinguishable from an unknown code, and browser aborts or
  ceremonies that were never submitted are not recorded.
- OIDC completion is recorded for the authorization-code grant only. SAML assertion issuance, device-code and refresh
  grants, authorization errors, token requests that never resolve a code, and the relying-party session after the
  token response are not recorded.
- Self-service step-ups (`protocol: account`) have no flow reference and are not linked to the portal login flow.
- A new deployment answers `FLOW_COMPLETION_NEVER_RECORDED` until its first OIDC completion event is within retention;
  the completion probe is cached for five minutes, so the first event can appear with that delay.
- Login rows are exported with the plugin's `flush_interval` and events with `events_flush_interval`; a window that
  ends close to now can still receive rows.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `503 HISTORY_NOT_CONFIGURED` | `storage.history.clickhouse.url` is empty, or the reader was disabled at startup (`Support history reader disabled` in the log). |
| `503 HISTORY_READER_UNSAFE` | The reader account is writable, an overflow mode is not `throw`, in `profile` mode a profile budget is missing or larger than configured, or in `query_settings` mode a profile `MAX` constraint is below a configured budget. |
| `503 HISTORY_SOURCE_UNAVAILABLE` | ClickHouse is unreachable, a query failed, or the `logins` read was incomplete. |
| `403 FORBIDDEN` with a valid token | The token lacks `nauthilus:history_read`; the caller used Basic credentials or an admin-only token; a detail lookup or ban `subject` needs `nauthilus:history_detail`. |
| `403` with a plain `{"error": …}` body | The backchannel middleware rejected the token before the history service, usually because it lacks `nauthilus:authenticate`. |
| `result_basis: source_without_rows` | `deployment` differs from the plugin's `deployment` label, the plugin does not write the stream, or the table holds no rows in retention. |
| `second_factor: not_recorded` on every flow | `events_insert_url` is not configured, `auth_events` is missing, or it could not be read. |
| Only `LEGACY_UNINTERPRETED` results | The window holds only rows written before the diagnostic data contract was deployed. |
| New columns stay empty after an upgrade | The migrations were not applied; ClickHouse drops unknown JSONEachRow fields by default. Apply them and append `&input_format_skip_unknown_fields=0` to the insert URLs. |

For the plugin streams, schema migrations, and buffer metrics, see the
[ClickHouse plugin reference](../developer/go-plugins/reference-plugins/clickhouse.md).
