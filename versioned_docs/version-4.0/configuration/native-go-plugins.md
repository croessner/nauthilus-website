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
        decision_bindings:
          - component: environment
            targets: [authn/authenticate, authn/lookup_identity]
            input: {fact: nauthilus.request.client.ip, category: environment}
            output_schema: geoip.facts.v1
```

## `plugins` fields

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `verification_policy` | string | `when_present` | Global artifact verification policy for configured modules. |
| `allowed_dirs` | list of absolute paths | none | Directories from which plugin artifacts may be loaded. At least one is required when modules are configured. |
| `trust.signers` | list | empty | Trusted detached-signature identities. |
| `opaque_identifier_tagger` | mapping | absent | Host-owned HMAC keys for `Host.OpaqueIdentifierTagger()`; see [Opaque identifier keys](#opaque-identifier-keys). |
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

## Artifact staging directory

Nauthilus does not open a plugin from its configured `path`. At startup the loader creates a private directory
`nauthilus-plugin-artifacts-*` (mode `0700`) in the process temporary directory, copies each verified artifact into it as
`verified-*.so` (mode `0400`), checks that the copy still matches the verified digest, and opens the copy. The directory
is removed when the loader run ends.

The temporary directory is `$TMPDIR`, or `/tmp` when `TMPDIR` is unset. It must be:

- writable by the Nauthilus user;
- mounted without `noexec`, because the dynamic loader maps the staged file as executable code;
- large enough to hold one copy of every configured artifact at the same time.

If the mount carries `noexec`, opening the plugin fails with `Operation not permitted`; an optional module is skipped and
a required module aborts startup. Mandatory access control policies that deny executable mappings from the temporary
directory, such as SELinux or fapolicyd rules, cause the same failure.

This matters for hardened containers with a read-only root file system. Docker and Compose mount a `tmpfs` with `noexec`
by default, so request `exec` explicitly:

```yaml
services:
  nauthilus:
    read_only: true
    tmpfs:
      - /tmp:exec
```

With `docker run`, use `--read-only --tmpfs /tmp:exec`. In Kubernetes with `readOnlyRootFilesystem: true`, mount an
`emptyDir` at `/tmp`:

```yaml
spec:
  containers:
    - name: nauthilus
      securityContext:
        readOnlyRootFilesystem: true
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir:
        medium: Memory
        sizeLimit: 256Mi
```

An `emptyDir` carries no `noexec` option of its own; if node hardening mounts the kubelet directory with `noexec`, point
`TMPDIR` at a volume that allows exec. To keep `/tmp` itself `noexec`, mount a separate exec-capable volume, for example
at `/var/lib/nauthilus/tmp`, and set `TMPDIR` to that path. Size `sizeLimit` for the sum of all configured artifacts.

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
| `positive_password_cache` | boolean | `false` | restart | Operator opt-in for the Redis positive password cache in front of this module's backends; see [Positive password cache for backend modules](#positive-password-cache-for-backend-modules). |
| `config` | mapping | empty | possible SIGHUP | Opaque plugin-owned configuration decoded strictly by the plugin. |

Module and component names use `[a-z0-9][a-z0-9_]{0,62}`. The module name qualifies everything the instance registers. For example, local backend `passdb` in module `customer_sql` becomes `customer_sql.passdb`.

An optional module that fails does not contribute its components. Configuration that requires one of those components, such as an ordered `plugin(module.backend)` selector or a policy check bound to the source, must still be designed for that absence; `optional` is not a promise that dependent configuration remains meaningful.

## Positive password cache for backend modules

A `cache` entry in `auth.backends.order` serves native backend plugins only when both sides opt in: the operator sets
`plugins.modules[].positive_password_cache: true`, and the backend declares cache safety in its build. Without both,
plugin backends always verify the password themselves.

```yaml
auth:
  backends:
    order: [cache, plugin(customer_sql.passdb)]
plugins:
  allowed_dirs: [/usr/lib/nauthilus/plugins]
  modules:
    - name: customer_sql
      type: go
      path: /usr/lib/nauthilus/plugins/customer_sql.so
      allow_capabilities: [credentials]
      positive_password_cache: true
      config: {}
storage:
  redis:
    positive_cache_ttl: 30s
```

- The default is `false`. A `cache` entry before `plugin(<module>.<backend>)` of a module without the opt-in loads
  with the configuration warning `cache before plugin(...) has no effect without plugins.modules[].positive_password_cache
  and the plugin cache declaration`.
- An opted-in module whose backends do not all declare cache safety fails registration.
- Entries use the positive-cache prefix with an isolated internal namespace per module and backend, store only the full
  prepared password digest (including `password_nonce`), and encrypt payload fields with the Redis encryption manager.
  `storage.redis.positive_cache_ttl` controls expiry; hits do not refresh it.
- The payload binds username, protocol, and OIDC client ID, and backends whose login resolution depends on a domain or
  tenant header bind that additional scope as well. A different scope misses and falls back to the plugin. Scopes of
  one account share a key and can replace each other, which can reduce the hit rate but never grants cross-scope
  access.
- Wrong passwords miss the cache and follow normal backend verification, brute-force accounting, and
  password-history handling. No negative entries are stored.
- A password change in the plugin's own database is not detected automatically. Flush the affected accounts through the
  user-cache flush API, which includes plugin namespaces, or wait for the TTL. Flush before changing backend identity
  semantics or removing or renaming a module.
- Subject providers, post-actions, and Policy checks still run on every request.
- The typed Policy provider `authn/builtin/plugin_backend_order` admits `cache` entries only for opted-in plugin
  instances and never reads LDAP or Lua cache namespaces.

Developers find the backend declaration contract in the [Go plugin API reference](../developer/go-plugins/api-reference/index.md).

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
| `password_hash` | The host-owned SHA-256 password digest in `PostActionRequest.PasswordHash` for detached post-actions. It grants no raw credential access. |
| `mail` | Host-managed SMTP/LMTP sends through `Host.Mail`. |

`credentials`, `password_hash`, and `mail` are sensitive and denied unless listed in `allow_capabilities`. `credentials`
does not imply `password_hash`. One `credentials` grant covers every credential-bearing request of that module:
backends, environment and subject sources, synchronous Policy obligations, and post-actions. There is no separate
obligation-specific capability. Components of a module without the grant receive a provider that reports the password
as unavailable and holds no password material. Duplicate or unknown capability entries are invalid. Grant only what the module's active configuration needs.

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

The bundled native ClickHouse plugin requires `password_hash` to register. Existing ClickHouse modules must add it
explicitly:

```yaml
plugins:
  modules:
    - name: clickhouse
      path: /usr/local/lib/nauthilus/plugins/clickhouse.so
      allow_capabilities: [password_hash]
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
any-of semantics: a bearer token needs at least one listed scope.

An administrative descriptor (`HookScopeAdmin` or `HookAuthAdmin`) always
requires a bearer token with `nauthilus:admin`, regardless of its auth mode.
Configured scopes on such a hook narrow the requirement but never replace it:
the caller needs `nauthilus:admin` and at least one listed scope. Values are
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

## Opaque identifier keys

`plugins.opaque_identifier_tagger` configures the keys behind the required host service
`Host.OpaqueIdentifierTagger()`. Keys stay outside module-owned `config`; plugins never receive key bytes.

```yaml
plugins:
  opaque_identifier_tagger:
    scopes:
      - scope: workflow
        active:
          version: current
          secret_ref:
            file: /run/secrets/workflow-current
        previous:
          version: previous
          secret_ref:
            file: /run/secrets/workflow-previous
```

| Field | Rule |
| --- | --- |
| `scopes` | 1 to 32 unique entries. |
| `scope` | Lowercase label of at most 64 bytes: `a-z` and `0-9`, plus `_`, `-`, `.` after the first byte. Plugins must request exactly this scope. |
| `active.version` / `previous.version` | Same label syntax, at most 32 bytes. `previous` is optional and needs a different version and a different file. |
| `secret_ref.file` | Absolute, clean path to a file containing exactly 32 raw random bytes. |

Inline key material, empty or wrongly sized files, and invalid references fail validation. There are no generated
default keys; without this section `OpaqueIdentifierTagger()` returns `ErrOpaqueIdentifierTaggerUnavailable`.
Configuration dumps show only references. Key files are captured in the sealed configuration snapshot, so changing a
reference or replacing a file at the same path requires a process restart.

New tags always use the active key; consumers must explicitly request previous-version candidates. Use separate scopes
for independently managed purposes. During rotation, keep both keys until every consumer's retention and replay window
has elapsed and any operator overrides have been migrated. A rollback must keep the complete matching key references;
removing a still-needed previous key can make existing state unreachable.

## Bundled artifacts

Stable and debug Nauthilus container images build these artifacts with the same toolchain and module graph as the server:

| Artifact | Module purpose | Documentation |
| --- | --- | --- |
| `/usr/local/lib/nauthilus/plugins/geoip.so` | GeoIP/ASN generic Policy fact provider | [GeoIP/ASN](../developer/go-plugins/reference-plugins/geoip.md) |
| `/usr/local/lib/nauthilus/plugins/clickhouse.so` | Batched ClickHouse post-action | [ClickHouse](../developer/go-plugins/reference-plugins/clickhouse.md) |
| `/usr/local/lib/nauthilus/plugins/haveibeenpwnd.so` | HIBP password lookup and optional mail post-action | [Have I Been Pwned](../developer/go-plugins/reference-plugins/haveibeenpwnd.md) |
| `/usr/local/lib/nauthilus/plugins/reputation.so` | Generic reputation fact, effect, and learning providers | [Reputation](../developer/go-plugins/reference-plugins/reputation.md) |
| `/usr/local/lib/nauthilus/plugins/dkim2-intelligence.so` | DKIM2 chain correlation fact provider | [DKIM2 Intelligence](../developer/go-plugins/reference-plugins/dkim2-intelligence.md) |

The debug image contains the server, these plugins, and the fake SMTP/IMAP test servers only. The `reputation-worker`
executable and the client tools are intentionally shipped in the stable image alone. Examples for the bundled plugins use
the image path `/usr/local/lib/nauthilus/plugins/`; custom plugins may live in any absolute directory listed in
`allowed_dirs`.

All bundled artifacts are built with the same native artifact identity as the server. Release and features/debug image builds require signed bundled plugins. Detached `.minisig` files are placed beside the `.so` files. Configure the public build key as a trusted signer; never copy the private seed into the runtime image.

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

Configuration reloads are counted in `plugin_reconfigure_total{module,result}`, one increment per module and reload; see
[Reload versus restart](#reload-versus-restart).

Automatic spans use the `nauthilus/plugin/runtime` instrumentation scope and the same low-cardinality identity fields. Host instrumentation does not intentionally attach usernames, client IPs, account names, passwords, tokens, SQL statements, or raw plugin errors.

## Reload versus restart

A SIGHUP reload applies changes inside `plugins.modules[].config` of a module whose plugin implements
`ReloadablePlugin`. Every other field of the `plugins` section is restart-bound, and so is the `config` of a module
whose plugin does not support reload. The bundled `clickhouse`, `geoip`, `haveibeenpwnd`, and `dkim2-intelligence`
plugins reload their config; individual keys such as `decision_bindings` in `geoip` stay restart-bound.

A reload runs in two phases around the Policy generation swap:

1. Preparation compares the candidate `plugins` section with the running one. A restart-bound change rejects the whole
   reload with `plugin restart required` and names the module. Every module whose `config` changed validates its
   candidate. Any failure rejects the whole reload; no module is reconfigured and the active generation stays in place.
2. After the new Policy generation is committed, Nauthilus reconfigures each changed module in declaration order.
   Unchanged modules are not called. If one module fails here, the new generation and the other modules stay active,
   the failing module keeps its previous configuration, the reload is reported as failed with the module name, and the
   next reload retries the change.

Each reload logs one record per module (`plugin_module`, `plugin_reload_result`) and counts it in
`plugin_reconfigure_total{module,result}` with the result `reloaded`, `unchanged`, `restart_required`, `rejected`,
`failed`, or `aborted`. Neither log nor metric contains config values or error text.

The following changes require a process restart:

- adding or removing a module;
- any `config` change of a module whose plugin does not implement `ReloadablePlugin`, and keys that a plugin reports as restart-bound;
- changing module `name`, `type`, `path`, `checksum`, `signature`, `signer`, `optional`, `stop_timeout`, `allow_capabilities`, or `positive_password_cache`;
- changing module `hooks` authorization;
- changing module `compatibility.metrics` or `compatibility.trace_scopes`;
- changing `opaque_identifier_tagger` or replacing a referenced key file;
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

Before `plugin.Open`, the loader also checks the native artifact identity that the build embeds through `-ldflags`. It
is a fingerprint of compiler settings, target OS and architecture, CGO settings, build tags, source files, dependency
locks, and embedded resources. An unmarked plugin, or one built from a different snapshot, fails with "native artifact
does not match the host build identity". Detached signatures and checksums still authenticate provenance and exact bytes
separately; keep `signature_required` in production.

Build the server and all plugins from one source snapshot, sign them afterwards, and publish server, plugins, signatures,
and configuration as one immutable bundle activated by a restart. Keep the previous complete bundle for rollback and
never mix old plugin files into a new image. Developers can find the build commands in
[native artifact identity](../developer/go-plugins/build-test-debug.md#native-artifact-identity).

## Related documentation

- [Native Go plugin developer documentation](../developer/go-plugins/index.md)
- [Security and compatibility](../developer/go-plugins/security-and-compatibility.md)
- [Go plugin API reference](../developer/go-plugins/api-reference/index.md)
