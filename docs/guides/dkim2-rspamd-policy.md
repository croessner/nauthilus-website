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

:::danger Integration currently blocked

Do not enable this path for production enforcement yet. The currently committed Rspamd response validator omits the required
`request_id` response key while Nauthilus correctly returns it. It therefore rejects a successful Policy response and
fails closed. The DKIM2 owner must align the adapter and tests, publish the pending DKIM2 changes, and pass a real
`dkim2d` end-to-end run before rollout. The neutral harness described below stubs `POST /v1/process` and is not full
daemon-interoperability proof.

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

The normalized-signal schema includes `dmarc.temperror` and `dmarc.permerror`, but the currently committed adapter
mapping does not emit them. Policies must not assume those two signals are observable until an aligned adapter release
and its tests are published.

## Native Reputation Provider

Nauthilus uses the existing generic `DecisionFactProvider` API; there is no DKIM2-specific handler or core decision
type. The bundled provider is `dkim2/plugin.dkim2_reputation.assessment` and emits only the ordered record-list fact
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

## Required Verification Before Rollout

1. Fix the Policy response key contract so the adapter accepts and verifies the echoed `request_id`.
2. Run the Lua contract suite and Rspamd configuration checks without exposing credentials.
3. Run the neutral Milter harness for unsigned, first-seen/greylist, retry/consume, duplicate, malformed, timeout,
   provider rejection, concurrency, Redis outage, and unrelated-Rspamd-action cases.
4. Run a separate real `dkim2d` end-to-end path. The neutral harness uses ephemeral Rspamd, Redis/Valkey, Nauthilus, and
   a Python `/v1/process` stub; it proves adapter, cache, TLS, generic Policy, and native-provider behavior, not real
   daemon interoperability.
5. Confirm the DKIM2 owner has published the pending source commits, then deploy first on a non-production listener.

Until all five gates pass, keep the integration disabled and treat this page as a contract and review aid.
