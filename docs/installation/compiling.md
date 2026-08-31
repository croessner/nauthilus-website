---
title: Compiling
description: Compile Nauthilus from source with the supported Go toolchain
keywords: [Source, Build, Compile, Go, GOEXPERIMENT]
sidebar_position: 2
---

# Compiling

This guide explains how to compile Nauthilus from source instead of using a pre-built binary.

## Prerequisites

- Go 1.26 or later. The project CI and container build currently use Go 1.26.5.
- Git.
- A C toolchain when the selected target or native Go plugins require CGO.

Nauthilus uses the Go module path `github.com/croessner/nauthilus/v4` and the `runtimesecret` Go experiment. Use the
toolchain version declared by `go.mod` and keep `GOEXPERIMENT=runtimesecret` enabled for builds and tests.

Verify the local toolchain before building:

```bash
go version
GOEXPERIMENT=runtimesecret go env GOEXPERIMENT
```

## Get the Source

```bash
git clone https://github.com/croessner/nauthilus.git
cd nauthilus
```

The `main` branch is the current development line. For reproducible production builds, check out the exact release tag
you intend to deploy:

```bash
git fetch --tags
git checkout v4.x.x
```

Replace `v4.x.x` with an existing v4 release tag. The upcoming `v4.0.0-alpha.1` tag can be used only after it is published.

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
- `make guardrails`: run the repository's full local quality gate.
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

## Reproducibility Notes

- Keep the vendored dependency tree intact when using `-mod=vendor`.
- Use the same Go version, `GOEXPERIMENT`, build tags, module sources, operating system, architecture, and CGO mode when
  binary compatibility matters.
- A native Go plugin must match the host binary's Go build environment. See the Developer documentation for the
  plugin-specific build contract.

## Next Steps

After building, follow [Using Binaries](/docs/installation/using-binaries) to configure and run Nauthilus.
