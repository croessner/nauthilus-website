---
title: Includes
description: Split Nauthilus configuration into multiple files with required/optional and environment-specific includes
keywords: [Configuration, Includes, Env, Patch]
sidebar_position: 2
---

# Includes

Nauthilus supports top-level `includes` so you can split one large configuration into multiple files.

This is useful for:
- Shared base configuration plus environment-specific overlays
- Keeping secrets or local overrides in separate files
- Reusing common blocks across deployments

## Syntax

`includes` is a top-level section.

```yaml
includes:
  required:
    - path/to/file.yaml
  optional:
    - path/to/optional.yaml
  env:
    dev:
      required:
        - path/to/dev-required.yaml
      optional:
        - path/to/dev-optional.yaml
```

### Fields

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `includes.required` | `[]string` | Files that must exist and load successfully. Missing file causes startup/config-load error. |
| `includes.optional` | `[]string` | Files that are loaded when present. Missing files are ignored. |
| `includes.env` | `map[string]{required,optional}` | Additional includes selected by current environment name. |

Environment selection:
- Nauthilus uses top-level `env` in your config if set.
- If top-level `env` is not set, it falls back to environment variable `NAUTHILUS_ENV`.

## Path Resolution

- Relative include paths are resolved relative to the directory of the file that contains the `includes` entry.
- Absolute paths are supported.

## Merge Order and Precedence

Merge order is deterministic:
1. `includes.required` (in listed order)
2. `includes.optional` (in listed order)
3. `includes.env.<name>.required` (in listed order)
4. `includes.env.<name>.optional` (in listed order)
5. The current file itself

Conflict rule:
- Later values override earlier ones.
- Therefore, the current file has highest precedence.

After loading:
- Loader-only keys `includes`, `env`, and `patch` are removed from final runtime settings.

## Error Behavior

- Required include missing: error
- Optional include missing: ignored
- Include cycle detected: error
- Invalid `env` type (non-string): error

## How Includes Are Processed

For day-to-day operation, these are the important rules:

1. Nauthilus loads all include files first.
2. Then it applies settings from your main file.
3. If the same setting appears multiple times, the last value wins.
4. At the end, optional `patch` entries are applied.

Practical consequence:
- Your main file is always the strongest override point.

### Good to know

- Includes can include other files.
- Circular includes are not allowed (for example, `a.yaml` includes `b.yaml` and `b.yaml` includes `a.yaml`).
- `optional` means only "missing file is okay".
- Syntax errors or invalid values still stop startup, even for optional files.

### Includes and `patch`

If you use `patch`, it is applied after all files were merged.

This allows targeted final adjustments without duplicating full blocks, for example:
- add one extra LDAP search entry
- replace one nested value only for `dev`
- remove keys from a map in a local overlay

## Complete Behavior Example

`nauthilus.yaml`:

```yaml
env: dev
includes:
  required:
    - base.yaml
  env:
    dev:
      optional:
        - dev.yaml

server:
  log:
    level: info
```

`base.yaml`:

```yaml
server:
  log:
    level: warn
ldap:
  config:
    lookup_pool_size: 5
```

`dev.yaml`:

```yaml
patch:
  - op: replace
    path: ldap.config.lookup_pool_size
    value: 12
server:
  log:
    color: true
```

Final effective settings:
- `server.log.level = info` (main file wins over includes)
- `server.log.color = true` (set by `dev.yaml`)
- `ldap.config.lookup_pool_size = 12` (changed by patch)

## Example 1: Base + Site Override

`nauthilus.yaml`:

```yaml
includes:
  required:
    - config/base.yaml
    - config/site.yaml

server:
  instance_name: "mail-prod-a"
```

`config/base.yaml`:

```yaml
server:
  address: "[::]:9443"
  max_concurrent_requests: 200
```

`config/site.yaml`:

```yaml
server:
  max_concurrent_requests: 400
```

Effective result:
- `server.address = "[::]:9443"` (from `base.yaml`)
- `server.max_concurrent_requests = 400` (site override)
- `server.instance_name = "mail-prod-a"` (main file override/highest precedence)

## Example 2: Environment-Specific Includes

`nauthilus.yaml`:

```yaml
env: dev
includes:
  required:
    - config/common.yaml
  env:
    dev:
      optional:
        - config/dev.yaml
    prod:
      required:
        - config/prod.yaml
```

Behavior:
- With `env: dev`, only `config/dev.yaml` from `includes.env.dev.*` is considered.
- With `env: prod`, `config/prod.yaml` becomes mandatory.
- If `env` is omitted in the file, `NAUTHILUS_ENV` is used.

## Example 3: Optional Local Override

```yaml
includes:
  required:
    - config/base.yaml
  optional:
    - config/local.yaml
```

Typical use:
- Commit `config/base.yaml` to Git.
- Keep `config/local.yaml` untracked for machine-local overrides.
- Missing `config/local.yaml` does not fail startup.
