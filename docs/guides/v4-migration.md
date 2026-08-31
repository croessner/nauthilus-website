---
title: Migrating to Nauthilus v4
description: Landing page for the v4 module, native plugin, configuration, and API migration
keywords: [Nauthilus, v4, migration, Policy, Go modules, plugins]
sidebar_position: 1
---

# Migrating to Nauthilus v4

Nauthilus `v4.0.0-alpha.1` is the first planned v4 prerelease. The major version records two deliberate compatibility boundaries: the Go module moves to `github.com/croessner/nauthilus/v4`, and decision configuration moves from the removed `auth.policy` subtree to the top-level Policy model.

:::warning Prerelease

This page prepares the upcoming alpha. It does not claim that `v4.0.0-alpha.1` has already been published or is production-ready.

:::

## Migration checklist

1. Replace only the exact Nauthilus module prefix `github.com/croessner/nauthilus/v3` with `github.com/croessner/nauthilus/v4`.
2. Rebuild every native `.so` plugin against the v4 `pluginapi/v1` package and the exact host toolchain, build tags, relevant flags, and dependency sources.
3. Manually migrate the removed v3 `auth.policy` configuration to top-level `policy`.
4. Replace unqualified `standard_auth`, rule/check `stage`, and check `config_ref` with the exact v4 qualified identities and checkpoint ownership.
5. Keep Policy and backchannel credentials separate.
6. Regenerate Go clients that consume Nauthilus-owned `go_package` metadata. Independently generated protobuf clients remain wire-compatible because package names, services, methods, field numbers, and HTTP paths are unchanged.
7. Review the [alpha release notes](../release-notes/4.0.0-alpha.1.md) and validate the complete deployment candidate before any rollout.

## Detailed contracts

- [Policy configuration hard cut and manual migration](policy-configuration-migration.md)
- [Policy configuration overview](../configuration/auth-policy.md)
- [Native Go plugin guide](../developer/go-plugins/index.md)
- [Generated protected HTTP API reference](../api-reference/index.md)

Third-party module paths that independently contain a `/v3` suffix are unrelated and must not be rewritten.
