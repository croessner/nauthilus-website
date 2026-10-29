---
title: DKIM2 and Rspamd Policy Integration
description: Operator contract for sending verified DKIM2 evidence from Rspamd to the Nauthilus Generic Policy API and deciding with correlated reputation, GeoIP/ASN, and identity facts
keywords: [DKIM2, Rspamd, Policy API, Redis, Milter, reputation, GeoIP]
sidebar_position: 9
---

# DKIM2 and Rspamd Policy Integration

This integration lets Rspamd narrow an otherwise applicable DKIM2 `PASS` through the Nauthilus Generic Policy API.
Each component keeps one job:

- `dkim2d` is the cryptographic verifier.
- Rspamd is the Milter adapter.
- Nauthilus Policy is the only decision authority for the extra reputation, identity, and Recipe assessment.

Inside Nauthilus, the decision uses correlated evidence from three bundled native plugins: `geoip`, `reputation`, and
`dkim2-intelligence`. The static `dkim2-reputation` plugin from `v4.0.0-alpha.1` has been removed. See
[Migrating from the static provider](#migrating-from-the-static-provider).

:::info Released adapter, separate live-daemon acceptance gate

DKIM2 `v0.1.22` publishes the aligned Rspamd adapter. It requires, validates, and correlates the `request_id` that
Nauthilus echoes back. Its strict response contract and DMARC signal mappings are covered by the Lua suite and by the
neutral Rspamd/Nauthilus/Milter Policy harness. The harness deliberately stubs `POST /v1/process`, so it does not prove
that a live `dkim2d` produces a verifier `PASS` for your DNS and message-wire path. Complete that separate live-daemon
acceptance check before you enable production enforcement.

:::

## Request Path and Ownership

```text
MTA -> Rspamd DKIM2 normal filter -> Redis claim or dkim2d POST /v1/process
    -> DKIM2_NAUTHILUS_POLICY postfilter -> Nauthilus POST /api/v1/policy/decisions
         geoip (smtp_peer) -> reputation (assessment) -> dkim2_intelligence (assessment) -> Policy rules
    -> Rspamd composites -> DKIM2_RETRY_FINALIZE idempotent finalizer
```

- **Normal filter.** Handles applicability, DKIM2 verification, replay state, daemon policy, and retry-cache lookup. It
  enforces verifier `FAIL`, `PERMERROR`, and `TEMPERROR`, non-permittable replay, reject, tempfail, and
  `out_of_band_required` without calling Nauthilus.
- **Policy postfilter.** Runs only for an applicable scan. That means a strictly validated verifier `PASS` whose scope is
  a single-hop `current` projection or a complete `chain` projection, whose daemon `local_policy_verdict` and
  `disposition` are `accept` or `continue`, and whose replay class is `first_seen` or `exploded`. The postfilter may
  narrow that result. It cannot widen a daemon rejection or temporary failure.
- **Finalizer.** Observes the effective Rspamd action after filters, postfilters, and composites. It atomically arms a
  soft-reject retry or consumes a terminal cached result.

The registered Policy symbols are exact:

- `DKIM2_NAUTHILUS_POLICY` is a medium-priority, zero-score postfilter with `nostat` and `ignore_passthrough`.
- `_PERMIT`, `_DENY`, and `_INDETERMINATE` are virtual zero-score children of that symbol.
- `DKIM2_RETRY_FINALIZE` is a zero-score idempotent symbol with `nostat` and `ignore_passthrough`.

## Generic Policy Contract

The request uses:

- Policy API version `1`;
- target `dkim2/accept-message-instance` and schema `dkim2/accept-message-instance/v1`;
- projection `dkim2.verifier-projection.v1`;
- one fresh `request_id` per Policy attempt.

The production caller is the dedicated Policy-Basic principal `rspamd-verifier`. It is not an application subject, and
the request carries no `subject`.

The transport envelope identifies:

- version `1` and a fresh opaque `request_id`;
- target namespace `dkim2` and action `accept-message-instance`;
- resource type `dkim2-message-instance`;
- environment service `rspamd` and protocol `milter`.

Production requests disable diagnostics.

Wire values use the Generic Policy one-of wrappers directly. For example:

- `{"string":"dkim2.verifier-projection.v1"}` for `dkim2.projection_schema`;
- `{"string":"203.0.113.25"}` for `rspamd.smtp_client_ip`;
- `{"records":[...]}` for `dkim2.chain`.

There is no `ip` Policy value kind and no `kind`/`value` JSON envelope. The chain must contain at least one complete
record. An empty or abbreviated record list is invalid.

The canonical tracked example `server/docs/policy-layer/dkim2_rspamd_policy_request_v1.example.json` in the Nauthilus
source tree contains a complete runnable bounded projection. Rspamd transports verifier-owned `resource.dkim2.*` facts
and adds its own privacy-minimized `environment.rspamd.*` observations. The current SMTP peer
(`environment.rspamd.smtp_client_ip`, taken from `task:get_from_ip()`) is mandatory. It is current-hop context, never
historical-hop IP evidence. Raw message content, addresses, credentials, selectors, keys, signatures, and Recipe payloads
are excluded.

The chain is an ordered record list of at most 128 hops. Each record binds:

- the sequence, Message-Instance, and signer domain;
- the algorithms and custody transition;
- the authenticated flags;
- the Recipe digest and change classes;
- the affected header names;
- the history state and body availability;
- the projection and hop digests.

Lists are sorted byte-lexically and unique. Digest values are exactly 32 decoded bytes. Missing, duplicate,
out-of-order, unknown, incoherent, oversized, or wrongly typed data fails closed.

Projection scope must match the aggregate facts:

- **`current`.** Exactly one record. `historical_content`, `historical_signatures`, `do_not_modify_state`, and
  `do_not_explode_state` are `not_evaluated`, and `custody_structure` is `not_present`.
- **`chain`.** `historical_content` and `historical_signatures` are `complete`. Custody and both protection aggregates
  are evaluated.

The optional resource attribute `dkim2.received_dsn_propagation` is admitted as a string of at most 30 characters. The
verifier sends it only for received delivery-status notifications. Its closed values are `not_applicable`, `eligible`,
`terminal_origin`, `not_failure`, `forbidden_null_previous_sender`, `unsupported_chain`, `not_reconstructable`, and
`not_evaluated`.

The released mapping adds `dmarc.temperror` (from `DMARC_DNSFAIL`) and `dmarc.permerror` (from `DMARC_BAD_POLICY`) to
the existing pass/fail signals. Policies must still use only the documented closed normalized vocabulary. Arbitrary
Rspamd symbol names and options are not forwarded.

## Correlated Policy Providers

Nauthilus uses the existing generic `DecisionFactProvider` API. It has no DKIM2-specific handler, validator, or core
decision type. The reference Policy schedules three native providers at the `final_decision` checkpoint. Each is skipped
by the scheduler guard `nonpass_verifier_state` when `resource.dkim2.verification_state` is not `PASS`, and each fails
to `indeterminate`.

| Policy alias | Provider | Purpose |
| --- | --- | --- |
| `smtp_peer` | `dkim2/plugin.geoip.smtp_peer` | GeoIP/ASN evidence for the exact current SMTP peer (`plugin.geoip.*`). |
| `reputation_assessment` | `dkim2/plugin.reputation.assessment` | Reputation tuples for every signer domain and for the peer IP, network, and ASN (`plugin.reputation.dkim2_subjects`, plus `_fast`, `_operational`, and `_baseline`). |
| `intelligence_assessment` | `dkim2/plugin.dkim2_intelligence.assessment` | Correlates the verifier chain, the reputation tuples, the GeoIP evidence, and the operator identity contracts. |

`dkim2-intelligence` publishes three facts atomically:

- `plugin.dkim2_intelligence.assessed_chain` has one record per hop, with signer reputation, identity contract
  state/strength, and closed `violation_classes`.
- `plugin.dkim2_intelligence.smtp_peer` has one record with independent IP, network, ASN, and GeoIP states and the
  target identity contract state.
- `plugin.dkim2_intelligence.assessment_complete` is structural completeness only. It is never a permit signal.

Identity contracts bind signer domains to the CIDRs or ASNs they are expected to send from. They apply only to the target
hop. Historical hops can only be `domain_only`. No provider is trusted implicitly. The field lists, identity rules, and
configuration keys are in the [DKIM2 intelligence reference plugin](../developer/go-plugins/reference-plugins/dkim2-intelligence.md).
Reputation storage, overrides, and observation are covered by the
[reputation reference plugin](../developer/go-plugins/reference-plugins/reputation.md).

## Reference Policy

The Nauthilus source tree ships two files for this integration:

- `server/docs/examples/go_plugin_dkim2_intelligence.yml`, the module fragment;
- `server/docs/examples/policy_dkim2_rspamd_verifier.yml`, the complete strict Policy. It covers the `rspamd-verifier`
  API client and its admitted attributes, limits, providers, fact schemas, rules, and target.

The target runs in `enforce` mode with `no_match: deny`, a 2 s evaluation timeout, and a 500 ms default provider
timeout. The three providers each use 400 ms.

The rule order is significant:

1. **Verifier and upstream invariants.** `deny_nonpass_verifier_state`, `deny_nonpass_authentication`, `deny_replay`
   (unless `first_seen` or `exploded`), `deny_terminal_nd` (`custody_structure = terminal_nd_requires_oob`),
   `deny_noncontinuable_local_verdict`, and `deny_noncontinuable_disposition`.
2. **Composition invariants.** `deny_incomplete_assessment`, `deny_signature_state`, and `deny_integrity_violation`.
   The last one fires when any hop reports `authentication_not_pass`, `body_unavailable`, `do_not_explode_violated`,
   `do_not_modify_violated`, `history_not_matched`, or `upstream_nonpermittable`. The shipped rule also lists
   `terminal_oob_required`, which the plugin never emits; terminal custody is enforced by `deny_terminal_nd`.
3. **Operator reputation and Recipe denies.** These include:
   - `deny_bad_reputation_body_change`: a suspicious or blocked signer combined with `body.rewrite`;
   - fresh suspicious or blocked peer IP or network reputation with confidence ≥ 0.6;
   - peer ASN reputation with samples ≥ 20 and confidence ≥ 0.7;
   - `deny_rspamd_risk_on_known_bad_ingress`: an Rspamd `metric_score` ≥ 8.0 on known-bad ingress;
   - `deny_body_change_for_header_only_signer`;
   - `deny_unusable_reputation`: any signer, IP, network, ASN, or GeoIP state that is not `fresh`;
   - `deny_target_identity`: a target hop that is not `matched` with strength `cidr` or `asn`.
4. **One permit.** `permit_selected_provider_header_relay` requires all of the following:
   - complete assessment;
   - every hop `pass`, `fresh`, and in the band `trusted`, `positive`, or `neutral`, with no `body.rewrite`;
   - a target signer from the selected set that is identity-`matched` by `cidr` or `asn`;
   - fresh, non-negative peer IP, network, ASN, and GeoIP evidence.

Record conditions use the record-local expression form: `records` with `attribute`, `quantifier` (`any` or `all`), and
a `where` predicate over one record. For example:

```yaml
- name: deny_target_identity
  checkpoint: final_decision
  require_providers: [intelligence_assessment]
  if:
    records:
      attribute: plugin.dkim2_intelligence.assessed_chain
      quantifier: any
      where:
        all:
          - field: is_target
            eq: true
          - any:
              - field: identity_contract_state
                not_in: [matched]
              - field: identity_contract_strength
                not_in: [cidr, asn]
  then:
    decision: deny
    reason: dkim2_deny_target_identity
```

The signer domains (`relay.example`, `google.example`, `yahoo.example`) and all thresholds are illustrative. Replace
them only after calibration. The shipped fragment sets `identity_contracts: []`, so the unmodified strict Policy denies
every message: at `deny_target_identity` once reputation and GeoIP evidence is fresh, and otherwise already at
`deny_unusable_reputation`.

### Calibration and observation

`server/docs/examples/policy_dkim2_observe.yml` is a calibration companion, not a standalone configuration. Merge it by
target identity. It keeps the target in `enforce` mode, because generic Policy computes proposals in enforce mode, and
the consumer target has no reachable effects. To log proposals without applying them to delivery, set the Rspamd adapter
setting `dkim2.nauthilus.mode` to `observe`. Any separate reputation observation ingestion target also stays in
`enforce` mode, so that its acknowledged storage effect runs.

## Response Mapping

Rspamd strictly validates the response and consumes only `effect` and `status.retryable`:

| Nauthilus result | Rspamd outcome |
| --- | --- |
| `permit` | Continue without forcing a global accept and without widening the DKIM2/Rspamd result |
| `deny` | Permanent reject; consume the retry entry |
| retryable `indeterminate` | Soft reject; arm the DKIM2 retry result |
| non-retryable `indeterminate` | Permanent reject; consume the retry entry |
| unexpected `not_applicable`, a malformed response, a transport, TLS, or authentication failure, or any HTTP failure | Technical soft reject; arm or re-arm the retry entry |

After a `permit`, an unrelated final Rspamd soft reject (including greylisting) arms the retry entry, while a final
accept or unrelated permanent reject consumes it. Nauthilus reason text, response bodies, and provider errors are never
copied into SMTP replies, symbols, logs, or metrics.

## Retry Cache and Failure Semantics

The Redis/Valkey cache is an identity-bound, HMAC-protected retry-result cache. It is not a replay authority:

- A first soft reject arms a bounded entry.
- One retry worker can claim it.
- Busy or corrupt state fails closed.
- A recoverable timeout re-arms it.
- A terminal action consumes it.

Rotate the cache authority generation whenever any of these change: the verifier code or schema, local policy, replay
authority, endpoint tenant, or process capability.

Use a dedicated Redis authority and ACL. Keep the process capability and the retry HMAC key in protected files. Never
print them or embed them in configuration, logs, traces, metrics, or tickets. TLS and hostname validation for the
Nauthilus Policy endpoint must remain enabled. The SMTP client IP is sensitive. Keep it out of normal logs, metrics,
traces, reports, diagnostics, and error bodies, and never use it in plaintext as a Redis key component.

There are currently no cache-lifecycle counters or symbols for miss, store, busy, hit, arm, consume, stale, or deadline.
Do not build operations claims around metrics that do not exist. The adapter provides finalization-failure logging.
Validate cache behavior with bounded scenario tests and Redis-safe evidence. On the Nauthilus side,
`nauthilus_plugin_dkim2_intelligence_composition_total{result=...}` counts composition outcomes, and the reputation
plugin exports its own assessment telemetry.

## Migrating from the Static Provider

`v4.0.0-alpha.1` shipped `dkim2-reputation`, a source-only plugin with a static snapshot of domain and network
classifications and signer contracts. It emitted `plugin.dkim2_reputation.assessed_chain` with a derived `acceptable`
flag. That plugin, its provider `dkim2/plugin.dkim2_reputation.assessment`, and its fact no longer exist. Configurations
and Policies that reference them fail activation.

1. Export the old `dkim2_reputation` module `config` block as JSON, without credentials.
2. Run the offline converter from the Nauthilus source tree:
   `python3 scripts/convert-static-reputation.py old.json import.json --creator <operator> --audit-prefix <prefix> [--expires-at <unix>]`.
3. Apply each generated override with `PUT /api/v1/custom/reputation/override`, using a token with `nauthilus:admin`.
   The origin is `cutover.static_dkim2_v4`.
4. Add the generated `ip_override_networks` to the reputation plugin and the generated `identity_contracts` to
   `dkim2_intelligence`.
5. Merge the generated `policy_rules` (an uncontracted-signer deny and per-signer Recipe guards) after the invariant
   denies and before any permit.
6. Replace the `dkim2_reputation` module with the `geoip`, `reputation`, and `dkim2_intelligence` modules. Replace
   Policy references to `plugin.dkim2_reputation.*` with the new facts. Start from the shipped reference Policy rather
   than porting `acceptable`.
7. Calibrate in observe mode (see above) before you enforce.

The field-by-field mapping is in the
[plugin reference](../developer/go-plugins/reference-plugins/dkim2-intelligence.md#migrating-from-dkim2-reputation).

## Released Evidence and Required Operator Acceptance

DKIM2 `v0.1.22` was published from commit `f1ae33d4218e62bc9f3e673bddb421b822c17213` after these checks passed:

- repository guardrails;
- the vulnerability check;
- the Lua contract tests;
- an independent review;
- the full neutral Policy E2E.

That run observed 15 stub calls, 14 Policy calls, and 11 requests forwarded through the Policy observer. It covered
unsigned, first-seen/greylist, retry/consume, duplicate, malformed, timeout, provider rejection, concurrency, Redis
outage, and unrelated-Rspamd-action scenarios. That evidence predates `v4.0.0-alpha.1`, so it was recorded before
Nauthilus replaced the static provider with the correlated provider graph. Re-run the harness against your current
configuration.

Before production enforcement, operators must still:

1. verify the exact adapter artifact and configuration without exposing credentials;
2. run the Rspamd configuration checks and the neutral harness in the deployment candidate;
3. pass a separate live `dkim2d` end-to-end path through the real DNS TXT record, the signed-message wire representation,
   Rspamd, Nauthilus, and the final Milter result;
4. configure identity contracts and reputation data, and calibrate thresholds in observe mode;
5. start on a non-production listener and prove timeout, retry-cache, denial, and unrelated-action behavior.

The release's bounded live-daemon attempt reached healthy `dkim2d` and Rspamd processes but ended with
`451 Temporary DKIM2 verification failure` before reaching Nauthilus. Content-free diagnostics could not tell whether the
cause was DNS TXT acceptance or synthetic signature wire fidelity. That attempt is therefore not passing verifier
evidence and must not waive step 3.
