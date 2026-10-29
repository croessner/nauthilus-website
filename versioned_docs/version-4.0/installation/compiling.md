---
title: Compiling
description: Compile Nauthilus from source with the supported Go toolchain
keywords: [Source, Build, Compile, Go, GOEXPERIMENT]
sidebar_position: 2
---

# Compiling

This guide explains how to compile Nauthilus from source instead of using a pre-built binary.

## Prerequisites

- Go 1.27.1. `go.mod` declares `go 1.27` with `toolchain go1.27.1`, and the project CI, container builds, and
  `make guardrails` require exactly this toolchain.
- Git.
- A C toolchain when the selected target or native Go plugins require CGO.

Nauthilus uses the Go module path `github.com/croessner/nauthilus/v4` and the `runtimesecret` Go experiment. Use the
toolchain version declared by `go.mod` and keep `GOEXPERIMENT=runtimesecret` enabled for builds and tests.

Verify the local toolchain before building:

```bash
go version
GOEXPERIMENT=runtimesecret go env GOEXPERIMENT
```

`go version` must report `go1.27.1`. With an older local Go 1.27 release, the Go command downloads the declared
toolchain automatically unless `GOTOOLCHAIN=local` is set.

## Get the Source

```bash
git clone https://github.com/croessner/nauthilus.git
cd nauthilus
```

The `main` branch is the current development line. For reproducible production builds, check out the exact release tag
you intend to deploy:

```bash
git fetch --tags
git checkout v4.0.0
```

For another release, replace the tag with the exact published version you intend to build.

## Build with Make

The repository Makefile is the canonical local build entry point:

```bash
make build
```

The Makefile exports `GOEXPERIMENT=runtimesecret`, runs the source migration and vet checks, embeds version and build
metadata, and writes the server binary to:

```text
nauthilus/bin/nauthilus
```

Useful validation targets include:

- `make test`: run the short Go test suite.
- `make race`: run the short test suite with the race detector.
- `make vet`: run `go vet`.
- `make guardrails`: run the repository's full local quality gate. It requires golangci-lint 2.13.2 and checks the
  exact Go toolchain contract.
- `make clean`: remove binaries created by the Makefile.

`make build` includes `go fix ./...`; run it only in a checkout where source rewrites are acceptable.

## Direct Go Build

To build only the server without the Makefile orchestration:

```bash
GOEXPERIMENT=runtimesecret go build \
  -mod=vendor \
  -trimpath \
  -o nauthilus \
  ./server
```

This produces a functional binary but does not inject the same Git version, build timestamp, or compiled configuration
path values as `make build` and the release pipeline.

## Build Tags

The normal server does not require an application feature tag. The supported optional endpoint tag is:

| Tag | Effect |
| --- | --- |
| `auth_basic_endpoint` | Includes `/api/v1/auth/basic`, which maps end-user credentials from the HTTP Basic `Authorization` header. |

Build that variant with:

```bash
GOEXPERIMENT=runtimesecret go build \
  -mod=vendor \
  -trimpath \
  -tags auth_basic_endpoint \
  -o nauthilus \
  ./server
```

Do not confuse this optional authentication protocol endpoint with `auth.backchannel.basic_auth`, which protects
management routes and does not require this build tag.

Release and container builds may additionally use the standard `netgo` tag for network resolver behavior. The former
`dev` and `register2fa` feature tags are not part of the current build contract.

## Profile-Guided Optimization

Go applies profile-guided optimization automatically when a CPU profile named `default.pgo` exists in the main package
directory. For Nauthilus that file is `server/default.pgo`. When the file is committed, `make build`, the direct
`go build ./server` command above, release builds, and Docker builds consume it without extra flags. The profile is
produced from the release end-to-end workload of one release and used by the next one; a release built without the file
is an ordinary non-PGO build. `v4.0.0` ships without `server/default.pgo`, so its binaries and images are
non-PGO builds. Pass `-pgo=off` to disable the profile for a single build.

## Protobuf Code Generation

Only contributors who change the `.proto` contracts need the protobuf toolchain. Generated code is pinned to
`protoc` 36.1, `protoc-gen-go` 1.36.11, and `protoc-gen-go-grpc` 1.5.1, as declared in
`scripts/protobuf-toolchain.env`. Regenerate with the same versions so the generated headers stay stable.

## Reproducibility Notes

- Keep the vendored dependency tree intact when using `-mod=vendor`.
- Use the same Go version, `GOEXPERIMENT`, build tags, module sources, operating system, architecture, and CGO mode when
  binary compatibility matters. A present `server/default.pgo` also changes the generated code.
- A native Go plugin must match the host binary's Go build environment. See the Developer documentation for the
  plugin-specific build contract.

## Next Steps

After building, follow [Using Binaries](/docs/installation/using-binaries) to configure and run Nauthilus.
