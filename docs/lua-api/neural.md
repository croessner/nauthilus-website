---
title: Neural
description: Historical neural-network page retained as a deprecation notice
keywords: [Lua, Neural, Deprecated]
sidebar_position: 13
---

# Neural

The neural-network feature described by older Nauthilus documentation is not part of the current public configuration model.

## Status

- the historical brute-force neural-network configuration is removed from current docs
- legacy examples that referenced Lua hooks for neural training or feedback are obsolete
- do not build new deployments around those old `lua.custom_hooks` examples

## Current Recommendation

Use the supported controls and services instead:

- `auth.controls.brute_force`
- `auth.controls.lua`
- `auth.services.backend_health_checks`

If you are migrating an older setup, treat previous neural-related docs as historical material rather than current configuration guidance.
