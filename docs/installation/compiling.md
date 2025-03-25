---
title: Compiling
description: Compiling Nauthilus from source
keywords: [Source, Build, Compile]
sidebar_position: 2
---

# Compiling

If you want to compile the source code by yourself, follow these steps.

## Pre requirements

You will need the Go compiler at version 1.21 or later.

You can clone the repository

using git:

```
git clone https://github.com/croessner/nauthilus.git
```

The "main" branch *should* mostly be stable, as it gets merges from the "features" branch. If you require stable
packages, use the binaries provided with each release or checkout the corresponding git tag!

## Building

```
go build -mod=vendor -o nauthilus .
```

If everything went fine, follow the instructions found on the
page "[Using binaries](/docs/installation/using-binaries)".

## Build tags

Tags can be added to the build command like -tags="tag1 tag2 ...tagN".

### dev

If you add **dev** to the build tags, the built will contain experimental, not yet fully implemented code. This setting is mainly for developers.

### register2fa

If you require a registration endpoint for two-factor-authentication, which will enable you to add a TOTP token to your users accounts, you cann add this tag.

