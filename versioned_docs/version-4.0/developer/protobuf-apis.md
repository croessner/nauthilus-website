---
title: Public Protobuf APIs
description: Versioned protobuf package layout, generated Go imports, and wire-compatibility boundaries
keywords: [protobuf, gRPC, API, compatibility, v4]
sidebar_position: 3
---

# Public Protobuf APIs

Nauthilus keeps public protobuf contracts below `api/<domain>/v1`. The directory and protobuf package version describe
the wire contract; the generated Go import follows the current Nauthilus major module.

| Source directory | Protobuf package | Purpose |
| --- | --- | --- |
| `api/auth/v1` | `nauthilus.auth.v1` | Authentication service and messages |
| `api/common/v1` | `nauthilus.common.v1` | Shared message types |
| `api/identity/v1` | `nauthilus.identity.v1` | Identity-backend service and messages |
| `api/policy/v1` | `nauthilus.policy.v1` | Generic Policy decision service and messages |

Generated Go clients import these packages below `github.com/croessner/nauthilus/v4/api/.../v1`. Code generated from
the v3 `go_package` metadata should be regenerated for v4. This source-import change is separate from protobuf wire
compatibility.

## Compatibility Boundary

The v4 migration preserves protobuf package names, service and method names, field numbers, field wire types, and HTTP
paths. Independently generated clients therefore remain wire-compatible when they use those stable identifiers. Do not
rely on generated Go package paths or Go type identity remaining compatible across a major module change.

Safe evolution adds new fields with unused numbers and preserves existing meaning. Removing or reusing a field number,
changing its wire type, renaming a service or method, or moving an HTTP route is a wire-contract change. Reserve removed
field numbers and names rather than recycling them.

The Generic Policy gRPC entry point is
`/nauthilus.policy.v1.PolicyDecisionService/Evaluate`; its typed value, ordered-record, security, status, and decision
semantics match the REST contract. See [Generic Policy API](../guides/generic-policy-api.md).

## Go Toolchain and Native Plugins

The Nauthilus `v4.0.0` source and release build use exactly Go 1.27.1 with `GOEXPERIMENT=runtimesecret`. Native Go `.so` plugins are
not protected by protobuf wire compatibility: rebuild them from the exact Nauthilus commit with the same Go version,
module graph, experiment, build tags, CGO mode, operating system, and architecture. The public `pluginapi/v1` contract
does not make mismatched Go binaries load-compatible.

## Code Generation Toolchain

The checked-in `*.pb.go` files are generated with `protoc` 36.1, `protoc-gen-go` 1.36.11, and `protoc-gen-go-grpc`
1.5.1. The versions are pinned in `scripts/protobuf-toolchain.env`; the generation scripts refuse to run with other
generator versions, and CI checks that regenerating produces the committed files (`make generate-grpc-proto-check`). Use the same versions when you regenerate the public contracts, so version headers and
generated output stay stable.
