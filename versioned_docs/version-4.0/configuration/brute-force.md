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
- `auth.controls.brute_force.rwp_window`
- `auth.controls.brute_force.rwp_allowed_unique_hashes`
- `auth.controls.brute_force.adaptive_toleration`
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
      pw_history_for_known_accounts: true
```

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

- The pre-authentication check reads the RWP window, every candidate ban key, and the reputation counter in one
  pipeline. A normal check therefore needs this pipeline plus the bucket-counter evaluation, also when a cached L1 block
  decision is served.
- Password histories are loaded in one pipeline on the read handle.
- A counted failed login needs the RWP commit plus two round trips, independent of the number of matching rules: one
  reputation read and one pipeline that increments every selected bucket.
- On the blocked path, the affected account and the failed password hash are each written with one pipeline.

`bruteforce_redis_roundtrips_total` counts every pipeline with its `kind` label:

| `kind` label | Pipeline |
|---|---|
| `pipeline_pw_hist_load` | Password-history reads |
| `pipeline_preauth_check` | RWP check, candidate ban keys, and reputation before authentication |
| `pipeline_eval_bucket_counter` | Read-side evaluation of all matched buckets |
| `pipeline_eval_bucket_counter_save` | Counter increments of a counted failed login |
| `pipeline_affected_account` | Affected-account write on the blocked path |
| `pipeline_pw_hist_save` | Password-history writes into the account and IP sets |
| `pipeline_exists_ban_preresult` | Fallback ban-key read without a pre-authentication prefetch |
| `pipeline_exists_ban_policy_facts` | Fallback ban-key read of the Policy facts without a prefetch |
| `pipeline_exists_ban_is_blocked` | Ban-key read of the IP block check |
| `lua_increment_and_expire` | Burst gate of the blocked path (single script) |

On the regular authentication path the two fallback labels stay flat. `redis_write_total` counts every pipelined
script exactly once, and the `bf_update_loop_total` function-duration task observes the batched failed-login write once
per failed login. These pipelines do not depend on the optional client-side `storage.redis.batching` hook, which should
stay disabled; see [Redis Subsystems](server-configuration.md#redis-subsystems).

### Bucket Time Precision

Bucket periods are whole seconds, rounded to the nearest second with a minimum of one second. Bucket keys, window
weighting, and counter retention use this same effective period, and counters are retained for two effective windows,
including for sub-second configuration values.

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

- `auth.brute_force.toleration.active`
- `auth.brute_force.toleration.mode`
- `auth.brute_force.toleration.custom`
- `auth.brute_force.toleration.positive`
- `auth.brute_force.toleration.negative`
- `auth.brute_force.toleration.max_negative`
- `auth.brute_force.toleration.percent`
- `auth.brute_force.toleration.ttl_seconds`
- `auth.brute_force.toleration.suppressed_block`

Use these when a policy needs to distinguish "bucket pressure exists" from "the request was tolerated by reputation". For example, `suppressed_block` is true when toleration prevented a block that would otherwise have been applied.

Normalized bucket identifiers must be unique. If two bucket names normalize to the same policy segment, the policy snapshot fails validation. For the full attribute list and YAML examples, see [Auth Policy Reference](auth-policy.md) and [Auth Policy Configuration Guide](../guides/auth-policy-configuration.md).

## Policy-Owned Side Effects

`builtin.brute_force` emits read-only policy facts. Mutable side effects are owned by the selected policy decision.

The built-in `standard_auth` brute-force denial includes these obligations:

```yaml
then:
  decision: deny
  reason: brute_force_reject
  response_marker: auth.response.fail
  obligations:
    - id: auth.obligation.brute_force.update
    - id: auth.obligation.lua_action.dispatch
      args:
        action: brute_force
    - id: auth.obligation.lua_post_action.enqueue
      args:
        action: brute_force
```

If a custom policy replaces the built-in brute-force denial, add the same obligations when you want parity with the default behavior. Without them, the policy can still deny or tempfail, but it will not update brute-force state, dispatch the synchronous `brute_force` Lua action, or enqueue the matching POST-Action. In `mode: observe`, Nauthilus reports planned obligations but does not execute mutable side effects.

## Notes

- `ip_allowlist` is the current canonical name.
- `protocols` now belongs inside the brute-force block.
- learning names use the current control names, for example `rbl`, not `realtime_blackhole_lists`.
- old neural-network configuration is not part of the current public configuration model.
