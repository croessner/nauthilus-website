---
title: Native Go Plugins
description: Configure, verify, load, observe, reload, and operate native Nauthilus Go plugins
keywords: [Go plugins, configuration, checksum, minisign, capabilities, Nauthilus]
sidebar_position: 42
---

# Native Go Plugins

The root-level `plugins` section configures trusted in-process Go `.so` modules. It controls artifact provenance and module instances; each plugin owns and validates the opaque data below its module's `config` key.

:::danger Privileged code

A native plugin runs inside the Nauthilus process. Checksum and signature verification establish artifact provenance, not isolation. Load only reviewed artifacts from operator-controlled directories.

:::

## Complete shape

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
      stop_timeout: 10s
      allow_capabilities: []
      config:
        database_path: /var/lib/GeoIP/GeoLite2-City.mmdb
        database_format: mmdb
        lookup_timeout: 50ms
```

## `plugins` fields

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `verification_policy` | string | `when_present` | Global artifact verification policy for configured modules. |
| `allowed_dirs` | list of absolute paths | none | Directories from which plugin artifacts may be loaded. At least one is required when modules are configured. |
| `trust.signers` | list | empty | Trusted detached-signature identities. |
| `modules` | list | empty | Configured module instances. |

Allowed directories and module paths are cleaned and resolved through symlinks during pre-load verification. The resolved `.so` must still be contained below a resolved allowlisted directory. A lexical path that escapes through a symlink is rejected.

## Verification policies

| Policy | Checksum behavior | Signature behavior |
| --- | --- | --- |
| `off` | ignored | ignored |
| `when_present` | verified when configured | verified when configured |
| `checksum_required` | every module must configure a valid SHA-256 checksum | a configured signature is also verified |
| `signature_required` | a configured checksum is verified | every module must configure a valid trusted detached signature |

`when_present` is the default. Use `signature_required` for bundled multi-architecture artifacts: Go plugin files differ across architectures, while a trusted signing identity can remain stable.

### Checksums

The only accepted checksum shape is:

```text
sha256:<64 hexadecimal characters>
```

Verification happens before `plugin.Open`. A mismatch prevents the module from being loaded.

### Detached signatures

Nauthilus accepts minisign- and signify-style Ed25519 detached signatures:

```yaml
plugins:
  trust:
    signers:
      - id: release-2026
        format: minisign
        public_key: |
          untrusted comment: Nauthilus plugin release key
          replace-with-public-key-payload
  modules:
    - name: customer_sql
      path: /usr/local/lib/nauthilus/plugins/customer_sql.so
      signature: minisign:/usr/local/lib/nauthilus/plugins/customer_sql.so.minisig
      signer: release-2026
```

Signer rules:

- `id` must match `[a-z0-9][a-z0-9_-]{0,127}` and be unique.
- `format` must be `minisign` or `signify`.
- configure exactly one of `public_key` and `public_key_file`;
- `public_key_file` must be absolute;
- the module's signature format must match the trusted signer format;
- `signature` uses `<format>:<absolute-path>` and requires `signer`;
- `signer` without `signature` is invalid.

The loader validates signer identity and, for minisign data, the trusted-comment signature. Keep private signing material outside configuration and image layers.

## Module fields

| Field | Type | Default | Reload behavior | Meaning |
| --- | --- | --- | --- | --- |
| `name` | string | required | restart | Unique runtime namespace for this configured instance. |
| `type` | string | `go` | restart | Module type; `go` is the only accepted value. |
| `path` | absolute `.so` path | required | restart | Artifact below `allowed_dirs`. |
| `checksum` | string | empty | restart | Optional or required SHA-256 reference, depending on policy. |
| `signature` | string | empty | restart | Detached signature reference. |
| `signer` | string | empty | restart | Trusted signer ID for `signature`. |
| `optional` | boolean | `false` | restart | Allows a module load/start failure to be recorded without making the module itself required. |
| `stop_timeout` | duration | host shutdown budget | restart | Per-module upper bound inside the outer shutdown context; negative values are invalid. |
| `allow_capabilities` | list | empty | restart | Explicit sensitive capabilities granted to this instance. |
| `hooks` | list | empty | restart | Operator-owned exact bearer-scope authorization keyed by registered local hook name. |
| `compatibility` | mapping | empty | restart | Signer-gated allowlists for exact legacy metric contracts and tracing instrumentation scopes. |
| `config` | mapping | empty | possible SIGHUP | Opaque plugin-owned configuration decoded strictly by the plugin. |

Module and component names use `[a-z0-9][a-z0-9_]{0,62}`. The module name qualifies everything the instance registers. For example, local backend `passdb` in module `customer_sql` becomes `customer_sql.passdb`.

An optional module that fails does not contribute its components. Configuration that requires one of those components, such as an ordered `plugin(module.backend)` selector or a policy check bound to the source, must still be designed for that absence; `optional` is not a promise that dependent configuration remains meaningful.

## Plugin-owned configuration

Nauthilus preserves `modules[].config` as an opaque subtree and deliberately omits its contents from shared config-dump and plugin discovery output. The plugin receives it through a read-only `ConfigView`.

The public `ConfigView.Decode` path is strict: unknown keys and type mismatches reject registration or reload. Use only keys documented by the selected plugin version. Plugin authors should decode into a small typed structure and apply explicit defaults.

Do not put long-lived secrets inline merely because the subtree is opaque. Prefer a mounted secret file or another plugin-owned external secret source. The plugin is responsible for redacting its configuration errors.

## Capabilities

Capabilities use three cooperative checks:

1. plugin metadata declares what the product may use;
2. `Register` requests what the configured instance needs;
3. `allow_capabilities` records the operator-approved subset and lets `RequireCapability` succeed.

Supported values are:

| Capability | Declared use |
| --- | --- |
| `credentials` | Request-scoped password access through `CredentialProvider`. |
| `mail` | Host-managed SMTP/LMTP sends through `Host.Mail`. |

Duplicate or unknown capability entries are invalid. Grant only what the module's active configuration needs.

Capabilities are an auditable API contract for cooperating trusted code, not a sandbox permission system. In particular, the current host mail facade is not independently withheld from code that skipped `RequireCapability(CapabilityMail)`. Artifact trust and process-level controls remain the security boundary.

```yaml
plugins:
  modules:
    - name: haveibeenpwnd
      path: /usr/local/lib/nauthilus/plugins/haveibeenpwnd.so
      allow_capabilities:
        - credentials
        - mail
      config:
        mail:
          enabled: true
```

Capability acquisition occurs during registration. Enabling a configuration branch that newly needs a capability may require a restart even though the changed key is below `config`.

## Hook authorization

Plugins declare coarse hook scope and authentication modes in
`HookDescriptor`. Operators can replace that coarse bearer-scope mapping for a
specific hook without putting authorization policy in plugin-owned `config`:

```yaml
plugins:
  modules:
    - name: customer_status
      path: /usr/local/lib/nauthilus/plugins/customer_status.so
      hooks:
        - name: health
          required_scopes:
            - nauthilus:admin
            - nauthilus:custom:health
```

`name` is the hook's registered local component name. `required_scopes` uses
any-of semantics: a bearer token needs at least one listed scope. Values are
trimmed, validated as RFC 6749 scope tokens, de-duplicated in declaration order,
and limited to 32 entries.

A non-empty list is valid only for a non-public hook whose descriptor uses
`HookAuthToken`. Plugins must leave `HookDescriptor.RequiredScopes` empty;
Nauthilus injects a detached copy from operator configuration. Duplicate hook
entries, unmatched hook names, invalid scopes, public hooks, and conflicting
authentication modes fail registration. Omitting the entry or using an empty
list preserves the descriptor's coarse scope/auth behavior.

Hook authorization changes require a process restart. Effective scopes are safe
descriptor metadata in config dump and discovery output; bearer tokens and the
plugin-owned `config` subtree remain omitted.

## Signed observability compatibility

`plugins.modules[].compatibility` is a narrow exception for a signed plugin that
must preserve exact legacy Prometheus collector contracts or OpenTelemetry
instrumentation scopes:

```yaml
plugins:
  verification_policy: signature_required
  allowed_dirs:
    - /usr/local/lib/nauthilus/plugins
  trust:
    signers:
      - id: release-2026
        format: minisign
        public_key_file: /usr/share/nauthilus/plugin-keys/release-2026.pub
  modules:
    - name: legacy_bridge
      path: /usr/local/lib/nauthilus/plugins/legacy_bridge.so
      signature: minisign:/usr/local/lib/nauthilus/plugins/legacy_bridge.so.minisig
      signer: release-2026
      compatibility:
        metrics:
          - type: histogram
            name: legacy_request_duration_seconds
            help: Legacy request duration
            labels:
              - service
            buckets:
              - 0.01
              - 0.1
              - 1
        trace_scopes:
          - nauthilus/lua/blocklist
```

This configuration is operator-owned and restart-only. It is rejected when
`verification_policy` is `off`, or when the module does not configure both a
detached signature and a trusted signer. Configuration alone does not grant the
exception: runtime access is bound only after the module registered successfully
and the loader recorded the signer that actually verified the artifact.

Each `metrics` entry is one complete exact collector contract:

| Field | Requirement |
| --- | --- |
| `type` | Required: `counter`, `gauge`, `histogram`, or `summary`. |
| `name` | Required exact Prometheus-compatible name. Names are globally unique across configured compatibility metrics. |
| `help` | Required non-empty exact help text. |
| `labels` | Optional ordered, unique Prometheus-compatible names. `plugin_scope` is reserved. |
| `buckets` | Optional only for histograms; values must be finite, positive, and strictly increasing. |

Plugin code requests an exact collector through `Host.Metrics` with
`MetricDefinition.Compatibility` set and the same type, name, help, ordered
labels, and buckets. Any drift is denied. An accepted observation is published
once to the exact collector and once to the normal namespaced native collector.
If an exact collector already exists, Nauthilus reuses it only when its complete
contract matches; otherwise the collector request fails closed.

`trace_scopes` contains exact instrumentation scope names selected through
`Host.CompatibilityTracer`. Values are trimmed, validated, and de-duplicated in
declaration order. Use them only for plugin-owned domain spans; host-managed
HTTP, LDAP, Redis, and mail operations retain ownership of their client spans.

The non-secret config dump retains compatibility configuration. Plugin discovery
returns defensive copies of `metrics` and `trace_scopes` only for a registered,
signature-verified module, together with its verified signer provenance. Failed
or unverified modules do not expose an effective compatibility grant.

## Bundled artifacts

Stable and debug Nauthilus container images build these artifacts with the same toolchain and module graph as the server:

| Artifact | Module purpose | Documentation |
| --- | --- | --- |
| `/usr/local/lib/nauthilus/plugins/geoip.so` | GeoIP/ASN pre-auth environment source | [GeoIP/ASN](../developer/go-plugins/reference-plugins/geoip.md) |
| `/usr/local/lib/nauthilus/plugins/clickhouse.so` | Batched ClickHouse post-action | [ClickHouse](../developer/go-plugins/reference-plugins/clickhouse.md) |
| `/usr/local/lib/nauthilus/plugins/haveibeenpwnd.so` | HIBP password lookup and optional mail post-action | [Have I Been Pwned](../developer/go-plugins/reference-plugins/haveibeenpwnd.md) |

Release and features/debug image builds require signed bundled plugins. Detached `.minisig` files are placed beside the `.so` files. Configure the public build key as a trusted signer; never copy the private seed into the runtime image.

## Runtime debug selection

Plugin debug output uses the normal Config v2 logging path:

```yaml
observability:
  log:
    level: debug
    debug_modules:
      - plugin
      - plugin.clickhouse
      - plugin.clickhouse.batch
      - plugin.haveibeenpwnd.lookup
      - plugin.haveibeenpwnd.mail
```

Selector behavior:

| Selector | Effect |
| --- | --- |
| `all` | Enables all built-in and plugin debug modules. |
| `plugin` | Enables all registered native plugin modules. |
| `plugin.<module>` | Enables debug logs for one configured module instance. |
| `plugin.<module>.<local>` | Enables one local debug module registered by that instance. |

The module portion is `plugins.modules[].name`, not `Metadata().Name`. `Info`, `Warn`, and `Error` records follow the normal log level and are not hidden by plugin debug selectors.

## Discovery

The loader constructs a machine-readable discovery document from safe module metadata and registered descriptors. It contains:

- module name, type, path, optional state, status, and error state;
- product metadata and build diagnostics;
- required capabilities;
- registered component kinds and source or hook descriptors;
- qualified plugin debug selectors.

Plugin-owned `config` values are omitted. The current public developer contract describes the discovery document produced by loader state; do not assume that every deployment exposes it through a standalone HTTP endpoint.

## Observability

Nauthilus records bounded module lifecycle and request-call diagnostics. Automatic request-call metrics are:

```text
plugin_calls_total{module,component,extension_point,method,result}
plugin_call_duration_seconds{module,component,extension_point,method,result}
```

Automatic spans use the `nauthilus/plugin/runtime` instrumentation scope and the same low-cardinality identity fields. Host instrumentation does not intentionally attach usernames, client IPs, account names, passwords, tokens, SQL statements, or raw plugin errors.

## Reload versus restart

SIGHUP can apply only a module's plugin-owned `config` when the loaded plugin implements `ReloadablePlugin`. All affected reloadable modules must validate successfully before host-owned views are committed. A rejected reload leaves the previous working configuration active.

The following changes require a process restart:

- adding or removing a module;
- changing module `name`, `type`, `path`, `checksum`, `signature`, `signer`, `optional`, `stop_timeout`, or `allow_capabilities`;
- changing module `hooks` authorization;
- changing module `compatibility.metrics` or `compatibility.trace_scopes`;
- changing `verification_policy`, `allowed_dirs`, or trusted signers;
- replacing the `.so` file;
- changing the API version or shared Go build contract.

Go cannot unload or replace a shared object after `plugin.Open`. SIGUSR1 does not provide restartless plugin code replacement.

## Build compatibility

An artifact must match the deployed server's:

- `GOEXPERIMENT` setting (`runtimesecret` for current Nauthilus builds);
- Go toolchain, including patch-level compatibility where package hashes differ;
- build tags, including `netgo` and any additional release tags;
- `-trimpath` and relevant build shape;
- exact `github.com/croessner/nauthilus/v4` source version;
- shared dependency versions and module graph.

`pluginapi.APIVersion == "nauthilus.plugin.v1"` validates the semantic contract after load; it cannot override Go's package-hash checks. Rebuild external plugins for the exact host release or commit.

## Related documentation

- [Native Go plugin developer documentation](../developer/go-plugins/index.md)
- [Security and compatibility](../developer/go-plugins/security-and-compatibility.md)
- [Go plugin API reference](../developer/go-plugins/api-reference/index.md)
