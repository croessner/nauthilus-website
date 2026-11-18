---
title: Metrics
description: Prometheus support in Nauthilus
keywords: [Metrics, Prometheus]
sidebar_position: 3
---
# Prometheus support

There is some limited support for Prometheus and Grafana. For an example have a look at the contrib folder included with
the source code.

## Endpoint Authentication

Nauthilus exposes Prometheus metrics on the HTTP listener at `/metrics`.
The endpoint is open unless dedicated metrics authentication is enabled.

Use `observability.metrics.endpoint_auth.basic` to protect `/metrics` with HTTP Basic authentication:

```yaml
observability:
  metrics:
    endpoint_auth:
      basic:
        enabled: true
        username: prometheus
        password: "replace-with-a-long-random-secret"
```

This authentication block is specific to the metrics endpoint.
It does not reuse `auth.backchannel.basic_auth`, and `/metrics` does not accept Bearer or OIDC authentication.

When `observability.metrics.endpoint_auth.basic.enabled=true`, both `username` and `password` are required during configuration validation.
Requests without valid credentials return HTTP `401` with a Basic authentication challenge.

If the block is disabled or omitted, `/metrics` remains accessible without authentication.

## Prometheus Configuration

Configure Prometheus with matching credentials:

```yaml
scrape_configs:
  - job_name: nauthilus
    metrics_path: /metrics
    scheme: https
    static_configs:
      - targets:
          - nauthilus.example.test:9443
    basic_auth:
      username: prometheus
      password: "replace-with-a-long-random-secret"
```

For scrapes that cross a trust boundary, use HTTPS or a private scrape network in addition to Basic authentication.

## Authentication Latency

`authentication_response_time_seconds{transport,outcome,protocol}` is a histogram of authentication requests measured at
the transport response boundary. It is recorded only while `observability.metrics.prometheus_timer.enabled` is `true`.
All labels are bounded:

| Label | Values |
|---|---|
| `transport` | `http`, `grpc`, or `other` |
| `outcome` | `ok`, `fail`, `tempfail`, or `error` (no valid terminal decision) |
| `protocol` | `smtp`, `smtps`, `submission`, `imap`, `imaps`, `pop3`, `pop3s`, `lmtp`, `lmtps`, `sieve`, `managesieve`, `jmap`, `http`, `https`, `oidc`, `saml`, `idp`, `account-provider`, `default`; any other value is `other`, an empty value is `unknown` |

The protocol value is compared case-insensitively after trimming. The implicit-TLS and submission variants and `jmap`
have their own label values, so a deployment that distinguishes them in its backends sees them apart in the metric too.
Dashboards that summed these protocols under `other` must select the new values.

## Brute-Force Metrics

In addition to `bruteforce_hits_total{bucket}` and `bruteforce_rejected_total{bucket}`, Nauthilus reports the
repeating-wrong-password (RWP) and toleration decisions, and the affected-account maintenance:

| Metric | Type | Labels | Meaning |
|---|---|---|---|
| `bruteforce_rwp_decisions_total` | counter | `verdict` | RWP verdicts after a failed password: `repeated` (a recorded hash, no bucket increment), `counted` (a new failure, buckets incremented), or `undecided` (Redis could not answer; nothing counted, request answered with a temporary failure). |
| `bruteforce_rwp_window_duration_seconds` | histogram | none | Duration of one RWP sliding-window round-trip to Redis, observed on success and failure. |
| `bruteforce_toleration_decisions_total` | counter | `mode` | Toleration lookups by resulting mode: `disabled`, `static`, or `adaptive`. |
| `bruteforce_toleration_percent` | histogram | none | Tolerated percentage actually applied. Lookups in `disabled` mode are not observed. |
| `bruteforce_affected_accounts_maintenance_total` | counter | `action` | Affected-account lifecycle changes of the background maintenance: `armed`, `rearmed`, `adopted`, `backfilled`, `extended`, `removed`, `index_restored`, `index_orphan_removed`. |
| `bruteforce_affected_accounts_maintenance_errors_total` | counter | `step` | Failed or refused maintenance steps: `lease`, `state`, `rearm`, `remove`, `adopt`, `index`, `gauges`, and `refused` (the Redis prefix prevents a same-slot key; nothing is removed). |
| `bruteforce_affected_accounts_members` | gauge | `key` | Members of the affected-account `set`, its `retention` deadlines, and its `index`; every instance refreshes it once per minute while brute-force protection is enabled. |

A rising `undecided` rate or a growing RWP round-trip duration means brute-force accounting is degraded; see
[Unavailable Brute-Force State](brute-force.md#unavailable-brute-force-state). The existing `tolerate.is_tolerated` trace
span also carries the attributes `toleration.mode`, `toleration.active`, `toleration.custom`, `toleration.percent`,
`toleration.positive`, and `toleration.negative`.

Since 4.1.0 `redis_write_total` counts each command of the affected-account write and of the affected-account flush
(three each) instead of one per pipeline, and `bruteforce_redis_roundtrips_total` has the additional kind
`pipeline_affected_account_history` for the management listing. See
[Affected Accounts](brute-force.md#affected-accounts).

## Backchannel Caller Metrics

`backchannel_caller_auth_total{transport,outcome}` counts caller authentication on the backchannel: the HTTP API under
`/api/v1/*` (`transport="http"`) and the gRPC authority listener (`transport="grpc"`). `outcome` is `accepted`,
`rejected`, or `unavailable`. `unavailable` means the token state or signing keys could not be read, or the caller's
request had already ended; such requests are answered with HTTP `503`, gRPC `UNAVAILABLE`, or, for an ended gRPC
request, `CANCELED`/`DEADLINE_EXCEEDED`, never as a rejection.
Rejected Basic credentials on `/ping`, `/livez`, `/healthz`, and `/metrics` are not counted. Policy API callers are reported by the
Policy observer instead.

Alert on sustained `backchannel_caller_auth_total{outcome=~"rejected|unavailable"}`. See
[REST API](../rest-api.md#backchannel-caller-rejections) for the caller rejection behavior. With the HTTP rate middleware
enabled, also watch `429` answers on `/api/v1`: an address that exhausts its failure budget is refused until it refills
(see [Failure Budget per Client IP](../rest-api.md#failure-budget-per-client-ip)).

## Post-Action Supervisor Metrics

Every Policy generation owns one post-action supervisor with a fixed worker set and a bounded queue, sized by
`policy.runtime.post_actions.workers` (default `8`, `1` to `1024`, not above `queue_capacity`) and
`policy.runtime.post_actions.queue_capacity` (default `256`, `1` to `65536`). A post-action is accepted synchronously
before the response is finalized. When the queue is full, acceptance fails and the authentication request ends as a
temporary failure.

| Metric | Labels | Meaning |
|---|---|---|
| `post_action_effect_states_total` | `state`, `phase`, `boundary` | Every supervisor transition. |
| `post_action_acceptance_failures_total` | `error_class` | Rejected post-action ownership transfers, for example `saturated`, `shutdown`, or `unknown_provider`. |
| `policy_terminal_post_actions_total` | `operation`, `post_action`, `result` | Once-per-request [terminal post-action](auth-policy.md#terminal-post-actions) completions: `accepted`, `failed`, `disabled`, `no_outcome`, `unavailable`, `admission_rejected`. |

Any increase of `post_action_acceptance_failures_total{error_class="saturated"}` means authentication requests failed
temporarily because the supervisor is undersized or a post-action provider is slow. Size `workers` as roughly the peak
accepted post-actions per second times the average post-action duration in seconds, with headroom.

Since 4.1.0 best-effort plans, currently terminal post-actions, are accepted only while fewer than half of
`queue_capacity` (rounded up) is in flight. Their rejections are counted as
`post_action_acceptance_failures_total{error_class="best_effort_saturated"}`, logged at debug level, and never fail a
request; only `saturated` means that requests failed temporarily.

## Dynamic Client Registration Metrics

The OIDC registration endpoint reports `idp_dynamic_client_registrations_total{outcome,code}` and
`idp_dynamic_client_registration_duration_seconds`. See
[Operating OIDC Dynamic Client Registration](../guides/oidc-dynamic-client-registration.md#monitoring-and-audit).

## MCP Support Endpoint Metrics

`mcp_requests_total{result}` counts the refused requests and the tool calls of the optional read-only MCP endpoint
(`runtime.servers.mcp`). It is exported on the normal `/metrics` endpoint, not on the MCP listener.

| `result` | Meaning |
|---|---|
| `ok` | Tool call answered with a result |
| `tool_error` | Tool call answered with a service error envelope |
| `unauthorized` | `401`: missing or refused token |
| `forbidden` | `403`: insufficient scope |
| `rejected` | Transport guard or body inspection refused the request |
| `rate_limited` | Failed bearer attempt limit reached |
| `busy` | Concurrency limit reached |
| `error` | Token state could not be read |

Alert on sustained `mcp_requests_total{result=~"unauthorized|rate_limited|error"}`. The `nauthilus_runtime` source of
the operational diagnostics reads `ldap_target_health`, `ldap_breaker_state`, `ldap_errors_total`,
`backend_servers_status`, `redis_connection_timeouts_total`, `plugin_auth_events_total`, and
`policy_check_technical_errors_total` from the same registry. See
[Read-only Support Access over MCP](../guides/support-mcp-access.md#audit-and-monitoring).

## Native Go Plugin Metrics

The native plugin runner exports bounded call metrics for every request-time component:

```text
plugin_calls_total{module,component,extension_point,method,result}
plugin_call_duration_seconds{module,component,extension_point,method,result}
plugin_reconfigure_total{module,result}
plugin_auth_events_total{outcome,lane}
```

`plugin_reconfigure_total` counts one increment per module and configuration reload. `result` is `reloaded`,
`unchanged`, `restart_required`, `rejected`, `failed`, or `aborted`; see
[Reload versus restart](native-go-plugins.md#reload-versus-restart).

Plugins can also register counters, gauges, histograms, and summaries through the public `Host.Metrics(scope)` facade. Their collectors use the `nauthilus_plugin_<scope>_...` namespace and a host-owned `plugin_scope` label. Metric names and labels must use Prometheus-compatible syntax; `plugin_scope` is reserved.

Every observation must supply exactly the declared labels. Invalid observations are dropped because the public observation methods do not return an error. Plugin authors must keep labels bounded and must not use usernames, IP addresses, account names, URLs, queries, session IDs, or error strings.

The runner also counts host diagnostic events delivered to event sinks in `plugin_auth_events_total{outcome,lane}`:
`outcome` is `queued`, `delivered`, `failed`, or `dropped`; `lane` is `mfa`, `oidc_completion`,
`bruteforce_lifecycle`, `bruteforce_counted`, or `bruteforce_hits`. A full lane drops events instead of blocking
requests; alert on `dropped`. See
[ClickHouse](../developer/go-plugins/reference-plugins/clickhouse.md#metrics-spans-and-debug).

Bundled reference plugins add:

- GeoIP: `geoip_lookup_total`, `geoip_lookup_seconds`, `geoip_database_records`, and `freshness_total` below its plugin
  namespace;
- ClickHouse (`nauthilus_plugin_clickhouse_...`): `clickhouse_queued_rows_total`, `clickhouse_flush_batches_total`, and
  `clickhouse_flush_duration_seconds` for login rows (queue results include `dropped_reject_limit`), the same three
  families with the `clickhouse_event_` prefix for step events, and with `clickhouse_bruteforce_{lifecycle,counted,hits}_`
  for brute-force evidence;
- Have I Been Pwned: check, HTTP-duration, and mail-attempt metrics;
- Reputation (`nauthilus_plugin_reputation_...`): `learning_total`, `learning_queue_pending`, `learning_queue_active`,
  `admission_total`, `observations_total`, `subject_updates_total`, `storage_total`, `assessments_total`, and the
  journal metrics `journal_total`, `journal_last_applied_timestamp_seconds`, `journal_replay_remaining_seconds`,
  `journal_processing_seconds`, and `journal_delivery_seconds`;
- DKIM2 intelligence: `nauthilus_plugin_dkim2_intelligence_composition_total{result}`.

The host's native Redis script runtime reports `script_operations_total{operation,result}` and
`script_duration_seconds{operation,result}` in the `redis_runtime` scope (`nauthilus_plugin_redis_runtime_...`).
`operation` is `upload`, `run`, or `reload`.

See [Host Services](../developer/go-plugins/host-services.md#metrics) and the [Metrics API reference](../developer/go-plugins/api-reference/services.md#metrics).
