---
title: Includes
description: Split Nauthilus configuration across multiple files
keywords: [Configuration, Includes, Env, Patch]
sidebar_position: 4
---

# Includes

Nauthilus supports top-level `includes` so you can split one large configuration into multiple files.

This is especially useful with config v2, because it lets you keep major sections such as `runtime`, `storage`, `auth`, and `identity` in separate files while preserving one canonical effective configuration.

## Syntax

```yaml
includes:
  required:
    - config/base.yaml
  optional:
    - config/local.yaml
  env:
    dev:
      optional:
        - config/dev.yaml
    prod:
      required:
        - config/prod.yaml
```

## Fields

| Field | Type | Meaning |
|---|---|---|
| `includes.required` | `[]string` | files that must exist and load successfully |
| `includes.optional` | `[]string` | files that are loaded when present |
| `includes.env` | `map[string]{required,optional}` | extra includes selected by environment |

Environment selection:

- first from top-level `env` in the config file
- otherwise from `NAUTHILUS_ENV`

## Merge Order

Merge order is deterministic:

1. `includes.required`
2. `includes.optional`
3. `includes.env.<name>.required`
4. `includes.env.<name>.optional`
5. the current file itself
6. optional `patch` operations

Later values win.

## Example

`nauthilus.yml`:

```yaml
env: dev

includes:
  required:
    - config/runtime.yaml
    - config/storage.yaml
    - config/auth.yaml
  env:
    dev:
      optional:
        - config/dev.yaml

observability:
  log:
    level: "info"
```

`config/runtime.yaml`:

```yaml
runtime:
  servers:
    http:
      address: "[::]:9443"
```

`config/storage.yaml`:

```yaml
storage:
  redis:
    primary:
      address: "redis:6379"
```

`config/dev.yaml`:

```yaml
patch:
  - op: replace
    path: observability.log.level
    value: debug
```

Effective result:

- `runtime.servers.http.address = "[::]:9443"`
- `storage.redis.primary.address = "redis:6379"`
- `observability.log.level = "debug"`

## Operational Notes

- relative include paths are resolved relative to the file that declares them
- include cycles are rejected
- missing required files are fatal
- missing optional files are ignored
- syntax or validation errors in included files are still fatal
