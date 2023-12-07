---
title: Compiling
sidebar_position: 2
---
<!-- TOC -->
  * [Pre requirements](#pre-requirements)
  * [Building](#building)
<!-- TOC -->
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
go build -mod=vendor -ldflags="-s -w" -o nauthilus .
```

If everything went fine, follow the instructions found on the
page "[Using binaries](/docs/using-binaries)".
