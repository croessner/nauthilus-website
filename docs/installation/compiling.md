---
title: Compiling
description: Compiling Nauthilus from source
keywords: [Source, Build, Compile]
sidebar_position: 2
---

# Compiling

This guide explains how to compile Nauthilus from source code. Follow these instructions if you want to build the application yourself instead of using pre-built binaries.

## Prerequisites

- Go compiler version 1.21 or later
- Git (to clone the repository)

## Getting the Source Code

Clone the repository using git:

```bash
git clone https://github.com/croessner/nauthilus.git
cd nauthilus
```

### Branch Selection

- The `main` branch is generally stable and receives merges from the `features` branch
- For production use, consider using a specific release tag:
  ```bash
  git checkout v1.x.x  # Replace with the desired version tag
  ```

## Building Nauthilus

### Basic Build

The simplest way to build Nauthilus:

```bash
go build -mod=vendor -o nauthilus .
```

### Using Make

Alternatively, you can use the provided Makefile:

```bash
make build
```

This will:
- Resolve dependencies
- Build the application with version information from git
- Place the binary in `nauthilus/bin/nauthilus`

### Additional Make Targets

- `make test`: Run tests
- `make race`: Run tests with race condition detection
- `make clean`: Remove previous build artifacts

## Build Tags

Build tags allow you to customize the compilation with additional features. Add them to your build command like this:

```bash
go build -mod=vendor -tags="tag1 tag2" -o nauthilus .
```

### Available Build Tags

#### hydra

Builds Nauthilus with Hydra/OIDC login/consent flows enabled. Also compiles the 2FA (TOTP) and WebAuthn frontend flows.

```bash
# Build with Hydra enabled
go build -mod=vendor -tags="hydra" -o nauthilus ./server

# Run tests with Hydra enabled
go test -tags hydra ./...
```

Without this tag, the binary excludes Hydra/OIDC code and related routes. The service-internal JWT authentication remains available in all builds.

#### dev

```bash
go build -mod=vendor -tags="dev" -o nauthilus .
```

The `dev` tag enables experimental features that are not yet fully implemented. This is primarily intended for developers working on Nauthilus.

#### register2fa

```bash
go build -mod=vendor -tags="register2fa" -o nauthilus .
```

The `register2fa` tag enables a registration endpoint for two-factor authentication, allowing you to add TOTP tokens to user accounts.

### Notes on 2FA/WebAuthn

- The 2FA (TOTP) and WebAuthn registration/UI flows are only compiled and registered when building with `-tags hydra`.
- OAuth2/OIDC configuration (the `oauth2` section in the config file) has effect only in hydra builds.

## Next Steps

After successfully building Nauthilus, follow the instructions on the [Using Binaries](/docs/installation/using-binaries) page to configure and run the application.
