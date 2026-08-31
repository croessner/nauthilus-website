---
title: DKIM2 Reputation Plugin
description: Reference for the bundled generic Policy provider that assesses a verified DKIM2 chain
keywords: [Go plugin, DKIM2, reputation, DecisionFactProvider, Policy]
sidebar_position: 5
---

# DKIM2 Reputation Plugin

The source tree's `dkim2-reputation` native plugin is a deterministic generic Policy fact provider for the exact target
`dkim2/accept-message-instance`. It is not part of the default bundled-plugin image list; build and verify it against
the exact host source and toolchain before installation.

| Contract | Value |
| --- | --- |
| Canonical provider | `dkim2/plugin.dkim2_reputation.assessment` |
| Extension point | `DecisionFactProvider` |
| Output | `plugin.dkim2_reputation.assessed_chain` |
| Request-time I/O | None |

It does not register an HTTP handler, a DKIM2-specific core type, a legacy environment source, or a decision callback.
Rspamd submits caller-owned facts through the Generic Policy API. The provider validates and enriches those facts;
Policy alone selects the final decision.

## Configuration

```yaml
plugins:
  modules:
    - name: dkim2_reputation
      type: go
      path: /usr/lib/nauthilus/plugins/dkim2-reputation.so
      checksum: sha256:replace-with-artifact-sha256
      optional: false
      config:
        domains:
          - domain: origin.example
            reputation: neutral
          - domain: relay.example
            reputation: trusted
        client_networks:
          - cidr: 203.0.113.0/24
            reputation: trusted
        contracts:
          - signer_domain: origin.example
            allowed_client_cidrs: [192.0.2.0/24]
            permitted_change_classes: []
          - signer_domain: relay.example
            allowed_client_cidrs: [203.0.113.0/24]
            permitted_change_classes: [body.rewrite, header.rewrite]
```

Configuration is a static operator-owned snapshot. Domains and CIDRs must be canonical. Reputation is the closed set
`trusted`, `neutral`, or `blocked`; unknown inputs stay `unknown`. Longest-prefix matching resolves overlapping client
networks. Change classes are a sorted unique subset of `body.rewrite` and `header.rewrite`.

## Validation and Output

The provider requires a complete `dkim2.verifier-projection.v1` chain. It validates closed record shapes, canonical
domains and peer addresses, contiguous sequence, target and count coherence, sorted collections, Recipe coherence, and
producer-compatible projection and bound-hop SHA-256 frames. Any contract violation returns generic `invalid_input`.

Each output record contains exactly `sequence`, `message_instance`, `hop_binding`, `signer_reputation`,
`smtp_peer_reputation`, `contract_state`, `recipe_authorization`, `assessment_complete`, `acceptable`, and
`violation_classes`. Output order and bindings correlate one-to-one with the admitted chain.

`acceptable` is a fail-closed assessment fact, not a decision. Unknown signers or peers, missing contracts, blocked
reputation, unauthorized Recipe changes, incomplete history, or upstream non-permittable state make it false. A terminal
`nd=` state emits `terminal_oob_required`; this plugin cannot establish out-of-band authority.

The SMTP peer is the current Rspamd connection. It is applied only to the target-hop contract even though its
request-wide classification is repeated in output records. Historical hops are never evaluated against the current IP.

Use this provider with the [DKIM2/Rspamd integration contract](../../../guides/dkim2-rspamd-policy.md). That integration
uses the aligned adapter published in DKIM2 `v0.1.22`. Its neutral Policy harness is passing, but it stubs the live
`dkim2d` process endpoint; operators must still prove a real verifier `PASS` through their DNS and message-wire path
before enabling production enforcement.
