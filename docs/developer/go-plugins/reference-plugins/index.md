---
title: Bundled Reference Plugins
description: Source-level reference for the native Go plugins bundled with Nauthilus
keywords: [Go plugins, GeoIP, ClickHouse, Have I Been Pwned, reputation, DKIM2, DKIM2 intelligence, reference plugins]
sidebar_position: 1
---

# Bundled Reference Plugins

Nauthilus ships the native Go plugin artifacts `geoip`, `clickhouse`, `haveibeenpwnd`, `reputation`, and
`dkim2-intelligence` in its stable and debug container images below `/usr/local/lib/nauthilus/plugins`. They demonstrate different
`pluginapi/v1` extension points:

| Plugin | Extension point | Qualified component with the standard module name | Primary purpose |
| --- | --- | --- | --- |
| [GeoIP/ASN](./geoip.md) | Generic native Decision Fact Providers, one per configured `decision_bindings` entry | `authn/plugin.geoip.environment` in the authentication example | Add local GeoIP, ASN, and freshness evidence for any configured Policy target. |
| [ClickHouse](./clickhouse.md) | `PostActionTarget` | `authn/plugin.clickhouse.post_action` | Write batched authentication analytics as ClickHouse JSONEachRow data. |
| [Have I Been Pwned](./haveibeenpwnd.md) | `PostActionTarget` | `authn/plugin.haveibeenpwnd.post_action` | Check an authenticated request password through the HIBP k-anonymity API and optionally send mail. |
| [Reputation](./reputation.md) | Generic native `DecisionFactProvider`s, a `DecisionEffectProvider`, an `ObligationTarget`, and admin hooks | `authn/plugin.reputation.<component>`, `authn/plugin.reputation.learn_outcome`, `reputation/plugin.reputation.observation_context` | Admit independent evidence, store decaying reputation in primary Redis, publish assessment records, and administer audited overrides. Includes the `reputation-worker` Kafka consumer. |
| [DKIM2 Intelligence](./dkim2-intelligence.md) | Generic native `DecisionFactProvider` | `dkim2/plugin.dkim2_intelligence.assessment` | Correlate an admitted DKIM2 verifier projection with reputation, current-peer GeoIP/ASN, and operator identity contracts without selecting the decision. Replaces the `dkim2-reputation` plugin of early v4 prereleases. |

The bundled artifacts:

- are trusted in-process Go plugins, not sandboxed services;
- export `NauthilusPlugin() (pluginapi.Plugin, error)`;
- implement `Plugin` and `RuntimePlugin`, and all except `reputation` also implement `ReloadablePlugin`;
- are built from `package main` below `contrib/plugins`;
- currently report plugin product version `0.1.0` and `pluginapi.APIVersion`;
- use strict plugin-owned configuration decoding, so unknown keys and type mismatches reject registration or reload;
- require a process restart when the artifact, module identity, verification settings, or capability grants change.

The repository also contains `contrib/plugins/internal/pluginutil`. It is an implementation-only Go `internal` package shared by bundled plugins. It is not a loadable plugin, not part of `pluginapi/v1`, and not available as a public helper package to external plugin modules.

## Choose the right page

- Use [Configure native Go plugins](../../../configuration/native-go-plugins.md) for loader fields, allowlisted paths, checksums, detached signatures, capability grants, discovery, debug selectors, and restart rules.
- Use [Build, test, and debug](../build-test-debug.md) for the general ABI and test workflow.
- Use [Security and compatibility](../security-and-compatibility.md) before loading third-party artifacts.
- Use the individual reference page for the exact plugin-owned config, lifecycle, host-service use, outputs, metrics, ordering, and current implementation limits.

## Binary compatibility

The bundled container artifacts are built in the same source tree as the Nauthilus server with the same Go toolchain, module graph, experiment, tags, and path-shaping flags. A local rebuild must reproduce that build identity. From the Nauthilus repository root, the baseline shape is:

```shell
mkdir -p build

export CGO_ENABLED=1 GOEXPERIMENT=runtimesecret
NATIVE_ARTIFACT_LDFLAGS="$(go run -mod=vendor ./scripts/native_artifact_fingerprint -tags="netgo")"

go build \
  -mod=vendor \
  -tags="netgo" \
  -trimpath \
  -ldflags "${NATIVE_ARTIFACT_LDFLAGS}" \
  -buildmode=plugin \
  -o build/<plugin>.so \
  ./contrib/plugins/<plugin>
```

Replace `<plugin>` with `geoip`, `clickhouse`, `haveibeenpwnd`, `reputation`, or `dkim2-intelligence`. The host loader
rejects artifacts that do not carry its exact native artifact identity, so the container build and the
`geoip` and `dkim2-intelligence` Makefiles pass `-ldflags "$(go run -mod=vendor ./scripts/native_artifact_fingerprint)"`. If the host uses additional build tags, add the exact same tags. Build from the
exact Nauthilus tag or commit used for the host; `pluginapi.APIVersion` compatibility alone does not guarantee that
Go's plugin loader will accept the artifact.

:::tip Prefer the bundled artifact

When using the Nauthilus container image, prefer its bundled `.so` and matching `.minisig` file. This avoids rebuilding against a subtly different Go package graph.

:::

## Results do not all mean the same thing

The plugins demonstrate several distinct data paths:

- GeoIP contributes generic Policy facts under `plugin.geoip.*` (or one correlated record collection per record binding) and no runtime exchange delta.
- Reputation contributes assessment records under `plugin.reputation.*` and writes learned evidence only through Policy-selected obligations; it emits no decision and no runtime exchange delta.
- DKIM2 Intelligence contributes a correlated assessed chain, one SMTP-peer record, and a structural completeness flag under `plugin.dkim2_intelligence.*`, and no decision, SMTP action, or runtime exchange delta.
- HIBP returns a plan-local `PostActionEnqueueResult.RuntimeDelta` under `plugin.exchange.haveibeenpwnd` for later post-action steps.
- ClickHouse consumes request snapshots, policy facts, and `plugin.exchange.*` data, but emits no policy facts and no runtime delta of its own.

Policy facts are validated decision evidence. Runtime exchange values are JSON-compatible coordination data. A post-action delta is visible only to later steps in the same detached post-action plan; it does not change the already selected decision, live request runtime, or client response.

## Current source-asset caveats

The pages describe the plugin implementation as it exists now, including known inconsistencies:

- GeoIP registers only the providers listed in `decision_bindings`; there is no implicit binding, authentication-shaped environment source, or runtime exchange alias.
- Reputation is not reloadable: every configuration change requires a restart of all servers and workers that share its Redis prefix.
- The checked-in ClickHouse schema and Kubernetes initialization assets do not currently cover every field emitted by the native plugin. They must be aligned before being treated as a validated deployment.
- ClickHouse buffers rows per process in memory (bounded by `max_buffer_rows`); there is no durable spool, so rows still buffered when a process ends are lost.
- HIBP mail uses `Host.Mail("mail")`, runs only after a fresh positive HTTP lookup, and does not retry after a mail gate has been claimed and rendering or sending fails.

These are implementation limits, not recommended extension patterns.
