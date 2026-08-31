---
title: GeoIP and ASN Plugin
description: Complete configuration, lifecycle, policy, runtime, and operations reference for the bundled GeoIP plugin
keywords: [GeoIP, ASN, MaxMind, Decision Fact Provider, plugin.geoip]
sidebar_position: 2
---

# GeoIP and ASN Plugin

The bundled `geoip` plugin registers one target-aware generic `DecisionFactProvider`. It requires a local primary GeoIP database and can add ASN organization, routing-prefix, registry allocation, and network-privacy evidence from optional sources. Top-level Policy binds its canonical ID `authn/plugin.geoip.environment` and qualifies its outputs under `plugin.geoip.*`. The plugin does not register an authentication-shaped `EnvironmentSource` or a second request-time adapter.

The container artifact is:

```text
/usr/local/lib/nauthilus/plugins/geoip.so
```

## Public contract

| Item | Value |
| --- | --- |
| Metadata name | `geoip` |
| Product version | `0.1.0` |
| Interfaces | `Plugin`, `RuntimePlugin`, `ReloadablePlugin` |
| Registered lifecycle component | `InitTask` named `database` |
| Registered request component | `DecisionFactProvider` named `geoip.environment` |
| Canonical Policy provider | `authn/plugin.geoip.environment` |
| Source timeout | current `lookup_timeout`, default `50ms` |
| Abort policy | `none` |
| Sensitive capabilities | none |
| Local debug modules | none; use the automatic `plugin.<module>` selector |

The configured module name participates in Policy binding. The reviewed example configures the module as `geoip`; a differently named module must use a matching provider declaration and exact descriptor ownership.

## Strict configuration schema

Configuration is decoded strictly. Unknown keys, wrong types, relative database paths, unsupported format strings, invalid URLs, and invalid durations reject registration or reload.

### Database and lookup fields

| Field | Type | Default | Validation and meaning |
| --- | --- | --- | --- |
| `database_path` | string | required | Cleaned absolute path to the required primary JSON or MaxMind database. File opening happens during the init task. |
| `database_format` | string | `auto` | Exactly `auto`, `json`, or `mmdb`. `auto` selects `mmdb` for a `.mmdb` suffix and `json` otherwise. Values are case-sensitive. |
| `asn_database_path` | string | empty | Optional cleaned absolute path to a secondary JSON or MaxMind ASN database. |
| `asn_database_format` | string | inferred | Exactly `auto`, `json`, or `mmdb`. Setting it without `asn_database_path` is invalid. |
| `refresh_interval` | duration string | disabled (`0`) | Non-negative interval for periodically reopening the local primary and optional ASN databases. Empty or `0s` disables this worker. |
| `lookup_timeout` | duration string | `50ms` | Must be positive. Bounds each request-time primary and ASN lookup sequence. |

### `asn_lookup`

This optional worker downloads routing prefix-to-AS snapshots and builds an in-memory IPv4/IPv6 longest-prefix trie.

| Field | Type | Default | Validation and meaning |
| --- | --- | --- | --- |
| `asn_lookup.enabled` | boolean | `false` | Enables immediate and periodic routing snapshot fetches. |
| `asn_lookup.refresh_interval` | duration string | `720h` | Non-negative. Empty and explicit `0s` both select `720h`; disable with `enabled: false`. |
| `asn_lookup.timeout` | duration string | `30s` | Must be positive; applied independently to each configured source fetch. |
| `asn_lookup.source_urls` | list of strings | CAIDA IPv4 and IPv6 creation logs when enabled | Every entry must be a nonempty HTTP(S) URL, even when the worker is disabled. |

Default routing sources:

```text
https://publicdata.caida.org/datasets/routing/routeviews-prefix2as/pfx2as-creation.log
https://publicdata.caida.org/datasets/routing/routeviews6-prefix2as/pfx2as-creation.log
```

The parser accepts direct text or gzip-compressed prefix data and CAIDA creation logs. For a creation log it fetches the last valid listed snapshot path. Plain CIDR rows, CAIDA address/prefix-length rows, `AS` prefixes, AS sets, and MOAS tokens are accepted; for a set or MOAS value, the first numeric ASN is used.

### `asn_registry`

This optional worker downloads delegated RIR statistics and maps active ASN ranges to registry metadata.

| Field | Type | Default | Validation and meaning |
| --- | --- | --- | --- |
| `asn_registry.enabled` | boolean | `false` | Enables immediate and periodic registry feed fetches. |
| `asn_registry.refresh_interval` | duration string | `720h` | Non-negative. Empty and explicit `0s` both select `720h`; disable with `enabled: false`. |
| `asn_registry.timeout` | duration string | `30s` | Must be positive; applied independently to each feed. |
| `asn_registry.source_urls` | list of strings | five worldwide RIR feeds when enabled | Every entry must be a nonempty HTTP(S) URL. |

Default feeds cover AfriNIC, APNIC, ARIN, LACNIC, and RIPE NCC. Only `asn` rows whose status is `allocated` or `assigned` are retained.

### `privacy_intelligence`

This optional subsystem classifies addresses from immutable in-memory snapshots. It performs no file or network I/O on the request path and never makes the authentication decision itself.

| Field | Type | Default | Validation and meaning |
| --- | --- | --- | --- |
| `privacy_intelligence.enabled` | boolean | `false` | Requires at least one source or enabled hosting rules when set. |
| `privacy_intelligence.lookup_timeout` | duration string | `10ms` | Must be positive and no greater than the parent `lookup_timeout`. |
| `privacy_intelligence.max_snapshot_entries` | integer | `1000000` | Positive per-source input and expanded-entry bound. |
| `privacy_intelligence.max_download_bytes` | integer | `33554432` | Positive bound for one remote response, local source, or persistent-cache read. |
| `privacy_intelligence.public_log_fields` | boolean | `false` | Enables the bounded privacy fields described under [Runtime exchange and public logs](#runtime-exchange-and-public-logs). |
| `privacy_intelligence.refresh.cache_dir` | string | empty | Optional absolute directory for derived remote cache paths. |
| `privacy_intelligence.refresh.max_concurrent_downloads` | integer | `2` | Shared download limit; must be from `1` through `8`. |
| `privacy_intelligence.refresh.startup_jitter` | duration string | `30s` | Non-negative delay available before a background refresh when a cache or optional source permits deferral. |
| `privacy_intelligence.refresh.default_refresh_interval` | duration string | `6h` | Positive default for non-Tor sources. |
| `privacy_intelligence.refresh.default_min_refresh_interval` | duration string | `1h` | Positive lower bound for non-Tor source refresh. |
| `privacy_intelligence.refresh.default_max_refresh_backoff` | duration string | `24h` | Positive failure-backoff ceiling. |

Each `sources` entry has this common contract:

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Unique 1-63 character identifier containing lowercase letters, digits, and non-leading underscores. |
| `kind` | yes | `tor_exit_list`, `normalized_json`, `cidr_list`, or `cidr_csv`. |
| `authority` | yes | `official`, `operator`, `community`, or `derived`; Tor requires `official`. |
| `path` / `url` | exactly one | An absolute local path or credential-free HTTPS URL. Privacy URLs are stricter than the HTTP(S) URLs accepted by the ASN workers. |
| `required` | no | Makes initialization/reload fail when no valid initial snapshot can be obtained. After startup, a missing or expired required snapshot produces stale state. |
| `refresh_interval` | no | Positive interval, default `6h`; Tor defaults to `1h`. It must not be below `min_refresh_interval`. |
| `min_refresh_interval` | no | Positive lower bound, default `1h`; Tor has a hard minimum and default of `30m`. |
| `max_refresh_backoff` | no | Positive ceiling, default `24h`, and at least `refresh_interval`. |
| `refresh_jitter` | no | Non-negative and smaller than `refresh_interval`; defaults to the smaller of 10% of the interval or 10 minutes. |
| `max_age` | no | Positive freshness window, default `24h`. |
| `cache_path` | no | Absolute path available only to remote sources; otherwise derived from `refresh.cache_dir`. |
| `confidence` | no | Evidence confidence. Community values are capped at 80 and derived values at 60; official and operator values default to 100. This is evidence confidence, not authentication risk. |
| `license`, `license_url` | community | Both are mandatory for community sources; normalized community JSON must also carry license metadata. |

`cidr_list` and `cidr_csv` additionally require a bounded `provider` identifier and a nonempty `classes` list. CSV uses zero-based `cidr_column` in the range 0-63 and optional `has_header`; those CSV fields are rejected for line lists. Both formats accept only public unicast prefixes, reject the entire candidate on malformed input, deduplicate coverage, and losslessly collapse adjacent or contained prefixes before expanding classes. Supported classes are:

- `tor_exit`
- `known_vpn_exit`
- `community_vpn_exit`
- `public_proxy`
- `privacy_relay`
- `shared_egress`
- `hosting`

`shared_egress` is for operator-reviewed public NAT egress prefixes. The plugin intentionally does not infer it from an entire carrier ASN or organization name. `hosting` remains separate from VPN evidence and by itself does not set `privacy_detected`.

#### Source formats

- `tor_exit_list` accepts complete bare-address lists, TorDNSEL or CollecTor 1.0 exit records, and bounded Onionoo details JSON. Onionoo entries must describe running relays with the `Exit` flag. The plugin never sends the current client address to Tor.
- `normalized_json` is a strict versioned schema with `schema_version: 1`, source identity, authority, generation and optional validity timestamps, and per-prefix classes/provider/confidence. Unknown JSON fields, invalid metadata, invalid or non-public prefixes, and entries beyond the configured bounds reject the candidate atomically.
- `cidr_list` accepts one public prefix per line with blank lines and `#` comments.
- `cidr_csv` accepts RFC 4180 records and extracts the configured prefix column.

No third-party list is bundled. Operators remain responsible for feed licenses, attribution, automation terms, redistribution limits, and egress allowlists. The implementation does not require MaxMind Anonymous IP or another commercial privacy database.

#### Hosting rules and overrides

`privacy_intelligence.hosting` can derive `hosting` evidence from configured CIDRs, positive ASNs, and case-insensitive organization substrings. Organization matching is disabled unless patterns are explicitly configured, and the derived confidence ceiling is 60.

`privacy_intelligence.overrides` accepts an address prefix plus `add_classes` and/or `suppress_classes`, an optional reason, and an optional RFC 3339 expiry. Suppression normally removes only non-official evidence; `suppress_official: true` is required to suppress an official classification. Added evidence has operator authority and confidence 100.

## Primary JSON format

JSON is primarily a license-free test and development format:

```json
{
  "records": [
    {
      "cidr": "203.0.113.0/24",
      "country_iso": "DE",
      "country_name": "Germany",
      "city_name": "Berlin",
      "asn": 64500,
      "asn_org": "Example Access GmbH"
    }
  ]
}
```

`records` must contain at least one entry and every `cidr` must parse. Overlapping prefixes are allowed; the most specific match wins. Country codes, names, ASN values, and organizations are not otherwise normalized or semantically validated.

For production, use an appropriately licensed MaxMind City or Country database as the primary database. An optional MaxMind ASN database can supply the ASN and autonomous-system organization without replacing primary location data.

MaxMind files are read completely and opened from process-owned byte slices rather than mmap. Budget roughly the combined primary and ASN file sizes per Nauthilus process, plus temporary overlap while a reload validates and publishes replacement readers. In-flight lookups hold short leases on the retired readers until they finish.

## Enrichment precedence

The primary database is authoritative for whether the request matched at all. Optional ASN sources cannot create an ASN-only result for an address that the primary database did not match.

For a primary match, enrichment occurs in this order:

1. The primary database supplies location and any embedded ASN data.
2. The routing snapshot, when available, replaces ASN, routed prefix, ASN country, and registry with its longest-prefix record.
3. The secondary ASN database may fill a missing ASN, organization, or prefix. Conflicting nonzero ASNs are not merged.
4. The RIR registry snapshot replaces registry, ASN country, and status for the final ASN, and fills the allocation date when it is still empty.

This precedence matters when the sources have different update times.

## Lifecycle and reload

```mermaid
sequenceDiagram
    participant Loader
    participant Plugin
    participant Init as database InitTask
    participant Workers
    participant Requests

    Loader->>Plugin: Register(strict config)
    Loader->>Plugin: Start(host)
    Loader->>Init: Start(config)
    Init->>Init: Open primary and optional ASN DB
    Init->>Plugin: Atomically publish readers
    Plugin->>Workers: Start configured refresh workers
    Init-->>Requests: Runtime becomes ready
```

- A missing, unreadable, empty, malformed, or unsupported primary database makes the init task fail. A required module therefore prevents runtime readiness.
- Privacy initialization validates local sources, restores and revalidates configured caches, and performs an immediate remote fetch when necessary. A required privacy source without a valid cache or successful initial fetch makes initialization or reload fail; an unavailable optional source does not.
- `refresh_interval` waits for its first tick before reopening local databases. A failed refresh logs an error and keeps the previous readers.
- ASN routing and registry workers fetch immediately and then on their configured interval. A failed multi-source refresh keeps the previous snapshot.
- Each remote privacy source has a supervised worker. Refreshes are coalesced per source and share the configured download semaphore. A candidate is parsed and validated completely before the combined immutable lookup index is rebuilt and atomically published.
- Privacy refresh failures log only the validated source ID, retain the last-known-good snapshot, and advance a bounded exponential backoff. `Retry-After`, `Cache-Control: max-age`, `Expires`, validators, and configured jitter can raise the next-attempt time.
- Sources are fetched sequentially. With five RIR feeds and a `30s` per-source timeout, one failed pass can take substantially longer than 30 seconds.
- `Reconfigure` decodes the new config and opens all referenced local databases before swapping state. A failure keeps the previous config and readers.
- A changed privacy config is also loaded before publication; an unchanged privacy engine is reused. A successful reconfigure restarts optional workers. Routing state is reset and may be temporarily absent until the new immediate fetch succeeds; existing registry data is retained while registry refresh remains enabled.
- `Stop` cancels workers and closes active MaxMind readers.

Remote privacy caches are written with mode `0600` through a temporary file and atomic rename; their directories are created with mode `0700`. Cache metadata, authority, kind, source ID, entry count, public prefixes, classes, and confidence are revalidated before publication. An expired valid cache remains available as explicitly stale evidence while refresh is retried.

## Host services

The plugin uses:

| Host service | Scope and purpose |
| --- | --- |
| `Logger("geoip")` | lifecycle, refresh, record-count, and bounded error logs |
| `Tracer("geoip")` | child spans for request-time evaluation |
| `Metrics("geoip")` | plugin-owned counters, histogram, and gauge |
| `HTTP("privacy")` | bounded conditional requests for remote privacy sources |
| `ServiceContext()` | lifetime parent for refresh workers |
| `Go(...)` | host-supervised database, routing, registry, and privacy workers |

The privacy downloader uses the host HTTP facade. The older routing and registry downloaders use their own `net/http` clients, defaulting to `http.DefaultClient`. Those ASN downloads do **not** use `Host.HTTP`, and they do not register `Host.ConnectionTargets`; consequently, they do not receive host HTTP facade diagnostics or connection-target accounting.

## Fact contract

All outputs are declared by the generic provider as environment facts for the exact `authn/authenticate` and `authn/lookup_identity` targets.

| Fact | Type | Emission |
| --- | --- | --- |
| `plugin.geoip.matched` | boolean | Always: `true` for a primary match, otherwise `false`. |
| `plugin.geoip.country_iso` | string | When nonempty. |
| `plugin.geoip.country_name` | string | When nonempty. |
| `plugin.geoip.city_name` | string | When nonempty. |
| `plugin.geoip.asn` | number | When greater than zero. |
| `plugin.geoip.asn_org` | string | When nonempty. |
| `plugin.geoip.asn_prefix` | string | When nonempty. |
| `plugin.geoip.asn_registry` | string | When nonempty. |
| `plugin.geoip.asn_country_iso` | string | When nonempty. |
| `plugin.geoip.asn_allocated` | string | When nonempty. |
| `plugin.geoip.asn_status` | string | When nonempty. |
| `plugin.geoip.privacy_lookup_state` | string | Whenever privacy intelligence is enabled: `evaluated`, `stale`, `unavailable`, `no_sources`, or `invalid_ip`. |
| `plugin.geoip.privacy_data_stale` | boolean | Whenever privacy intelligence is enabled. |
| `plugin.geoip.privacy_detected` | boolean | In `evaluated` or `stale` state. Hosting-only evidence remains `false`. |
| `plugin.geoip.privacy_classes` | string list | In `evaluated` or `stale` state, including an explicit empty list. |
| `plugin.geoip.privacy_primary_class` | string | When retained evidence selects a primary class. |
| `plugin.geoip.privacy_confidence` | number | With a primary class. |
| `plugin.geoip.privacy_source_authorities` | string list | When retained evidence has contributing authorities. |
| `plugin.geoip.privacy_data_age_seconds` | number | With contributing authorities; age of the oldest retained evidence. |
| `plugin.geoip.is_tor_exit_node` | boolean | Explicit true or false in `evaluated` or `stale` state. |
| `plugin.geoip.is_known_vpn_exit` | boolean | Explicit true or false in `evaluated` or `stale` state. |
| `plugin.geoip.is_community_vpn_exit` | boolean | Explicit true or false in `evaluated` or `stale` state. |
| `plugin.geoip.is_public_proxy` | boolean | Explicit true or false in `evaluated` or `stale` state. |
| `plugin.geoip.is_privacy_relay` | boolean | Explicit true or false in `evaluated` or `stale` state. |
| `plugin.geoip.is_hosting_network` | boolean | Explicit true or false in `evaluated` or `stale` state. |
| `plugin.geoip.is_shared_egress` | boolean | Explicit true or false in `evaluated` or `stale` state. |

An invalid client IP is treated as a nonmatching result rather than a plugin error. When privacy intelligence is enabled, it also emits `privacy_lookup_state: invalid_ip` and omits classification booleans. A database lookup or privacy deadline error is returned to the host.

Privacy state is deliberately tri-state rather than a simple boolean:

- `evaluated` means valid snapshots were evaluated, so explicit false classification facts are meaningful.
- `stale` means evidence was evaluated but a contributing or required source exceeded `max_age` or is missing.
- `unavailable`, `no_sources`, and `invalid_ip` omit classification booleans so absence cannot be mistaken for a verified negative.

The plugin does not deny a request merely because data is stale or unavailable. For fail-closed enforcement, make a source `required` to reject startup without any valid initial snapshot and write policy that requires `privacy_lookup_state: evaluated` and `privacy_data_stale: false` before trusting negative classifications.

## Generic provider boundary

The provider accepts only the admitted `input.auth.client_ip` fact. It receives no credential, raw transport, response, or scheduling authority. Its result contains the declared `plugin.geoip.*` facts and a safe error class only; request logging and Policy diagnostics remain host-owned.

There is no registered `plugin.exchange.geoip` execution path and no runtime alias for the removed `plugin.environment.geoip.*` fact family. Analytics consumers project the already collected `plugin.geoip.*` facts into their typed views instead of invoking a second GeoIP adapter.

## Metrics, spans, and debug

The plugin names below are `pluginapi.MetricDefinition.Name` values, not the final Prometheus collector names. The host exports native plugin metrics as `nauthilus_plugin_<scope>_<definition_name>` and prepends the host-owned `plugin_scope` label. This plugin calls `Host.Metrics("geoip")`, so both the collector-name scope and `plugin_scope` value are `geoip` even when the configured module name differs.

| Plugin definition name | Exported Prometheus family | Labels | Meaning |
| --- | --- | --- | --- |
| `geoip_lookup_total` | `nauthilus_plugin_geoip_geoip_lookup_total` | `plugin_scope="geoip"`, `result=matched|miss|invalid_ip|error` | Generic provider lookup attempts. |
| `geoip_lookup_seconds` | `nauthilus_plugin_geoip_geoip_lookup_seconds` | `plugin_scope="geoip"`, same result label | Lookup latency when a positive duration was recorded. The histogram exposes the usual `_bucket`, `_sum`, and `_count` series. |
| `geoip_database_records` | `nauthilus_plugin_geoip_geoip_database_records` | `plugin_scope="geoip"`, `state=loaded` | Combined primary and optional ASN database record indicator. |
| `geoip_privacy_source_refresh_total` | `nauthilus_plugin_geoip_geoip_privacy_source_refresh_total` | `plugin_scope="geoip"`, `source=<configured ID>`, `result=success|error` | Background privacy refresh attempts. |
| `geoip_privacy_snapshot_entries` | `nauthilus_plugin_geoip_geoip_privacy_snapshot_entries` | `plugin_scope="geoip"` | Total entries in currently published privacy snapshots. |

For example, a matched-lookup series is selected as:

```text
nauthilus_plugin_geoip_geoip_lookup_total{plugin_scope="geoip",result="matched"}
```

Request tracing uses separate span names and attributes:

| Span | Attributes | Meaning |
| --- | --- | --- |
| `geoip.environment.evaluate` | `plugin.module`, `plugin.component`; on match `geoip.matched`, `geoip.country_iso` | Request-time child span. |
| `geoip.database.primary.lookup` | `geoip.lookup.result=matched|miss|error` | Primary database child lookup. |
| `geoip.asn.routing.lookup` | same | Routing-prefix child lookup when configured. |
| `geoip.database.asn.lookup` | same | Secondary ASN database child lookup when configured. |
| `geoip.asn.registry.lookup` | same | Registry child lookup when configured. |
| `geoip.privacy.lookup` | same; parent adds privacy state/class/staleness | In-memory privacy lookup when enabled. |

For MaxMind data, the records gauge uses the search-tree node count, not a count of business records. Routing prefix and RIR range counts are logged when their snapshots load, but are not included in this gauge. Privacy refresh error logs expose only the validated source ID, not the URL or transport details.

GeoIP declares no local debug submodule. Enable the configured module selector:

```yaml
observability:
  log:
    level: debug
    debug_modules:
      - plugin.geoip
```

## Build and tests

From the exact Nauthilus host checkout:

```shell
GOEXPERIMENT=runtimesecret \
GOCACHE=/tmp/nauthilus-go-cache \
go test ./contrib/plugins/geoip

mkdir -p build
CGO_ENABLED=1 \
GOEXPERIMENT=runtimesecret \
go build \
  -mod=vendor \
  -tags="netgo" \
  -trimpath \
  -buildmode=plugin \
  -o build/geoip.so \
  ./contrib/plugins/geoip
```

The package test includes a subprocess smoke test that builds the `.so`, opens it through Go's `plugin` package, resolves `NauthilusPlugin`, and checks the API version. Loading in a helper process avoids comparing a plugin against the test binary's different package hashes.

## Realistic configuration and policy

```yaml
plugins:
  verification_policy: signature_required
  allowed_dirs:
    - /usr/local/lib/nauthilus/plugins
  trust:
    signers:
      - id: nauthilus-plugin-build-key-2026
        format: minisign
        public_key_file: /usr/share/nauthilus/plugin-keys/build-2026.pub
  modules:
    - name: geoip
      type: go
      path: /usr/local/lib/nauthilus/plugins/geoip.so
      signature: minisign:/usr/local/lib/nauthilus/plugins/geoip.so.minisig
      signer: nauthilus-plugin-build-key-2026
      optional: false
      config:
        database_path: /var/lib/GeoIP/GeoLite2-City.mmdb
        database_format: mmdb
        asn_database_path: /var/lib/GeoIP/GeoLite2-ASN.mmdb
        asn_database_format: mmdb
        refresh_interval: 1h
        lookup_timeout: 50ms
        asn_lookup:
          enabled: true
          refresh_interval: 720h
          timeout: 30s
        asn_registry:
          enabled: true
          refresh_interval: 720h
          timeout: 30s
        privacy_intelligence:
          enabled: true
          lookup_timeout: 10ms
          max_snapshot_entries: 1000000
          max_download_bytes: 33554432
          public_log_fields: true
          refresh:
            cache_dir: /var/lib/nauthilus/privacy/cache
            max_concurrent_downloads: 2
            startup_jitter: 30s
            default_refresh_interval: 6h
            default_min_refresh_interval: 1h
            default_max_refresh_backoff: 24h
          sources:
            - id: tor_exit
              kind: tor_exit_list
              authority: official
              url: https://onionoo.torproject.org/details?type=relay&running=true&flag=Exit&fields=exit_addresses%2Crunning%2Cflags
              refresh_interval: 1h
              min_refresh_interval: 30m
              max_refresh_backoff: 12h
              refresh_jitter: 5m
              max_age: 6h
              required: true
            - id: apple_private_relay
              kind: cidr_csv
              authority: official
              url: https://mask-api.icloud.com/egress-ip-ranges.csv
              provider: apple_private_relay
              classes:
                - privacy_relay
                - shared_egress
              cidr_column: 0
              has_header: false
              confidence: 100
              max_age: 24h
            - id: x4b_vpn
              kind: cidr_list
              authority: community
              url: https://raw.githubusercontent.com/X4BNet/lists_vpn/main/output/vpn/ipv4.txt
              provider: x4bnet
              classes:
                - community_vpn_exit
              license: MIT
              license_url: https://github.com/X4BNet/lists_vpn#license
              confidence: 55
              max_age: 24h

policy:
  namespaces:
    authn:
      condition_sets:
        strings:
          allowed_country_iso:
            - DE
            - AT
            - CH
      providers:
        environment:
          kind: native
          module: geoip
          targets:
            - action: authenticate
            - action: lookup_identity
          produced_facts:
            - plugin.geoip.matched
            - plugin.geoip.country_iso
            - plugin.geoip.country_name
            - plugin.geoip.city_name
            - plugin.geoip.asn
            - plugin.geoip.asn_org
            - plugin.geoip.asn_prefix
            - plugin.geoip.asn_registry
            - plugin.geoip.asn_country_iso
            - plugin.geoip.asn_allocated
            - plugin.geoip.asn_status
            - plugin.geoip.privacy_lookup_state
            - plugin.geoip.privacy_detected
            - plugin.geoip.privacy_classes
            - plugin.geoip.privacy_primary_class
            - plugin.geoip.privacy_confidence
            - plugin.geoip.privacy_source_authorities
            - plugin.geoip.privacy_data_stale
            - plugin.geoip.privacy_data_age_seconds
            - plugin.geoip.is_tor_exit_node
            - plugin.geoip.is_known_vpn_exit
            - plugin.geoip.is_community_vpn_exit
            - plugin.geoip.is_public_proxy
            - plugin.geoip.is_privacy_relay
            - plugin.geoip.is_hosting_network
            - plugin.geoip.is_shared_egress
          failure: indeterminate
          timeout: 50ms
      domain_plans:
        geoip:
          checkpoints:
            pre_auth:
              providers:
                - name: brute_force
                  use: authn/builtin/brute_force
                  actions: [authenticate]
                - name: plugin_environment_geoip
                  use: authn/plugin.geoip.environment
                  actions: [authenticate, lookup_identity]
            auth_backend:
              providers:
                # Replace this binding when authentication uses another backend.
                - name: ldap_backend
                  use: authn/builtin/ldap_backend
                  actions: [authenticate, lookup_identity]
            auth_decision:
              providers: []
      policy_sets:
        geoip:
          visibility: private
          rules:
            - name: deny_current_tor_password_auth
              checkpoint: pre_auth
              actions: [authenticate]
              require_providers: [plugin_environment_geoip]
              if:
                all:
                  - attribute: plugin.geoip.is_tor_exit_node
                    is: true
                  - attribute: plugin.geoip.privacy_data_stale
                    is: false
              then:
                decision: deny
                response_marker: auth.response.fail
            - name: deny_unexpected_country
              checkpoint: pre_auth
              actions: [authenticate]
              require_providers: [plugin_environment_geoip]
              if:
                all:
                  - attribute: plugin.geoip.matched
                    is: true
                  - attribute: plugin.geoip.country_iso
                    not_in: "@string.allowed_country_iso"
                  - attribute: plugin.geoip.asn_registry
                    not_in:
                      - ripencc
                      - arin
              then:
                decision: deny
                response_marker: auth.response.fail
  targets:
    - namespace: authn
      action: authenticate
      schema: authn/authenticate/v1
      domain_plan: authn/geoip
      default_policy: authn/standard_auth
      plans:
        pre_auth:
          policy_sets: [authn/geoip]
    - namespace: authn
      action: lookup_identity
      schema: authn/lookup_identity/v1
      domain_plan: authn/geoip
      default_policy: authn/standard_auth
```

The specific policy grammar must match the active Nauthilus config generation. The stable contracts supplied by this plugin are the source name and registered fact IDs.

## Security, privacy, and current limits

- The plugin handles client IP-derived location, ASN, and network-classification data. Treat its central logs, traces, snapshots, and caches according to your privacy policy.
- Use HTTPS and explicit egress allowlists for routing and RIR sources; their legacy parsers permit HTTP. Privacy source URLs must be credential-free HTTPS.
- A creation log may name an absolute follow-up URL. Configure only trusted creation-log sources.
- A routing source can consume up to 128 MiB compressed response data and 128 MiB decompressed data; two default sources plus trie construction need corresponding memory headroom.
- Each RIR response is bounded at 32 MiB and feeds are fetched sequentially.
- Routing and RIR fetches bypass `Host.HTTP` and connection-target observability. Privacy downloads use `Host.HTTP`, but the plugin still declares no static connection targets because URLs are plugin configuration.
- Privacy snapshots and caches contain IP-derived intelligence. Keep cache paths private, retain the restrictive permissions, and do not expose source/provider/license metadata through request logs.
- A negative privacy result is meaningful only in `evaluated` or `stale` state. Do not convert unavailable states into false policy claims, and decide explicitly whether stale data should fail open or fail closed.
- Generic prefix feeds are accepted only as classifications explicitly assigned by the operator; the plugin does not assess whether a list is accurate, complete, or legally usable.
- The primary local database remains mandatory even when routing lookup or privacy intelligence is enabled.
- The checked-in `geoip-test.mmdb` is intentionally not a real MaxMind database; it tests path/format handling only.
- MaxMind data has its own licensing and update requirements and is not bundled by this plugin source directory.
