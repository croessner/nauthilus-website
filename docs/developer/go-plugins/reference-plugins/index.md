---
title: Bundled Reference Plugins
description: Source-level reference for the native Go plugins bundled with Nauthilus
keywords: [Go plugins, GeoIP, ClickHouse, Have I Been Pwned, reference plugins]
sidebar_position: 1
---

# Bundled Reference Plugins

Nauthilus ships three native Go plugin artifacts in its stable and debug container images. They are production-oriented integrations and source examples for different `pluginapi/v1` extension points:

| Plugin | Extension point | Qualified component with the standard module name | Primary purpose |
| --- | --- | --- | --- |
| [GeoIP/ASN](./geoip.md) | Generic native Decision Fact Provider | `authn/plugin.geoip.environment` | Add local GeoIP and ASN evidence before authentication policy runs. |
| [ClickHouse](./clickhouse.md) | `PostActionTarget` | `authn/plugin.clickhouse.post_action` | Write batched authentication analytics as ClickHouse JSONEachRow data. |
| [Have I Been Pwned](./haveibeenpwnd.md) | `PostActionTarget` | `authn/plugin.haveibeenpwnd.post_action` | Check an authenticated request password through the HIBP k-anonymity API and optionally send mail. |

All three artifacts:

- are trusted in-process Go plugins, not sandboxed services;
- export `NauthilusPlugin() (pluginapi.Plugin, error)`;
- implement `Plugin`, `RuntimePlugin`, and `ReloadablePlugin`;
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

CGO_ENABLED=1 \
GOEXPERIMENT=runtimesecret \
go build \
  -mod=vendor \
  -tags="netgo" \
  -trimpath \
  -buildmode=plugin \
  -o build/<plugin>.so \
  ./contrib/plugins/<plugin>
```

Replace `<plugin>` with `geoip`, `clickhouse`, or `haveibeenpwnd`. If the host uses additional build tags, add the exact same tags. Build from the exact Nauthilus tag or commit used for the host; `pluginapi.APIVersion` compatibility alone does not guarantee that Go's plugin loader will accept the artifact.

:::tip Prefer the bundled artifact

When using the Nauthilus container image, prefer its bundled `.so` and matching `.minisig` file. This avoids rebuilding against a subtly different Go package graph.

:::

## Results do not all mean the same thing

The plugins demonstrate three distinct data paths:

- GeoIP contributes generic Policy facts under `plugin.geoip.*` and no runtime exchange delta.
- HIBP returns a plan-local `PostActionEnqueueResult.RuntimeDelta` under `plugin.exchange.haveibeenpwnd` for later post-action steps.
- ClickHouse consumes request snapshots, policy facts, and `plugin.exchange.*` data, but emits no policy facts and no runtime delta of its own.

Policy facts are validated decision evidence. Runtime exchange values are JSON-compatible coordination data. A post-action delta is visible only to later steps in the same detached post-action plan; it does not change the already selected decision, live request runtime, or client response.

## Current source-asset caveats

The pages describe the plugin implementation as it exists now, including known inconsistencies:

- GeoIP has one generic provider authority; there is no authentication-shaped environment source or runtime exchange alias.
- The checked-in ClickHouse schema and Kubernetes initialization assets do not currently cover every field emitted by the native plugin. They must be aligned before being treated as a validated deployment.
- ClickHouse has threshold-based flushing only; there is no timer flush or shutdown flush.
- HIBP mail uses `Host.Mail("mail")`, runs only after a fresh positive HTTP lookup, and does not retry after a mail gate has been claimed and rendering or sending fails.

These are implementation limits, not recommended extension patterns.
