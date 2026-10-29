---
title: Reputation Plugin
description: Reference for the bundled generic reputation plugin with evidence admission, decaying assessment, audited overrides, authentication learning, and the optional Kafka journal
keywords: [Go plugin, reputation, DecisionFactProvider, obligation, Redis, Kafka, HMAC, Policy]
sidebar_position: 6
---

# Reputation Plugin

The bundled `reputation` plugin is a protocol-neutral reputation store for Policy. It admits independent evidence
from an explicit source and signal catalog, stores it as decaying per-subject masses in primary Redis, and publishes
closed assessment tuples as Policy facts. It never selects a decision itself: Policy keeps permit/deny authority, and
consumers such as the authentication target or the [DKIM2 Intelligence plugin](./dkim2-intelligence.md) decide what
a band means.

The plugin replaces the removed Lua `geoip_reputation.lua` subject plugin. There is no runtime alias for the old
`lua.plugin.geoip_reputation.*` facts or its `GEOIP_REPUTATION_*` settings.

This page is the source-level reference. For a deployment walkthrough, see
[Operating the reputation subsystem](../../../guides/reputation-operations.md).

The container artifacts are:

```text
/usr/local/lib/nauthilus/plugins/reputation.so
/usr/local/lib/nauthilus/plugins/reputation.so.minisig   (signed release images)
/usr/app/reputation-worker                                  (Kafka consumer worker, stable image only)
```

## Public contract

| Item | Value |
| --- | --- |
| Metadata name | `reputation` |
| Product version | `0.1.0` |
| Interfaces | `Plugin`, `RuntimePlugin` (not reloadable; configuration changes require a restart) |
| Observation fact provider | `observation_context` for the exact target `reputation/observe` |
| Storage effect provider | `storage`, `host_sync` execution, selected through a Policy obligation |
| Assessment fact providers | one per configured `target_bindings[].component` (default `assessment`) |
| Authentication learning | `ObligationTarget` named `learn_outcome`, registered only when `auth_learning` is set |
| Management hooks | `POST /api/v1/custom/reputation/lookup`, `PUT` and `DELETE /api/v1/custom/reputation/override`, `POST /api/v1/custom/reputation/allocation` |
| Required host services | primary Redis facade, `plugins.opaque_identifier_tagger`, metrics |
| Sensitive capabilities | none; learning never receives credentials or password digests |

## Data model

### Subjects

A subject is a typed identity. Supported kinds are `ip`, `network`, `asn`, `dns_domain`, `account`, and `service`.
Raw values are bounded to 512 UTF-8 bytes and canonicalized before use:

- IPv4-mapped IPv6 addresses are unmapped and networks are masked;
- networks derived from an IP use `network_subjects.ipv4_prefix` and `ipv6_prefix`;
- ASNs are positive 32-bit decimal values;
- DNS names become lower-case IDNA A-labels;
- accounts use `account_normalization` (`exact` or `lowercase`);
- services must appear in the configured `services` list.

Canonical subjects are converted to HMAC tags by the host opaque identifier service. Neither raw subjects nor HMAC
tags are written to Policy output, logs, metrics, journal records, or management responses.

### Profiles, masses, and scoring

Every subject keeps separate risk and trust masses per source class for three fixed decay profiles: `fast`,
`operational`, and `baseline`. Each profile has its own `half_life`. Reads decay the stored masses to the Redis clock
without rewriting state. The configured `score` parameters produce:

```text
log_odds     = ln((risk + alpha) / (trust + alpha))
confidence   = 1 - exp(-(risk + trust) / saturation)
signed_score = tanh(log_odds / temperature) * confidence
```

Positive signed values are risk; negative values are trust. The `bands` block maps the result, confidence, samples,
and source diversity to a closed band: `unknown`, `trusted`, `positive`, `neutral`, `suspicious`, `blocked`, or
`unavailable`.

Learned bands are evaluated in this order: `blocked` (only with `learned_blocked`), `suspicious` (fast or operational
risk), `trusted` (operational trust, suppressed by recent severe risk), `positive`, `neutral`, then `unknown`. Operator
overrides take precedence over learned state in the order `blocked`, `trusted`, `neutral`.

`learned_blocked: false` keeps learned evidence from ever producing `blocked`. When enabled, learned blocking also
requires either recent authoritative risk or at least `minimum_block_source_classes` (at least two) current
risk-contributing source classes. Changing read thresholds or the score transform does not reset stored evidence.

### Model identity

The `model_id` and an internal fingerprint cover every ingestion-relevant setting: normalization, source and signal
catalog, profile half-lives, caps, subject scope, and retention. Changing any of these requires a new `model_id`.
Startup rejects a known `model_id` whose stored fingerprint differs. One optional `shadow_model` can accumulate the
same evidence with different profiles, caps, and signal weights under a separate `model_id`; it never replaces the
active model.

The following operational settings are excluded from the fingerprint and can change without a new model:
`auth_learning_queue`, `journal`, `event_manifest_capacity_per_source`, `subject_seen_capacity_per_subject`,
`new_subject_capacity_per_source_hour`, `source_admission_capacity`, `bands`, `score`, `target_bindings`, and
`ip_override_networks`.

## Configuration reference

Configuration is decoded strictly. Unknown keys, wrong types, and out-of-range values reject registration. There are
no implicit production defaults for model settings; the
[`go_plugin_reputation.yml`](https://github.com/croessner/nauthilus/blob/main/server/docs/examples/go_plugin_reputation.yml)
example contains calibration values, not recommendations.

Identifiers (model IDs, source names, signal names, classes, roles, topics, group IDs) must match
`^[a-z][a-z0-9_.-]{0,63}$`.

### Model and storage

| Field | Validation and meaning |
| --- | --- |
| `state_schema` | Required, exactly `reputation-state.v1`. |
| `model_id` | Required identifier of the active model. |
| `subject_scope` | Opaque identifier scope for subject tags. Must exist under `plugins.opaque_identifier_tagger`. |
| `manifest_scope` | Separate scope for event manifests and allocation shards; must differ from `subject_scope`. |
| `allocation_maintenance` | `false` normally. `true` starts only administrative access after an interrupted allocation drain. |
| `allocation_drain_generation` | Integer 0..1,000,000. Increment only after a completed drain (see the operator guide). |
| `retention` | Subject state lifetime, at most one year. |
| `event_manifest_ttl` | Immutable manifest lifetime; at most `retention`. |
| `subject_seen_ttl` | Replay-marker lifetime; at least `event_manifest_ttl` and at most `retention`. |
| `maximum_retry_horizon` | Retry window for exact replays; at most `event_manifest_ttl`. |
| `maximum_source_classes` | 1..8. |
| `source_class_caps.<class>` | `risk`, `trust`, `samples` caps per class; at least one class and no more than `maximum_source_classes`. |
| `profiles.fast\|operational\|baseline.half_life` | All three are required; `fast <= operational <= baseline <= retention`. |
| `score` | `alpha` (0..1000], `saturation` (0..1,000,000], `temperature` (0..100]. |
| `bands` | Thresholds, see [Bands](#bands). |
| `network_subjects` | `ipv4_prefix` 1..32 and `ipv6_prefix` 1..128. |
| `account_normalization` | `exact` or `lowercase`. |
| `services` | Up to 64 identifiers accepted for the `service` subject kind. |
| `maximum_new_subjects_per_source_hour` | 1..100,000. Part of the model fingerprint. |
| `maximum_event_manifests_per_source` | 16..10,000,000, divided over 16 allocation shards. Part of the fingerprint. |
| `maximum_seen_events_per_subject` | 1..10,000,000. Part of the fingerprint. |
| `shadow_model` | Optional `model_id`, `profiles`, `source_class_caps`, and `signal_weights` for every signal. |

For every source, `maximum_lateness + future_clock_skew + maximum_retry_horizon` must fit inside both
`event_manifest_ttl` and `subject_seen_ttl`.

### Operational capacity overrides

These fields expand storage or admission headroom without changing the model fingerprint, stored scores, or
deduplication. Omit them or set `0` to keep the fingerprinted budget.

| Field | Validation and meaning |
| --- | --- |
| `event_manifest_capacity_per_source` | At least `maximum_event_manifests_per_source`, at most 10,000,000. Divided over 16 shards. |
| `subject_seen_capacity_per_subject` | At least `maximum_seen_events_per_subject`, at most 10,000,000. |
| `new_subject_capacity_per_source_hour` | At least `maximum_new_subjects_per_source_hour`, at most 10,000,000. |
| `source_admission_capacity.<source>` | `requests_per_second` and `max_concurrency` at or above the source's own values. Host ceilings are 10,000 requests/second and 1,024 concurrent calls. |

Apply increases to every writer sharing the Redis prefix at the same time. Do not lower an expanded capacity, or roll
back to a binary that enforces the smaller budget, until live manifest and seen sets have expired below the old bound.
Older writers reject oversized sets rather than resetting them.

### Sources

`sources.<name>` declares one evidence producer. There must be 1..64 sources.

| Field | Meaning |
| --- | --- |
| `source_policy_id` | Globally unique, immutable while its event history exists. |
| `binding.kind` | `api_caller` (selected by an authenticated Policy API principal) or `host_execution` (selected by a host-created callback identity). The two never fall back to each other. |
| `binding.caller_principal` | For `api_caller`: exact, case-sensitive `policy.api.clients[].principal`. |
| `binding.module`, `component`, `extension_point`, `operation`, `targets` | For `host_execution`: the exact callback identity, for example `reputation` / `learn_outcome` / `obligation` / `execute` / `[authn/authenticate]`. |
| `source_class` | A configured `source_class_caps` class. |
| `allowed_signals` | Signals this source may submit. |
| `allowed_subjects` | `role: [kinds]` the caller may supply. |
| `derived_subjects` | `role: [kinds]` the plugin derives, for example `network` from an IP, or `asn` through a GeoIP provider. |
| `maximum_subjects` | Bounded subject count per event. |
| `maximum_lateness`, `future_clock_skew` | Accepted event-time window. Skew is at most one hour. |
| `allow_magnitude` | Whether the producer may send `magnitude`. |
| `requests_per_second`, `max_concurrency` | Baseline admission limits. |
| `asn_provider`, `asn_fact`, `asn_max_age` | Optional exact ASN derivation from a GeoIP record binding (see [ASN derivation](#asn-derivation-from-geoip)). |

An `api_caller` source can only use signals with `evidence_origin` `external_pre_policy` or
`authoritative_external`. A `host_execution` source can only use `host_backend_outcome`. Direct caller-supplied ASN
subjects require `authoritative_external` evidence.

### Signals

`signals.<name>` declares one kind of evidence. There must be 1..64 signals.

| Field | Meaning |
| --- | --- |
| `direction` | `risk` or `trust`. |
| `weight` | Positive, at most 1000. |
| `magnitude` | `forbidden`, `optional`, or `required`. |
| `magnitude_range` | `[min, max]` inside `[0, 1]`; required unless `magnitude: forbidden`. |
| `subject_roles` | `role: {kind: multiplier}` with multipliers in (0, 1]. |
| `source_classes` | Classes allowed to emit this signal. |
| `evidence_origin` | `external_pre_policy`, `authoritative_external`, or `host_backend_outcome`. |
| `authoritative` | Whether the evidence counts as authoritative for risk guards. |
| `max_event_age` | Maximum event age, at most `retention`. |
| `profiles` | Profiles this signal contributes to. |

### Bands

| Field | Meaning |
| --- | --- |
| `learned_blocked` | Allow learned evidence to reach `blocked`. |
| `minimum_confidence`, `minimum_samples` | Evidence needed for `neutral`; below it, learned state that matches no other band stays `unknown`. |
| `diversity_mass_floor` | Mass a source class needs to count toward diversity. |
| `minimum_block_source_classes` | Independent risk classes required for learned blocking (at least 2). |
| `authoritative_risk_max_age`, `severe_risk_max_age`, `severe_risk_score` | Recency guards for blocking. |
| `trusted`, `positive`, `suspicious_fast`, `suspicious_operational`, `blocked` | Each `{score, confidence, samples}` threshold. |

### Target bindings (assessment)

`target_bindings` (up to 32) prepare assessment facts for exact Policy targets:

| Field | Meaning |
| --- | --- |
| `target` | Exact `namespace/action`, one binding per target. |
| `component` | Fact provider name, default `assessment`. A component belongs to one namespace; use distinct names across namespaces. `observation_context` is reserved. |
| `output_fact` | Base output name. The provider also publishes `<output_fact>_fast`, `<output_fact>_operational`, and `<output_fact>_baseline`. |
| `decision_profile` | Profile used for `<output_fact>`, default `operational`. |
| `subjects` | 1..8 extractors. |

Each extractor has `attribute`, `role`, and `kind`, and optionally:

- `category` when the attribute has no category prefix;
- `provider` for `plugin.*` facts, which also require a direct Policy dependency on that producer;
- `input_kind: integer` (only for `asn`), otherwise canonical strings;
- `derive: network_from_ip` (only for `kind: network`) using the configured prefixes;
- `optional: true` for scalar inputs: absence yields an `unavailable` tuple without a lookup;
- `field`, `correlation_fields`, and `correlation_types` for flat record extraction; correlation values stay attached
  to the same source row and cannot overwrite tuple fields.

Observation and learning expansion admits at most 24 subjects per event. Read-only assessment extraction is bounded at
160 subjects per binding.

### IP overrides from networks

`ip_override_networks` is a list of at most 128 canonical CIDRs. An IP assessment may then use the most specific
active operator override stored on one of these networks. An exact-IP override still wins, expired entries fall
through to less specific networks, and the tuple keeps the IP's actual learned measurements. This does not change
learned network aggregation.

### Authentication learning

| Field | Meaning |
| --- | --- |
| `auth_learning.success_signal` | A `trust` signal with `host_backend_outcome` origin. |
| `auth_learning.bad_credentials_signal` | A different `risk` signal with the same origin. |
| `auth_learning_queue.capacity` | Waiting events, 1..65536, default `1024`. |
| `auth_learning_queue.max_age` | Total budget including queueing, rate waiting, retries, and delivery. Positive, at most `5m`, default `30s`. |
| `auth_learning_queue.timeout` | Per storage attempt, at most `max_age`, default `5s`. |

The `auth_learning` mapping is part of the fingerprint. The queue block is not.

### Journal

The optional `journal` block enables the durable Kafka transport:

| Field | Validation and meaning |
| --- | --- |
| `role` | `producer` (authentication/Policy servers) or `consumer` (the `reputation-worker`). |
| `brokers` | 1..16 `host:port` entries with numeric ports. |
| `topic`, `quarantine_topic` | Distinct identifiers. |
| `group_id` | Consumer group identifier. |
| `ca_file`, `certificate_file`, `key_file` | Absolute paths for mutual TLS. |
| `delivery_timeout` | `100ms`..`10s`. |

The Kafka client requires acknowledgement from all in-sync replicas, uses zstd batch compression, and bounds client
buffers to 1,024 records and 16 MiB. Journal records are limited to 256 KiB.

## Components and outputs

### Observation (`reputation/observe`)

The `observation_context` provider performs read-only admission for an external caller and produces:

| Fact | Type | Meaning |
| --- | --- | --- |
| `plugin.reputation.observation_valid` | boolean | Event passed admission. |
| `plugin.reputation.observation_learning_eligible` | boolean | Event may be stored. |
| `plugin.reputation.observation_reason` | string | `valid`, `source_unbound`, `signal_invalid`, `time_invalid`, `magnitude_invalid`, `subject_invalid`, `subject_duplicate`, `input_invalid`, `event_conflict`, or `unavailable`. |
| `plugin.reputation.observation_source_class` | string | Configured source class. |
| `plugin.reputation.observation_evidence_origin` | string | Configured origin. |
| `plugin.reputation.observation_subject_kinds` | strings | Admitted subject kinds. |
| `plugin.reputation.admitted_subjects` | records | Protected plan visible only to the storage provider. |

Only a selected `reputation/store_observation` obligation, executed by the `storage` effect provider, writes state.
The effect is idempotent over `resource.reputation.event_id`, rechecks the caller binding and catalog, and cannot be
broadened by caller records. A duplicate request is an ordinary successful decision.

Startup requires `policy.api` to be enabled, exactly one `reputation/observe` target with schema
`reputation/observe/v1`, `mode: enforce`, and `no_match: deny`, and one client profile per `api_caller` principal whose
concurrency and rate limits do not exceed the source's effective limits and whose `diagnostics` is `false`.

### Assessment tuples

Each assessment output is a record list. Every record contains `role`, `kind`, any configured correlation fields, and
the closed tuple shared through `contrib/plugins/internal/reputationview`:

| Field | Meaning |
| --- | --- |
| `state` | `fresh`, `not_found`, or `unavailable`. `stale` is part of the closed vocabulary but not emitted by this provider. |
| `profile` | `fast`, `operational`, or `baseline`. |
| `band` | `unknown`, `trusted`, `positive`, `neutral`, `suspicious`, `blocked`, or `unavailable`. |
| `override` | `none`, `trusted`, `neutral`, or `blocked`. |
| `risk_score`, `trust_score`, `confidence`, `samples`, `source_diversity`, `age_seconds` | Present only for measured state. |

Missing state yields `state=not_found`, `band=unknown`, and no numbers. A read failure yields `state=unavailable`,
`band=unavailable`, and no numbers. An active override can change a missing state's band without inventing scores.

Assessments always read primary Redis through a registered script. When the host exposes a previous key version,
both active and previous tags are read; a failure in either slot makes every profile unavailable. Histories are
merged conservatively (greater risk, lower trust, lower confidence, lower samples and diversity); evidence is never
summed across slots. There is no replica or stale-cache read path.

### Authentication learning

`authn/plugin.reputation.learn_outcome` is a capture-only obligation. The host freezes a `BackendOutcomeView` right
after the verified or cached backend result, before final Policy decisions. The learner uses:

- the host request GUID as event identity and the capture time as event time;
- the original normalized backend account;
- the client IP and derived network.

It never reads final authentication flags, caller facts, passwords, or password hashes. Pre-backend denials,
lookup-only requests, and health checks do not learn. A successful backend result emits `success_signal`; bad
credentials emit `bad_credentials_signal`. With the example catalog, success adds low trust to account, IP, and
network, while bad credentials add low risk to IP and network only. Neither signal spreads to ASN.

Capture places the event in a bounded process-local queue and returns immediately. Queue overflow, unavailable storage,
and expired jobs never change the authentication result. A fixed worker pool, sized by the source's effective
`max_concurrency` and rate-limited by its `requests_per_second`, performs Redis admission and, when a producer journal
is configured, acknowledged Kafka delivery. Transient failures retry the same event identity at least 250 ms apart
within `max_age`. A graceful stop drains the queue within the host shutdown deadline; remaining items are counted as
`shutdown`.

### ASN derivation from GeoIP

A source can add an ASN subject from a GeoIP record binding by setting `asn_provider` (for example
`reputation/plugin.geoip.observation`), `asn_fact` (for example `plugin.geoip.observations`), and `asn_max_age`. The
fact must belong to that provider's module. The plugin correlates exactly one record to the admitted IP:

- missing, ambiguous, too old, or unavailable evidence makes ASN-dependent admission indeterminate and writes nothing;
- a verified `not_found` result without a positive ASN omits only the ASN contribution; IP and network learning
  continues;
- sources without ASN expansion are unaffected by GeoIP availability.

The verified-absence rule is part of the fingerprint for ASN-enabled models. Deploy it under a new `model_id` when an
older ASN-enabled model is already registered.

## Durable storage and replay

- All keys used by one atomic operation share one Redis Cluster hash slot. Only the host primary connection, prefix,
  and named script registry are used.
- A manifest-scope HMAC binds the source policy and producer event ID to one of 16 allocation shards.
- Before any subject write, Redis creates or compares an immutable manifest over timestamp, magnitude, source class,
  origin, model fingerprints, and the sorted opaque subject plan. A different payload for the same event is
  `event_conflict`.
- Each subject update decays masses, applies bounded contributions, and records a seen tag. Partial fan-out and lost
  acknowledgements resume without double counting.
- Malformed state, missing deduplication state, unsupported schemas, and numeric corruption fail closed without
  resetting evidence.
- Expired replay markers are pruned in batches of at most 512 per call.
- Each script writes a state hash with one command and probes each key once. A subject shared by many logins, such as
  a NAT address, concentrates work on one Cluster slot by design.
- The storage start retries transient Redis failures (connection errors, timeouts, `LOADING`, `TRYAGAIN`,
  `CLUSTERDOWN`, `READONLY`, `MASTERDOWN`, `MOVED`/`ASK`, `NOSCRIPT`) with a one- to five-second backoff for at most ten
  attempts within about fifty seconds, each logged at `WARN` with an `error_class`. Permanent failures such as ACL
  rejections, script errors, and model or allocation mismatches end the start at once, and the start error keeps the
  concrete Redis cause. See
  [Storage start and Redis readiness](../../../guides/reputation-operations.md#storage-start-and-redis-readiness).

## Management hooks

All four hooks use admin scope and admin authentication: a backchannel bearer token with `nauthilus:admin` is required
and cannot be replaced by configured hook scopes. Bodies are `application/json`, limited to 4096 bytes, and handled
with a 5-second timeout. Unknown or duplicate fields, nulls, query parameters, and wildcard searches are rejected.
Responses carry `Cache-Control: no-store`. The routes return 404 when the plugin is not loaded.

See the [Management API reference](../../../api-reference/management/lookup-reputation.api.mdx) and the
[operator guide](../../../guides/reputation-operations.md#management-api) for request and response details.

## Telemetry

The plugin calls `Host.Metrics("reputation")`, so collectors are exported as `nauthilus_plugin_reputation_<name>` with
`plugin_scope="reputation"`. Label values come from closed vocabularies or the compiled catalog; unregistered values
become `unknown`.

| Definition name | Labels | Meaning |
| --- | --- | --- |
| `learning_total` | `channel` (`external`, `authentication`), `result` | Learning lifecycle outcome. |
| `learning_queue_pending` | none | Authentication events waiting in the queue. |
| `learning_queue_active` | none | Authentication events being processed. |
| `admission_total` | `source_class`, `signal`, `reason` | Read-only admission and manifest probing. |
| `observations_total` | `source_class`, `signal`, `result` | Ingestion attempts, including duplicates and partial results. |
| `subject_updates_total` | `kind`, `result` | Per-subject write outcomes. |
| `storage_total` | `script`, `result` | Registered script results and typed failures. |
| `assessments_total` | `target`, `kind`, `state`, `band`, `override` | Selected-profile assessment output. |
| `journal_total` | `result` (`published`, `applied`, `duplicate`, `retry`, `quarantined`) | Journal outcomes. |
| `journal_delivery_seconds` | none | Time awaiting Kafka acknowledgement, including failed attempts. |
| `journal_processing_seconds` | none | Consumer time to apply one contribution. |
| `journal_last_applied_timestamp_seconds` | none | Consumer: last successful application. |
| `journal_replay_remaining_seconds` | none | Consumer: remaining manifest lifetime of the last processed record. |

`learning_total` results are `applied`, `duplicate`, `partial`, `rejected`, `quota_exceeded`, `unavailable`,
`skipped`, `queued`, `buffered`, `queue_full`, `expired`, `shutdown`, `worker_panic`, and `retried`. `buffered` means
local queue admission only, `queued` means a Kafka acknowledgement, and `applied` means Redis subject updates
completed.

`storage_total` uses the script names `reputation.override.v1`, `reputation.assessment.v1`,
`reputation.metadata.v1`, `reputation.control.v1`, `reputation.manifest.v1`, and `reputation.ingestion.v1`, with
results `success`, `unavailable`, `event_conflict`, `event_time`, `model_mismatch`, `allocation_mismatch`,
`quota_exceeded`, and `override_conflict`.

The host additionally exports `nauthilus_plugin_redis_runtime_script_operations_total` and
`nauthilus_plugin_redis_runtime_script_duration_seconds` with `operation` (`upload`, `run`, `reload`) and `result`
(`success`, `noscript`, `unavailable`) for native Redis scripts.

No metric, log, or journal record contains a raw subject, tag, event ID, caller principal, or message content.

## Build and tests

The release images build the plugin and the worker from the same source tree:

```shell
NATIVE_ARTIFACT_LDFLAGS="$(go run -mod=vendor ./scripts/native_artifact_fingerprint -tags="netgo")"
# Plugin artifact
CGO_ENABLED=1 GOEXPERIMENT=runtimesecret \
go build -mod=vendor -tags="netgo" -trimpath -buildmode=plugin \
  -ldflags "${NATIVE_ARTIFACT_LDFLAGS}" \
  -o build/reputation.so ./contrib/plugins/reputation

# Consumer worker executable
GOEXPERIMENT=runtimesecret \
go build -mod=vendor -tags="netgo reputation_worker" -trimpath \
  -o build/reputation-worker ./contrib/plugins/reputation
```

Build the plugin from the exact host tag or commit, with the same toolchain and tags, as described in
[Bundled Reference Plugins](./index.md#binary-compatibility).

Repository gates:

| Target | Scope |
| --- | --- |
| `GOEXPERIMENT=runtimesecret go test ./contrib/plugins/reputation` | Unit and contract tests. |
| `make reputation-redis-check` | Test-owned Redis/Valkey primary and three-node Cluster: real Lua execution, quotas, rotation, drain, `NOSCRIPT` recovery, and a command-budget check. |
| `make reputation-worker-check` | Worker build and its HTTP boundary. |
| `make reputation-kafka-check` | Isolated single-broker Kafka fixture over loopback plaintext; it does not qualify TLS, ACLs, or failover. |

`make release-guardrails` runs the worker and Kafka checks.
