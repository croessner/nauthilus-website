---
title: Go Plugin API Reference
description: Complete public API reference for Nauthilus native Go plugins
keywords: [Go plugin API, pluginapi v1, reference, NauthilusPlugin]
sidebar_position: 1
---

# Go Plugin API Reference

This reference documents every exported constant, variable, type, function, method, interface method, and public struct field in the four supported packages:

```text
github.com/croessner/nauthilus/v3/pluginapi/v1
github.com/croessner/nauthilus/v3/pluginapi/v1/exchange
github.com/croessner/nauthilus/v3/pluginapi/v1/helpers
github.com/croessner/nauthilus/v3/pluginapi/v1/password
```

It describes the public source contract and the behavior of the current Nauthilus production adapters separately. This distinction matters: an exported field can be available to plugin code while a particular adapter leaves it empty, or a result field can be accepted by the type system while the current runtime does not act on it.

## Status vocabulary

Each page uses these terms:

| Term | Meaning |
| --- | --- |
| **Public surface** | The declaration is part of the importable `pluginapi/v1` contract. Go code can compile against it. |
| **Populated** | The current production adapter supplies a meaningful value at that invocation point. Empty remains a valid value unless stated otherwise. |
| **Evaluated** | The current production adapter consumes the returned value and changes host behavior. |
| **Discovery only** | The value is reported or retained for diagnostics but does not authorize or schedule behavior. |
| **Currently ignored** | The field is public but the current production path does not act on it. Do not depend on it until the implementation changes. |

The statements about current behavior describe the Nauthilus 3.1 development line represented by this documentation. They are not a promise that an ignored field will remain ignored.

## Package map

| Page | Declarations |
| --- | --- |
| [Core contract](./contract.md) | API version, metadata, capabilities, plugin lifecycle, configuration views, registration, host and logging contracts |
| [Runtime and request values](./runtime.md) | request snapshots, TLS and IdP values, runtime context, credentials and secrets |
| [Common results](./results.md) | statuses, facts, patches, response mutation, backend result values and backend server references |
| [Extension points](./extensions.md) | init tasks, environment and subject sources, obligations and post-actions |
| [Backends and MFA](./backends.md) | password backends, account lists, TOTP, recovery codes, WebAuthn and public MFA state |
| [Host services](./services.md) | HTTP, mail, connection targets, Redis, cache, helpers, LDAP, metrics and tracing |
| [HTTP hooks](./hooks.md) | hook descriptors, authentication matrix, requests and responses |
| [Policy declarations](./policy.md) | policy stages, operations, types, categories, details and fact/log identifiers |
| [Validation](./validation.md) | public sentinel errors, name grammars and validation/building functions |
| [`helpers` package](./helpers.md) | account hash tags, IP scoping and routability checks |
| [`password` package](./password.md) | password comparison, salted SHA parsing/generation and full SHA-256 hashes |
| [`exchange` package](./exchange.md) | standard runtime keys, feature values and deterministic analytics views |

## Compatibility boundary

`pluginapi.APIVersion` is a semantic API contract, not a portable Go plugin ABI. A `.so` must also match the host's Go toolchain, experiments, build tags, package sources, and shared dependency graph. The root service API deliberately exports `github.com/redis/go-redis/v9` interfaces, so the exact shared go-redis package version is part of binary compatibility.

The host places panic boundaries around plugin factory, metadata, registration, lifecycle, and request-time calls. A recovered panic is treated as a plugin failure; it does not make native plugins a sandbox. Loaded code has the process privileges of Nauthilus.

For architecture and usage examples, start with the [developer guide](../index.md). This section is the declaration-by-declaration lookup view.
