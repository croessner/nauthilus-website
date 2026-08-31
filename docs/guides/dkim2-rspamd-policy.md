---
title: DKIM2 and Rspamd Policy Integration
description: Operator contract for sending verified DKIM2 evidence from Rspamd to the Nauthilus Generic Policy API
keywords: [DKIM2, Rspamd, Policy API, Redis, Milter]
sidebar_position: 9
---

# DKIM2 and Rspamd Policy Integration

This integration lets Rspamd narrow an otherwise applicable DKIM2 `PASS` through the Nauthilus Generic Policy API.
`dkim2d` remains the cryptographic verifier, Rspamd remains the Milter adapter, and Nauthilus Policy remains the only
decision authority for the additional reputation and contract assessment.

:::info Released adapter, separate live-daemon acceptance gate

DKIM2 `v0.1.22` publishes the aligned Rspamd adapter. It requires, validates, and correlates Nauthilus' echoed
`request_id`; its strict response contract and DMARC signal mappings are covered by the Lua suite and the neutral
Rspamd/Nauthilus/Milter Policy harness. That harness deliberately stubs `POST /v1/process`, so it does not prove that a
live `dkim2d` produces a verifier `PASS` for the deployment's DNS and message-wire path. Complete that separate
live-daemon acceptance check before enabling production enforcement.

:::

## Request Path and Ownership

```text
MTA -> Rspamd DKIM2 normal filter -> Redis claim or dkim2d POST /v1/process
    -> DKIM2_NAUTHILUS_POLICY postfilter -> Nauthilus POST /api/v1/policy/decisions
    -> Rspamd composites -> DKIM2_RETRY_FINALIZE idempotent finalizer
```

- The normal filter handles applicability, DKIM2 verification, replay state, daemon policy, and retry-cache lookup.
- The Policy postfilter runs only for an eligible complete-chain `PASS` whose daemon verdict and disposition are
  `accept` or `continue`. It may narrow that result; it cannot widen a daemon rejection or temporary failure.
- The finalizer observes the effective Rspamd action after filters, postfilters, and composites. It atomically arms a
  soft-reject retry or consumes a terminal cached result.

The registered Policy symbols are exact: `DKIM2_NAUTHILUS_POLICY` is a medium-priority, zero-score postfilter with
`nostat` and `ignore_passthrough`; `_PERMIT`, `_DENY`, and `_INDETERMINATE` are virtual zero-score children.
`DKIM2_RETRY_FINALIZE` is a zero-score idempotent symbol with `nostat` and `ignore_passthrough`.

## Generic Policy Contract

The request uses Policy API version `1`, target `dkim2/accept-message-instance`, projection
`dkim2.verifier-projection.v1`, and one fresh `request_id` per Policy attempt. The production caller is the dedicated
Policy-Basic principal `rspamd-verifier`. It is not an application subject, and the request carries no `subject`.

The transport envelope identifies version `1`, a fresh opaque `request_id`, target namespace `dkim2`, action
`accept-message-instance`, resource type `dkim2-message-instance`, and environment service/protocol `rspamd`/`milter`.
Production requests disable diagnostics.

Wire values use the Generic Policy one-of wrappers directly: for example,
`{"string":"dkim2.verifier-projection.v1"}` for `dkim2.projection_schema`,
`{"string":"203.0.113.25"}` for `rspamd.smtp_client_ip`, and `{"records":[...]}` for `dkim2.chain`. There is no
`ip` Policy value kind and no `kind`/`value` JSON envelope. The chain must contain at least one complete record; an empty
or abbreviated record list is invalid.

The canonical tracked example `server/docs/policy-layer/dkim2_rspamd_policy_request_v1.example.json` in the Nauthilus
source tree contains a complete runnable bounded projection. Rspamd transports
verifier-owned `resource.dkim2.*` facts and supplies its own privacy-minimized `environment.rspamd.*` observations.
The current SMTP peer is current-hop context, never historical-hop IP evidence. Raw message content, addresses,
credentials, selectors, keys, signatures, and Recipe payloads are excluded.

The chain is an ordered record list of at most 128 hops. It binds sequence, Message-Instance, signer domain, algorithms,
custody transition, authenticated flags, Recipe digest and change classes, affected header names, history state, body
availability, and projection/hop digests. Lists are sorted byte-lexically and unique; digest values are exactly 32
decoded bytes. Missing, duplicate, out-of-order, unknown, incoherent, oversized, or wrongly typed data fails closed.

The released mapping includes `dmarc.temperror` from `DMARC_DNSFAIL` and `dmarc.permerror` from `DMARC_BAD_POLICY`, in
addition to the existing pass/fail signals. Policies must still use only the documented closed normalized vocabulary;
arbitrary Rspamd symbol names and options are not forwarded.

## Native Reputation Provider

Nauthilus uses the existing generic `DecisionFactProvider` API; there is no DKIM2-specific handler or core decision
type. The source-level provider is `dkim2/plugin.dkim2_reputation.assessment` and emits only the ordered record-list fact
`plugin.dkim2_reputation.assessed_chain`. It verifies projection coherence and derives signer reputation, current-peer
reputation, contract state, Recipe authorization, acceptability, and closed violation classes. It never emits a Policy
decision or SMTP action. See [DKIM2 reputation reference plugin](../developer/go-plugins/reference-plugins/dkim2-reputation.md).

## Retry Cache and Failure Semantics

The Redis/Valkey cache is an identity-bound, HMAC-protected retry-result cache, not a replay authority. A first soft
reject arms a bounded entry; one retry worker can claim it; busy or corrupt state fails closed; a recoverable timeout
re-arms it; a terminal action consumes it. Rotate the cache authority generation whenever verifier code/schema, local
policy, replay authority, endpoint tenant, or process capability changes.

Use a dedicated Redis authority and ACL. Protect both the process capability and retry HMAC key as files; never print
or embed them in configuration, logs, traces, metrics, or tickets. TLS and hostname validation for the Nauthilus Policy
endpoint must remain enabled.

There are currently no cache-lifecycle counters or symbols for miss, store, busy, hit, arm, consume, stale, or deadline.
Do not build an operations claim around metrics that do not exist. The adapter currently provides finalization-failure
logging; validate cache behavior with bounded scenario tests and Redis-safe evidence.

## Released Evidence and Required Operator Acceptance

DKIM2 `v0.1.22` was published from commit `f1ae33d4218e62bc9f3e673bddb421b822c17213` after its repository guardrails,
vulnerability check, Lua contract tests, independent review, and full neutral Policy E2E passed. That run observed 15
stub calls, 14 Policy calls, and 11 requests forwarded through the Policy observer while covering unsigned,
first-seen/greylist, retry/consume, duplicate, malformed, timeout, provider rejection, concurrency, Redis outage, and
unrelated-Rspamd-action scenarios.

Before production enforcement, operators must still:

1. verify the exact `v0.1.22` artifact and configuration without exposing credentials;
2. run Rspamd configuration checks and the neutral harness in the deployment candidate;
3. pass a separate live `dkim2d` end-to-end path through the real DNS TXT, signed-message wire representation, Rspamd,
   Nauthilus, and final Milter result;
4. start on a non-production listener and prove timeout, retry-cache, denial, and unrelated-action behavior.

The release's bounded live-daemon attempt reached healthy `dkim2d` and Rspamd processes but ended with `451 Temporary
DKIM2 verification failure` before Nauthilus. Content-free diagnostics could not distinguish DNS TXT acceptance from
synthetic signature wire fidelity, so that attempt is not passing verifier evidence and must not waive step 3.
