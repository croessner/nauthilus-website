---
title: DKIM2 Intelligence Plugin
description: Reference for the bundled Policy fact provider that correlates a verified DKIM2 chain with reputation, GeoIP/ASN, and operator identity contracts
keywords: [Go plugin, DKIM2, reputation, GeoIP, identity contract, DecisionFactProvider, Policy]
sidebar_position: 5
---

# DKIM2 Intelligence Plugin

The `dkim2-intelligence` native plugin is a deterministic generic Policy fact provider for the exact target
`dkim2/accept-message-instance`. It combines three inputs into one correlated view:

- the admitted DKIM2 verifier projection sent by Rspamd;
- reputation assessments from the generic [reputation plugin](./reputation.md);
- current-peer GeoIP/ASN evidence from the [GeoIP plugin](./geoip.md).

It also applies the identity contracts you configure. It emits facts only. It does not verify, score, learn, authorize
Recipes, select a decision, or choose an SMTP action. DKIM2 remains responsible for parsing, cryptographic verification,
reconstruction, Recipe execution, replay handling, and sealing. Policy rules own the final result.

:::warning Replaces `dkim2-reputation`

The static `dkim2-reputation` plugin of early v4 prereleases has been removed. Its provider
`dkim2/plugin.dkim2_reputation.assessment` and fact `plugin.dkim2_reputation.assessed_chain` no longer exist. See
[Migrating from `dkim2-reputation`](#migrating-from-dkim2-reputation).

:::

| Contract | Value |
| --- | --- |
| Plugin metadata name / version | `dkim2_intelligence` / `0.1.0` |
| Features | `decision_fact_provider`, `reconfigure` |
| Canonical provider | `dkim2/plugin.dkim2_intelligence.assessment` (component `assessment`) |
| Extension point | `DecisionFactProvider` |
| Target | `dkim2/accept-message-instance` |
| Required upstream providers | the configured reputation provider (for example `dkim2/plugin.reputation.assessment`) and GeoIP provider (for example `dkim2/plugin.geoip.smtp_peer`) |
| Outputs | `plugin.dkim2_intelligence.assessed_chain`, `plugin.dkim2_intelligence.smtp_peer`, `plugin.dkim2_intelligence.assessment_complete` |
| Provider timeout (descriptor) | `1s` |
| Request-time I/O | None. The plugin has no Redis, HTTP, credential, effect, permit, or deny capability. |
| Container artifact | `/usr/local/lib/nauthilus/plugins/dkim2-intelligence.so` |

The plugin ships in the stable and debug container images together with `geoip`, `clickhouse`, `haveibeenpwnd`, and
`reputation`. For a local build, run `make build` in `contrib/plugins/dkim2-intelligence`. The Makefile embeds the native
artifact fingerprint and builds with `GOEXPERIMENT=runtimesecret`, `-mod=vendor`, `-trimpath`, and
`-buildmode=plugin`. Build the host and all plugins from the same source tree and compiler identity. The repository check
`scripts/check-native-artifact-bundle.sh` includes this module and rejects stale or unmarked artifacts.

## Provider graph

The plugin cannot run alone. The Policy namespace must schedule three native providers in this order:

```text
geoip (smtp_peer)  ->  reputation (assessment)  ->  dkim2_intelligence (assessment)
```

1. GeoIP resolves `environment.rspamd.smtp_client_ip` into `plugin.geoip.*` facts.
2. Reputation assesses every chain signer domain and three current-peer subjects: the IP, its derived network, and the
   optional ASN taken from GeoIP. It emits its target-binding output fact, for example
   `plugin.reputation.dkim2_subjects`.
3. DKIM2 intelligence correlates those results with the verifier chain and publishes its three facts.

The host activates the catalog only when the configured reputation and GeoIP components exist, their output schemas are
declared, they are scheduled first, and every record field this plugin consumes is visible to it with the expected type.
The consumed fields include `role`, `kind`, `sequence`, `message_instance`, `hop_binding`, `signer_domain`, and the
reputation tuple fields. A missing dependency, a wrong producer, a hidden field, or an incompatible type prevents
activation.

Names in the Policy `providers` map are authored aliases. The native `component` selects the exact registered component,
so the reputation and DKIM2 intelligence modules can both export a component called `assessment` without sharing
authority. If you enable an authentication target binding in the same reputation module, give that component a
different local name.

## Configuration

The Nauthilus source tree ships the module fragment `server/docs/examples/go_plugin_dkim2_intelligence.yml` and the
complete Policy `server/docs/examples/policy_dkim2_rspamd_verifier.yml`. Merge the fragment with your reputation module
configuration by module and target-binding identity. Keep the reputation model, primary Redis, opaque-key, and source
admission settings from your reputation configuration.

```yaml
plugins:
  modules:
    - name: geoip
      type: go
      path: /usr/local/lib/nauthilus/plugins/geoip.so
      config:
        database_path: /var/lib/GeoIP/GeoLite2-City.mmdb
        asn_database_path: /var/lib/GeoIP/GeoLite2-ASN.mmdb
        freshness:
          max_age: 1080h
          max_stale_age: 2160h
        decision_bindings:
          - component: smtp_peer
            input:
              category: environment
              fact: environment.rspamd.smtp_client_ip
            output_schema: geoip.facts.v1
            targets:
              - dkim2/accept-message-instance

    - name: reputation
      # path, model, Redis, key, and source settings come from your reputation configuration
      config:
        target_bindings:
          - component: assessment
            target: dkim2/accept-message-instance
            decision_profile: operational
            output_fact: dkim2_subjects
            subjects:
              - role: signer
                kind: dns_domain
                category: resource
                attribute: resource.dkim2.chain
                field: signer_domain
                correlation_fields: [sequence, message_instance, hop_binding, signer_domain]
                correlation_types:
                  sequence: integer
                  message_instance: integer
                  hop_binding: bytes
                  signer_domain: string
              - role: smtp_peer_ip
                kind: ip
                category: environment
                attribute: environment.rspamd.smtp_client_ip
              - role: smtp_peer_network
                kind: network
                category: environment
                attribute: environment.rspamd.smtp_client_ip
                derive: network_from_ip
              - role: smtp_peer_asn
                kind: asn
                category: environment
                attribute: plugin.geoip.asn
                input_kind: integer
                optional: true
                provider: dkim2/plugin.geoip.smtp_peer

    - name: dkim2_intelligence
      type: go
      path: /usr/local/lib/nauthilus/plugins/dkim2-intelligence.so
      config:
        reputation_provider: dkim2/plugin.reputation.assessment
        reputation_fact: plugin.reputation.dkim2_subjects
        geoip_provider: dkim2/plugin.geoip.smtp_peer
        decision_profile: operational
        signer_sets:
          selected-providers:
            - google.example
            - yahoo.example
        identity_contracts:
          - name: selected-providers
            signer_sets: [selected-providers]
            current_peer_cidrs: [192.0.2.0/24, 2001:db8::/32]
            current_peer_asns: [64500]
          - name: relay
            signer_domains: [relay.example]
            current_peer_cidrs: [203.0.113.0/24]
```

Add `checksum`, or `signature` and `signer`, to each module as described in
[Configure native Go plugins](../../../configuration/native-go-plugins.md). The shipped fragment sets
`identity_contracts: []`. That is valid, but no current target can then reach `matched`, so the strict reference Policy
denies every message.

### Plugin-owned keys

| Key | Required | Meaning |
| --- | --- | --- |
| `reputation_provider` | yes | Exact native provider reference in the `dkim2` namespace, for example `dkim2/plugin.reputation.assessment`. |
| `reputation_fact` | yes | Record-list fact produced by that module. It must start with `plugin.<module>.` for the module named in `reputation_provider`, and it is at most 128 bytes. |
| `geoip_provider` | yes | Exact native provider reference in the `dkim2` namespace, for example `dkim2/plugin.geoip.smtp_peer`. The plugin reads `plugin.<module>.ip`, `lookup_state`, `data_age_seconds`, `asn`, `country_iso`, `asn_org`, and `asn_prefix`. |
| `decision_profile` | yes | `fast`, `operational`, or `baseline`. It must equal the reputation target binding's `decision_profile`, because every reputation tuple with another profile fails correlation. |
| `signer_sets` | no | Map of set name to signer domains. There are at most 64 sets. Each set holds 1 to 256 unique canonical domains. Sets are validated even when no contract references them. |
| `identity_contracts` | no | List of at most 256 contracts. See below. |

Unknown keys, type mismatches, and a missing or empty configuration reject registration. Names of contracts and signer
sets are 1 to 64 characters from `a-z`, `0-9`, `_`, and `-`.

Each identity contract accepts:

| Key | Meaning |
| --- | --- |
| `name` | Required unique contract name. |
| `signer_domains` | Canonical lower-case signer domains. |
| `signer_sets` | Names of existing `signer_sets` entries whose domains are added to this contract. |
| `current_peer_cidrs` | Up to 128 unique canonical CIDRs. Host bits must be zero, the text must match the canonical form, and IPv4-mapped IPv6 is rejected. |
| `current_peer_asns` | Up to 128 unique integer ASNs from `1` to `4294967295`. |

Each contract must resolve to 1 to 256 unique domains. A domain may belong to only one contract, whether it is listed
directly or through a set.

### Reload

The plugin supports `Reconfigure`. `identity_contracts` and `signer_sets` reload on SIGHUP together as one immutable
snapshot. A change to `reputation_provider`, `reputation_fact`, `geoip_provider`, or `decision_profile` is reported as
restart-bound before the reload is committed and rejects the whole reload, because those values define the registered
input contract. Each request
uses one coherent configuration snapshot.

## Identity contract semantics

Identity contracts are the only way to bind a signer to the network it is expected to send from. No ISP, mailbox
provider, or forwarding service is trusted automatically. Without contracts, no provider allowlist is inferred.

The current SMTP peer is compared only with the **target hop**, which is the last admitted record. Historical hops never
receive CIDR or ASN evidence from the current connection.

| Situation | `identity_contract_state` | `identity_contract_strength` |
| --- | --- | --- |
| Signer domain is in no contract | `missing` | `none` |
| Historical hop, domain is in a contract | `domain_only` | `domain_only` |
| Target hop, peer IP is inside a contract CIDR | `matched` | `cidr` |
| Target hop, GeoIP ASN equals a contract ASN | `matched` | `asn` |
| Target hop, contract lists ASNs, no CIDR matched, ASN evidence unavailable | `unavailable` | `none` |
| Target hop, contract has neither CIDRs nor ASNs | `missing` | `none` |
| Target hop, anything else | `mismatch` | `none` |

A CIDR match takes priority over an ASN match. An ASN match is a weaker, separate strength. The ASN comes only from
fresh or stale GeoIP evidence for the exact current peer.

## Validation

`Collect` performs these steps, in order, before it publishes anything:

1. **Projection.** It decodes and validates the verifier projection with the shared `dkim2projection` package. This
   checks the closed record shape, canonical domains and peer address, contiguous sequences, target and count coherence,
   sorted collections, Recipe coherence, and the SHA-256 projection and hop bindings. It does not reconstruct or verify
   messages. Both scopes are accepted:
   - `current`: exactly one record. Historical content and signatures and both protection aggregates are
     `not_evaluated`, and custody is `not_present`.
   - `chain`: complete historical content and signatures, evaluated custody, and evaluated protection aggregates.
2. **Reputation.** Every reputation record must carry a valid `role`, `kind`, and closed tuple with the configured
   profile.
3. **Correlation.** The target must be the final hop. Signer assessments must match each chain record in order, with
   the same `sequence`, `message_instance`, canonical `signer_domain`, and 32-byte `hop_binding`. A missing, duplicated,
   reordered, oversized, or forged correlation fails. A missing peer tuple (`smtp_peer_ip`, `smtp_peer_network`, or
   `smtp_peer_asn`) becomes an explicit `unavailable` tuple.
4. **GeoIP.** The evidence must describe exactly the canonical current peer IP. Fresh or stale evidence needs a bounded
   age. `not_found` or `unavailable` evidence must not carry country or ASN details. An ASN prefix must contain the peer.
5. **Composition.** It builds and validates both collections against their record schemas and byte limits.

Any failure returns the generic `invalid_input` error class and no facts. The provider never emits a partial chain. If
the plugin is unconfigured, it returns `unavailable`.

## Output facts

All three facts are published together, and only after every step above has succeeded.

### `plugin.dkim2_intelligence.assessment_complete`

This boolean is `true` whenever the facts are published. It means the correlation is structurally complete, including
evidence that is explicitly missing or unavailable. It is **not** a trust or permit result.

### `plugin.dkim2_intelligence.assessed_chain`

This fact has one record per admitted verifier hop, in the same order. It has 1 to 128 records, 34 declared fields, and
at most 262144 aggregate bytes.

| Group | Fields |
| --- | --- |
| Hop identity | `sequence`, `message_instance`, `hop_binding` (32 bytes, provider-private), `is_target`, `signer_domain` |
| Verifier semantics (copied) | `signature_state` (`pass`), `custody_transition`, `do_not_modify`, `do_not_explode`, `feedback`, `feed_here`, `exploded`, `recipe_mode`, `recipe_body_mode`, `change_classes`, `affected_headers`, `change_count`, `affected_header_count`, `history_header_state`, `history_body_state`, `body_availability` |
| Signer reputation tuple | `signer_reputation_state`, `signer_reputation_profile`, `signer_reputation_band`, `signer_override`, and the optional measurements `signer_risk_score`, `signer_trust_score`, `signer_confidence`, `signer_samples`, `signer_source_diversity`, and `signer_reputation_age_seconds` |
| Identity | `identity_contract_state` (`matched`, `domain_only`, `missing`, `mismatch`, `unavailable`), `identity_contract_strength` (`cidr`, `asn`, `domain_only`, `none`) |
| Explanation | `violation_classes` |

### `plugin.dkim2_intelligence.smtp_peer`

This fact has exactly one record with 36 declared fields and at most 8192 aggregate bytes.

| Group | Fields |
| --- | --- |
| Profile | `reputation_profile` |
| IP, network, and ASN tuples | For each of `ip`, `network`, and `asn`: `<kind>_state`, `<kind>_band`, `<kind>_override`, and the optional measurements `<kind>_risk_score`, `<kind>_trust_score`, `<kind>_confidence`, `<kind>_samples`, `<kind>_source_diversity`, and `<kind>_age_seconds` |
| GeoIP | `geoip_state` (`fresh`, `stale`, `not_found`, `unavailable`). The optional `geoip_age_seconds`, `country_iso`, `asn`, `asn_org` (provider-private), and `asn_prefix` appear only for `fresh` and `stale`. |
| Target identity | `target_contract_state` (`matched`, `missing`, `mismatch`, `unavailable`), `target_contract_strength` (`cidr`, `asn`, `none`) |

The IP, network, ASN, and GeoIP states are independent. No single aggregate flag replaces them. The output never repeats
the raw peer IP.

### Reputation tuple vocabulary

Both facts use the closed tuple from the shared `reputationview` package:

- state: `fresh`, `stale`, `not_found`, `unavailable`;
- band: `unknown`, `trusted`, `positive`, `neutral`, `suspicious`, `blocked`, `unavailable`;
- override: `none`, `trusted`, `neutral`, `blocked`. An active override equals the band;
- measurements (risk, trust, and confidence in `[0,1]`, samples, source diversity `0..8`, age in seconds) appear only
  for `fresh` and `stale`;
- `unavailable` always has band `unavailable` and override `none`. `not_found` without an override has band `unknown`.

### Violation classes

`violation_classes` is a sorted, unique list of at most 14 values. It describes observed conditions. It is not a
decision.

| Class | Emitted when |
| --- | --- |
| `authentication_not_pass` | target hop, and the aggregate `authentication_state` is not `PASS` |
| `upstream_nonpermittable` | target hop, and the aggregate `disposition` is not `accept` or `continue` |
| `body_unavailable` | the hop's `body_availability` is `unavailable` |
| `history_not_matched` | the hop's header or body history state is not `matched` |
| `do_not_modify_violated` | the previous hop set `do_not_modify` and this hop has change classes |
| `do_not_explode_violated` | the previous hop set `do_not_explode` and this hop is `exploded` |
| `contract_missing` / `contract_mismatch` / `identity_unavailable` | the identity state is `missing`, `mismatch`, or `unavailable` |
| `reputation_blocked` / `reputation_unavailable` | the signer tuple, or on the target hop also any peer tuple, has band `blocked` or state `unavailable` |

The record schema also admits `body_change_forbidden`, `header_change_forbidden`, and `recipe_not_authorized`. The
current composer never emits them. Recipe authorization belongs in Policy rules, for example a deny when
`change_classes` contains `body.rewrite` for a given signer.

## Privacy

Output never contains the raw IP, subject tags, message headers or values, bodies, keys, selectors, signatures, Recipe
payloads, or Recipe digests. `hop_binding` and `asn_org` are provider-private and cannot be used in expressions. The
signature state is copied from the verifier unchanged.

## Metrics

The plugin calls `Host.Metrics("dkim2_intelligence")` and registers one counter, `composition_total`, which the host
exports as `nauthilus_plugin_dkim2_intelligence_composition_total`. Its `result` label is one of:

- `completed`
- `unavailable`
- `projection_invalid`
- `reputation_invalid`
- `correlation_invalid`
- `geoip_invalid`
- `composition_invalid`

The counter follows each `Collect` call. It never carries signer, peer, hop, or Recipe labels. `completed` means that
composition passed its checks, not that the message is acceptable. An exporter failure does not change results.

## Migrating from `dkim2-reputation`

The former plugin held a static snapshot (`domains`, `client_networks`, `contracts`) and emitted a derived
`acceptable` flag. The replacement splits that job three ways:

- The generic reputation plugin holds operator classifications as stored overrides.
- `dkim2-intelligence` holds identity contracts.
- Policy rules hold Recipe authorization and acceptance.

| Former (`dkim2-reputation`) | v4 replacement |
| --- | --- |
| Module `dkim2_reputation`, provider `dkim2/plugin.dkim2_reputation.assessment` | Modules `geoip`, `reputation`, and `dkim2_intelligence`. The provider is `dkim2/plugin.dkim2_intelligence.assessment`. |
| Fact `plugin.dkim2_reputation.assessed_chain` | `plugin.dkim2_intelligence.assessed_chain`, `.smtp_peer`, and `.assessment_complete` |
| `domains[].reputation` | A `dns_domain` override in the reputation plugin (`trusted`, `neutral`, `blocked`) |
| `client_networks[].reputation` | A `network` override plus the reputation `ip_override_networks` CIDR catalog |
| `contracts[].signer_domain` + `allowed_client_cidrs` | `identity_contracts[]` with `signer_domains` and `current_peer_cidrs` |
| `contracts[].permitted_change_classes` | Policy deny rules on `change_classes` for that signer |
| `signer_reputation`, `smtp_peer_reputation` | `signer_reputation_*` tuple, and `ip_*`, `network_*`, `asn_*` tuples |
| `contract_state` (`matched`, `missing`, `peer_mismatch`) | `identity_contract_state` and `identity_contract_strength` |
| `recipe_authorization`, `acceptable` | Removed. Express these as Policy rules. |
| `contract_peer_mismatch`, `signer_reputation_*`, `smtp_peer_reputation_*`, `terminal_oob_required` | `contract_mismatch`, `reputation_blocked`, `reputation_unavailable`. For terminal custody, use `resource.dkim2.custody_structure == terminal_nd_requires_oob`. |

The offline converter `scripts/convert-static-reputation.py` in the Nauthilus source tree automates the mapping:

```shell
python3 scripts/convert-static-reputation.py old-dkim2-reputation.json import.json \
  --creator operator-name --audit-prefix dkim2-cutover --expires-at 0
```

Its input is the old `config` block exported as JSON, without credentials. It writes a new mode-`0600` file with the
schema `reputation-static-import.v1`. It never overwrites an existing file, opens Redis, or reads credentials. The
output contains:

- `overrides`: one same-band override per old domain or network, with origin `cutover.static_dkim2_v4`, reason
  `static.classification`, and a deterministic `audit_id`. Apply them with
  `python3 contrib/client/nauthilus-admin.py reputation override import import.json`, which validates the artifact,
  converts each absolute expiry into `ttl_seconds` at request time, and skips already expired entries (see
  [Reputation operations](../../../guides/reputation-operations.md#python-admin-client)). The underlying API is
  `PUT /api/v1/custom/reputation/override` with a token carrying `nauthilus:admin`; it derives the creator from the token.
- `ip_override_networks`: the CIDR catalog for the reputation plugin, ordered from most to least specific.
- `identity_contracts`: one `static-<hash>` contract per old signer contract.
- `policy_rules`: a `static-uncontracted-signer` deny, followed by per-signer Recipe deny guards for the change classes
  that were not permitted. Place them after the invariant denies and before every permit.

The converter never creates a permit. It does not bypass freshness, identity, or integrity requirements.

## Related pages

- [DKIM2 and Rspamd Policy integration](../../../guides/dkim2-rspamd-policy.md)
- [Reputation plugin](./reputation.md)
- [GeoIP/ASN plugin](./geoip.md)
- [Generic Policy API](../../../guides/generic-policy-api.md)
