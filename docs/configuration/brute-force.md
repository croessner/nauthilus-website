---
title: Brute Force Protection
description: Configuration for auth.controls.brute_force
keywords: [Configuration, Brute Force, Protection]
sidebar_position: 8
---

# Brute Force Protection

Brute-force protection is configured under `auth.controls.brute_force` and activated by listing `brute_force` in `auth.controls.enabled`.

```yaml
auth:
  controls:
    enabled:
      - brute_force
```

## Main Paths

- `auth.controls.brute_force.protocols`
- `auth.controls.brute_force.ip_allowlist`
- `auth.controls.brute_force.buckets`
- `auth.controls.brute_force.learning`
- `auth.controls.brute_force.custom_tolerations`
- `auth.controls.brute_force.ip_scoping`
- `auth.controls.brute_force.tolerate_ttl`
- `auth.controls.brute_force.tolerate_percent`
- `auth.controls.brute_force.adaptive_toleration`
- `auth.controls.brute_force.min_tolerate_percent`
- `auth.controls.brute_force.max_tolerate_percent`
- `auth.controls.brute_force.scale_factor`
- `auth.controls.brute_force.rwp_window`
- `auth.controls.brute_force.rwp_allowed_unique_hashes`
- `auth.controls.brute_force.affected_accounts.retention`
- `auth.controls.brute_force.affected_accounts.cleanup_enabled`
- `auth.controls.brute_force.pw_history_for_known_accounts`

## Example

```yaml
auth:
  controls:
    enabled:
      - brute_force
    brute_force:
      protocols:
        - imap
        - smtp
        - submission
      ip_allowlist:
        - 127.0.0.0/8
        - ::1
      buckets:
        - name: "login_rule"
          period: 10m
          ban_time: 4h
          cidr: 24
          ipv4: true
          ipv6: false
          failed_requests: 5
      learning:
        - rbl
        - relay_domains
        - brute_force
        - lua
      tolerate_percent: 20
      tolerate_ttl: 48h
      custom_tolerations:
        - ip_address: "192.168.1.0/24"
          tolerate_percent: 30
          tolerate_ttl: 72h
      ip_scoping:
        rwp_ipv6_cidr: 64
        tolerations_ipv6_cidr: 64
      adaptive_toleration: true
      affected_accounts:
        retention: 24h
        cleanup_enabled: true
      pw_history_for_known_accounts: true
```

## Toleration

Toleration keeps a shared address, for example a corporate proxy or a NAT gateway, from being banned because a few of
the users behind it mistype their passwords. Nauthilus counts two values per client address (IPv6 grouped by
`ip_scoping.tolerations_ipv6_cidr`) within `tolerate_ttl`:

- **positive** is the number of *distinct accounts* that authenticated successfully from the address. Repeated logins
  of one account count once, and login names that resolve to the same account count once, so a valid account cannot
  buy failed attempts by logging in repeatedly.
- **negative** is the number of *failed login attempts* from the address, whichever account they target. Ten failures
  against one account count ten times.

An address is tolerated while `positive > 0` and `negative <= floor(percent * positive / 100)`. A tolerated address is
not banned when a bucket exceeds its limit, and `auth.brute_force.toleration.suppressed_block` reports the suppressed
ban. As soon as the failures exceed the allowance, toleration ends and the regular bucket limits apply again, so an
attack from a shared address is stopped once it outgrows the share of failures that the legitimate accounts behind it
justify.

Only `authenticate` requests with a host-verified credential outcome are counted: a request answered with success after
the backend verified the password is a positive, and a request answered as a failed login after the backend rejected
the password is a negative. A [repeating wrong password](#repeating-wrong-passwords) is not counted, exactly like in
the buckets. Temporary failures, pre-authentication rejections such as an existing ban, identity lookups, and no-auth
requests are not counted either.

Both values are counted on read over exactly the window, so every instance sees the same values and successes age out
even while an address stays quiet. At most 10,000 failures are retained per address, and a saturated count is never
tolerated. When the counters cannot be read, the address is not tolerated for that request and the regular bucket
limits apply.

| Key | Default | Meaning |
|---|---|---|
| `tolerate_ttl` | unset | Counting window, at most `8760h`. Without a window from this key or a matching `custom_tolerations` entry, tolerations are disabled for the address. |
| `tolerate_percent` | `0` | Static share of tolerated failures relative to `positive`. |
| `adaptive_toleration` | `false` | Derive the share from `positive` instead of `tolerate_percent`. |
| `min_tolerate_percent` | `10` | Lower bound of the adaptive share. |
| `max_tolerate_percent` | `50` | Upper bound of the adaptive share. |
| `scale_factor` | `1.0` | Growth of the adaptive share, `0.1` to `10`. |
| `ip_scoping.tolerations_ipv6_cidr` | `128` | IPv6 prefix length that groups addresses for toleration counting. |

With `adaptive_toleration` the share is calculated from the distinct successful accounts:

```text
factor  = min(1, ln(positive + 1) / ln(100) * scale_factor)
percent = floor(min_tolerate_percent + (max_tolerate_percent - min_tolerate_percent) * factor)
```

With the default bounds, one account allows no failure (16 %), 5 accounts allow 1 failure (25 %), 10 accounts allow 3
(30 %), 50 accounts allow 22 (44 %), and 100 or more accounts reach the 50 % cap. An attacker who controls ten valid
accounts and attacks an eleventh from the same address therefore gets three failed attempts within the window; the
fourth ends the toleration, logging in again with the same ten accounts does not raise the allowance, and the
successes age out after `tolerate_ttl` even while the attack continues.

A `custom_tolerations` entry overrides these settings for a matching `ip_address` (address or CIDR). `ip_address`,
`tolerate_ttl`, and `tolerate_percent` are required. `min_tolerate_percent`, `max_tolerate_percent`, and
`scale_factor` of the entry apply when the entry sets `adaptive_toleration: true`.

The same windowed `positive` count also raises the bucket limits of an address with recent successful logins by the
toleration share; the global `tolerate_percent` or adaptive settings determine that share. The bucket fact
`effective_limit` reports the applied limit.

:::warning Behavior change in 4.1.0

Toleration works again. Since the Policy cutover before v4.0.0 no request recorded toleration observations, so
`tolerate_percent`, `custom_tolerations`, `adaptive_toleration`, and the reputation-scaled bucket limits had no effect
on v4.0.x. In addition, negatives now count every failed attempt instead of distinct failing accounts: before, valid
logins of a few accounts kept an address tolerated while a single other account was attacked without limit. Review
`tolerate_ttl`, `tolerate_percent`, `min_tolerate_percent`, `max_tolerate_percent`, `adaptive_toleration`, and
`custom_tolerations` before the upgrade. Networks with recent successful logins get higher effective limits again,
while shared addresses with many failures reach the end of their toleration sooner.

The counters now live only in the sorted sets `bf:tr:{<scoped ip>}:P` and `bf:tr:{<scoped ip>}:N` below
`storage.redis.prefix`. Counter hashes `bf:tr:{<scoped ip>}` from earlier versions are no longer read and expire on
their own. The brute-force and user flush endpoints now remove these sets; earlier releases targeted keys that were
never written, so a flush did not reset the toleration counters.

:::

## Repeating Wrong Passwords

Repeating-wrong-password (RWP) handling keeps a user who retries the same wrong password, for example a mail client
with a stale stored password, from filling the buckets. It works per account and scoped client IP:

- Only a failed password hash that is already recorded for this account and scoped IP counts as a repeat. A repeat
  refreshes its timestamp but does not increment the buckets.
- Every newly encountered wrong password increments the matching buckets from its first occurrence, including the
  first failure for a known account. Distinct wrong passwords are never free guesses.
- The classification and the recording of a failed hash are one atomic Redis operation, so concurrent requests cannot
  exempt a distinct failure.

| Key | Default | Meaning |
|---|---|---|
| `rwp_window` | `15m` | How long a recorded failed hash is recognized as a repeat. Retention is rounded up to whole seconds. |
| `rwp_allowed_unique_hashes` | `3` | Maximum number of failed hashes remembered per account and scoped IP. It bounds the retained history; it is not a number of tolerated distinct passwords. |

`ip_scoping.rwp_ipv6_cidr` controls how IPv6 addresses are grouped for RWP. IPv4-mapped IPv6 addresses are normalized
to IPv4 first.

:::note Behavior change from earlier v4 prereleases

Earlier releases tolerated up to `rwp_allowed_unique_hashes` distinct wrong passwords within `rwp_window` before any
bucket was incremented, and then raised the buckets to a catch-up floor. Now every distinct wrong password counts
immediately, and the catch-up floor is gone. Buckets therefore reach their limits after the configured number of
distinct failures. Review bucket limits that were tuned around the old grace period.

:::

### Unavailable Brute-Force State

When Redis cannot answer during the pre-authentication brute-force check, the request fails with a temporary
authentication failure and the policy fact `auth.brute_force.error` is set. An unavailable repeat check never grants an allowance.

When the RWP commit after a failed password cannot reach Redis, the verdict is undecided. Nauthilus then does not
increment any bucket and answers the request with a temporary failure (`auth.backend.tempfail` is true for the policy),
so a degraded store neither bans legitimate clients nor reports a wrong password. Brute-force accounting is blind while
the store is unavailable; watch `bruteforce_rwp_decisions_total{verdict="undecided"}` and
`bruteforce_rwp_window_duration_seconds` (see [Metrics](metrics.md#brute-force-metrics)).

### Password Hashes in Redis

Redis password state uses only the full 64-hex password hash, which includes `storage.redis.password_nonce`. Password
history sets (`pw_hist`, `pw_hist_ips`), the RWP allowance sets, and the positive password cache ignore the eight-hex
short hashes that earlier v4 prereleases wrote. No cleanup is required: stray short members expire with their TTL, and
until then a short member only misses a one-time known-password hint and a short positive-cache value is a cache miss.

### Redis Round Trips

Brute-force protection runs on the hot authentication path, so data-independent Redis commands share explicit
pipelines instead of sequential round trips:

- The pre-authentication check reads the RWP window, every candidate ban key, and the windowed reputation count in one
  pipeline. The count is skipped when tolerations are disabled for the address. A normal check therefore needs this
  pipeline plus the bucket-counter evaluation, also when a cached L1 block decision is served.
- Password histories are loaded in one pipeline on the read handle.
- A counted failed login needs the RWP commit plus two round trips, independent of the number of matching rules: one
  reputation read and one pipeline that increments every selected bucket.
- The affected account is written with one pipeline, and on the blocked path the failed password hash with another.
- The management listing reads the password-history IPs of the listed accounts in bounded pipelines of at most 256
  accounts per round trip.

`bruteforce_redis_roundtrips_total` counts every pipeline with its `kind` label:

| `kind` label | Pipeline |
|---|---|
| `pipeline_pw_hist_load` | Password-history reads |
| `pipeline_preauth_check` | RWP check, candidate ban keys, and reputation before authentication |
| `pipeline_eval_bucket_counter` | Read-side evaluation of all matched buckets |
| `pipeline_eval_bucket_counter_save` | Counter increments of a counted failed login |
| `pipeline_affected_account` | Affected-account write with its retention deadline, on a counted failed login or a blocked request |
| `pipeline_affected_account_history` | Management listing: password-history IPs of one batch of at most 256 accounts; Redis Cluster fans it out to one round trip per owning node |
| `pipeline_pw_hist_save` | Password-history writes into the account and IP sets |
| `pipeline_exists_ban_preresult` | Fallback ban-key read without a pre-authentication prefetch |
| `pipeline_exists_ban_policy_facts` | Fallback ban-key read of the Policy facts without a prefetch |
| `pipeline_exists_ban_is_blocked` | Ban-key read of the IP block check |
| `lua_increment_and_expire` | Burst gate of the blocked path (single script) |

On the regular authentication path the two fallback labels stay flat. `redis_write_total` counts every pipelined
script exactly once, and the `bf_update_loop_total` function-duration task observes the batched failed-login write once
per failed login. Since 4.1.0 `redis_write_total` counts each of the three commands of the affected-account write and of
the affected-account flush instead of one per pipeline, so dashboards show a step at the upgrade. These pipelines do
not depend on the optional client-side `storage.redis.batching` hook, which should stay disabled; see
[Redis Subsystems](server-configuration.md#redis-subsystems).

### Bucket Time Precision

Bucket periods are whole seconds, rounded to the nearest second with a minimum of one second. Bucket keys, window
weighting, and counter retention use this same effective period, and counters are retained for two effective windows,
including for sub-second configuration values.

## Affected Accounts

The management listing (`/api/v1/bruteforce/list`) reports affected accounts: accounts with a counted failed login or
a blocked request, together with the client IPs of their password history. A failure that only repeats a recorded
wrong password does not mark an account as affected. No authentication, ban, counter, repeat, or toleration decision
reads this list, so its lifecycle does not change the protection.

Since 4.1.0 affected accounts age out per account. Earlier releases kept every entry until an explicit flush, so the
list grew without bound. An account now stays listed while it had counted activity within the retention R, and as long
as it still has a password-history IP list:

| Key | Default | Meaning |
|---|---|---|
| `affected_accounts.retention` | `24h` | Minimum visibility after the last counted failed or blocked request, at most `8760h`. |
| `affected_accounts.cleanup_enabled` | `true` | Runs the background maintenance that removes due accounts. |

R is the largest of `affected_accounts.retention`, `storage.redis.negative_cache_ttl`, `rwp_window`, `tolerate_ttl`
including every custom toleration, and the longest bucket `ban_time` plus twice the longest bucket `period`. Bans,
counters, and tolerations are kept per network, not per account, and the maintenance never touches them.

- Every counted failed login and every blocked request moves the account's deadline forward, also while the cleanup is
  disabled, so enabling it later starts from current deadlines.
- The maintenance runs once per minute outside the authentication path. A short Redis lease lets one instance work per
  tick, every step handles at most 256 accounts, and all reads go to the primary. An account whose password-history IP
  list still exists gets its deadline moved to the end of that history instead of being removed.
- Accounts written by an earlier release have no deadline. After the upgrade they stay listed for at least R. The same
  re-arm runs whenever the maintenance has not run for more than ten minutes, for example after a rollback or while
  `cleanup_enabled` was `false`.
- `cleanup_enabled: false` stops removals. The flush endpoints still remove an account immediately.
- The lifecycle needs Redis 6.2 or newer. Its keys share the hash slot of the affected-account set and start with
  `storage.redis.prefix`, so prefix-scoped ACLs keep working. When the prefix contains braces that prevent a same-slot
  key, the maintenance removes nothing, logs a warning, and counts the step `refused`.

The maintenance reports `bruteforce_affected_accounts_maintenance_total{action}`,
`bruteforce_affected_accounts_maintenance_errors_total{step}`, and `bruteforce_affected_accounts_members{key}`; see
[Metrics](metrics.md#brute-force-metrics). During a rolling upgrade, keep old and new instances side by side for less
than R.

## Listing and Flushing by Login Name

Brute-force state is attributed to the account that authentication resolved for a login name. When a backend finds a
user, also on a wrong password, Nauthilus stores a mapping from the login name, per protocol and OIDC client, to that
account. An alias address therefore maps to the account of its mailbox.

`POST /api/v1/bruteforce/list` checks the names in `accounts` literally by default (`account_resolution` omitted or
`none`). Since 4.1.0 the request can also check the accounts stored for each name:

```json
{
  "accounts": ["alias@example.test"],
  "account_resolution": "account_mapping"
}
```

- `account_mapping` requires 1 to 100 distinct `accounts`. Fewer or more names, a request without `accounts`, and an
  unknown mode are answered with HTTP `400`.
- Every name is checked literally and together with its mapped accounts. The account section of the response echoes
  `account_resolution` and adds `resolutions`, one entry per requested name and independent of paging, with `input`,
  `status`, `source`, `accounts`, `checked`, `matched`, `literal_match`, and `error`.
- `status` is `mapped` (one stored account), `unmapped` (none; only the literal name was checked), `ambiguous`
  (several; all were checked), or `error` (the mappings could not be read). An `error` leaves the result undecided: the
  listing sets `error` and is answered with HTTP `500`.
- `accounts` keeps its meaning, and paging applies to the matched accounts. IP filters keep working on the separate IP
  section; the listing links no IP address to an account.
- The listing only reads. It does not call the Lua cache-flush callback and flushes, counts, or writes nothing.

A mapping exists only for login names that were used for a login, for example not for an alias known only to LDAP. It
is a cache that is not re-verified against the backend and can be stale after renames or removals. Names are compared
byte-exact without case folding. The resolution scans the user-hash shard on the Redis primary that owns it, also when
reads are otherwise routed to replicas, and one Redis read deadline bounds it. The admin client exposes the mode as
`bruteforce list --via-mapping`; see the [admin client guide](../guides/admin-client.md).

The user cache flush (`/api/v1/cache/flush`) uses the same mappings when no Lua cache-flush callback returns an
account. Since 4.1.0 a failed mapping read stops the flush before any account or brute-force state is removed and is
answered with HTTP `503` `Account mapping lookup failed`; the asynchronous variant marks its job failed. Earlier
releases silently flushed only the literal name in that case. A retry is safe. The flush also no longer removes the
mapping fields and accounts of other users whose login names start with the flushed name followed by `|`.

## Policy Attributes

When a checkpoint schedules `authn/builtin/brute_force`, Nauthilus exports both global brute-force facts and generated per-bucket facts. Bucket names become policy-safe identifier segments:

| Bucket name | Policy segment | Example attribute |
|---|---|---|
| `login_rule` | `login_rule` | `auth.brute_force.bucket.login_rule.ratio` |
| `IMAP Short` | `imap_short` | `auth.brute_force.bucket.imap_short.over_limit` |
| `24h` | `b_24h` | `auth.brute_force.bucket.b_24h.repeating` |

The generated bucket attributes include:

- `matched`
- `count`
- `limit`
- `effective_limit`
- `remaining`
- `ratio`
- `over_limit`
- `already_banned`
- `repeating`

Global brute-force policy attributes also include toleration facts:

| Attribute | Meaning |
|---|---|
| `auth.brute_force.toleration.active` | The address is tolerated. |
| `auth.brute_force.toleration.mode` | `disabled` (no `tolerate_ttl` for the address), `static`, or `adaptive`. A failed counter read reports `static` and is not tolerated. |
| `auth.brute_force.toleration.custom` | A `custom_tolerations` entry matched the address. |
| `auth.brute_force.toleration.positive` | Distinct accounts with a successful login within the window. |
| `auth.brute_force.toleration.negative` | Failed login attempts within the window. |
| `auth.brute_force.toleration.max_negative` | Tolerated failures, `floor(percent * positive / 100)`. |
| `auth.brute_force.toleration.percent` | Applied toleration share. |
| `auth.brute_force.toleration.ttl_seconds` | Applied window. |
| `auth.brute_force.toleration.suppressed_block` | Toleration prevented a ban that would otherwise have been applied. |

Use these when a policy needs to distinguish "bucket pressure exists" from "the request was tolerated by reputation".
See [Toleration](#toleration) for the counting rules.

Normalized bucket identifiers must be unique. If two bucket names normalize to the same policy segment, the policy snapshot fails validation. For the full attribute list and YAML examples, see [Auth Policy Reference](auth-policy.md) and [Auth Policy Configuration Guide](../guides/auth-policy-configuration.md).

## Policy-Owned Side Effects

`authn/builtin/brute_force` emits read-only policy facts. Mutable side effects are owned by the selected policy
decision.

The built-in `authn/standard_auth` brute-force reject selects the effect `authn/brute_force_update`, which updates the
brute-force state without dispatching Lua actions. A custom rule that replaces the built-in reject selects the same
effect for parity:

```yaml
then:
  decision: deny
  obligations:
    - id: authn/brute_force_update
```

Without it, the policy can still deny or tempfail, but it does not update brute-force state. Lua actions such as a
`brute_force` action type run only when a rule selects their `authn/lua_action_<name>` effect. In `mode: observe`,
Nauthilus reports planned obligations but does not execute mutable side effects.

A request answered by a built-in rule carries only the built-in effects. A post-action listed on a configured rule,
for example a login log, therefore never runs for a brute-force reject after a ban hit closed the remaining pre-auth
providers. Declare such post-actions as [terminal post-actions](auth-policy.md#terminal-post-actions) of the target;
they run once for every answered request, whichever rule answered it.

## Notes

- `ip_allowlist` is the current canonical name.
- `protocols` now belongs inside the brute-force block.
- learning names use the current control names, for example `rbl`, not `realtime_blackhole_lists`.
- old neural-network configuration is not part of the current public configuration model.
- The Redis keys of brute-force protection, their types, and their lifetimes are listed under
  [Brute-Force Protection](../developer/data-stores/redis-keyspace.md#31-brute-force-protection) in the Redis Keyspace
  Reference. The evidence that the ClickHouse plugin records for bans, counted increments, and ban hits is described in
  the [ClickHouse Data Model Reference](../developer/data-stores/clickhouse-data-model.md#43-nauthilusbruteforce_lifecycle).
