---
title: Configuration Migration
description: Migration boundary from the v3 config-v2 layout to the v4 top-level Policy model
keywords: [Configuration, Migration, v4, Policy]
sidebar_position: 6
---

# Configuration Migration

The v3 config-v2 layout remains the baseline for runtime, observability, storage, authentication mechanisms, and identity configuration. Nauthilus v4 introduces an additional hard cut for decision configuration: the former `auth.policy` subtree is removed and top-level `policy` is the sole authority.

There is no supported configuration converter, startup translation, offline translator, dual read, or fallback compiler. Migrate manually and validate the complete candidate before deployment.

## What stays outside Policy

These existing top-level owners remain distinct:

- `runtime`: inbound servers, outbound clients, and shared process settings
- `observability`: logs, profiling, tracing, and metrics
- `storage`: Redis and cache/storage behavior
- `auth`: request handling, backends, controls, services, and backchannel authentication
- `identity`: frontend, MFA, OIDC, SAML, and sessions
- `plugins`: native plugin loading and module configuration

## What moves to top-level Policy

Move the complete v3 decision model together:

- decision targets and report settings
- localization and condition sets
- fact-source allowlists
- Lua and plugin providers
- Lua effects
- registry-script schema contributions
- provider scheduling and checkpoint ordering
- policy rules and policy-set imports
- Generic Policy API caller profiles, limits, and transports

Do not keep an empty or partial `auth.policy` block. Old-root and mixed-root inputs are both rejected.

## Required migration sequence

1. Keep non-Policy config-v2 roots at their existing canonical owners.
2. Manually map every removed `auth.policy` field using the [field-complete migration contract](policy-configuration-migration.md).
3. Replace v3 stages with exact checkpoint ownership.
4. Replace `type` plus `config_ref` with the documented qualified provider `use` identity.
5. Qualify `standard_auth` as `authn/standard_auth`.
6. Configure Policy and backchannel credentials as separate resource families.
7. Validate the complete candidate, canonical dump, provider/effect resolution, and runtime routes before cutover.

The [v4 migration landing](v4-migration.md) also covers the Go module and native plugin rebuild boundary.
