---
title: Developer Documentation
description: Extend Nauthilus with native Go plugins and its public developer APIs
keywords: [Nauthilus, Developer, Go, Plugins, API]
sidebar_position: 1
---

# Developer Documentation

This section documents the public extension surfaces of the current Nauthilus development line. It complements the operator-oriented configuration guides and the generated HTTP API reference.

## Native Go plugins

Nauthilus 3.1 introduces a public, versioned contract for trusted in-process Go plugins. The documentation is organized into four layers:

1. [Native Go plugins](./go-plugins/index.md) explains the model and provides a learning path.
2. [Configure native Go plugins](../configuration/native-go-plugins.md) covers loading, verification, capabilities, discovery, and restart behavior for operators.
3. [Reference plugins](./go-plugins/reference-plugins/index.md) explains every plugin shipped under `contrib/plugins`.
4. [Go plugin API reference](./go-plugins/api-reference/index.md) describes every exported declaration in `pluginapi/v1` and its public subpackages.

:::warning Trusted in-process code

Native plugins are not sandboxed. A loaded `.so` runs inside the Nauthilus process and has the same operating-system privileges as the server. Artifact provenance, code review, resource bounds, and secret-safe behavior are part of the plugin's security boundary.

:::

## Other APIs

- [Lua API](../lua-api/introduction.md) documents the embedded Lua extension surface.
- [HTTP API reference](../api-reference/index.md) is generated from the Management and IdP OpenAPI contracts.
- [REST API guide](../rest-api.md) explains authentication endpoints and management operations narratively.
- [gRPC API](../grpc-api.md) covers authority and distributed identity-backend integrations.

The native Go plugin API is independent of the HTTP and gRPC wire APIs. A plugin uses Go value types and host-provided interfaces inside the server process; an external integration uses a versioned network contract.
