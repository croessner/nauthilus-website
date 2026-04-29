---
title: Configuration File
description: Current Nauthilus configuration model and navigation
keywords: [Configuration, YAML, File, v2]
sidebar_position: 1
---

# Configuration File

Nauthilus uses a canonical config-v2 structure. The file is usually written in YAML, but other input formats supported by Viper still work when selected explicitly with `--config-format`.

## Current Root Structure

The current configuration file is organized into these root sections:

- `runtime`
- `observability`
- `storage`
- `auth`
- `identity`

This is a breaking redesign. Legacy root sections such as `server`, `ldap`, `lua`, `idp`, `realtime_blackhole_lists`, `relay_domains`, `brute_force`, `backend_server_monitoring`, and `cleartext_networks` are not part of the current public model anymore.

## File Formats

YAML is the recommended format. JSON, TOML, HCL, and INI remain available through `--config-format`.

## File Location

By default, Nauthilus looks for `nauthilus.yml` in:

- current directory
- `$HOME/.nauthilus`
- `/etc/nauthilus`
- `/usr/local/etc/nauthilus`

Use `--config <path>` to point to a specific file.

## Command-Line Options

Relevant configuration-related flags:

- `--config <path>`: set the config file path
- `--config-format <format>`: set the file format
- `--config-check`: validate and exit
- `-d`: print canonical defaults
- `-n`: print canonical non-default values from the loaded config
- `-P`: print sensitive values in dump output

Important behavior:

- `-d` and `-n` are mutually exclusive.
- Without `-P`, secrets and other sensitive values are printed as `***REDACTED***`.
- Dump output uses canonical v2 paths.
- Legacy monolithic YAML files can be rewritten with `python3 scripts/convert-config-v1-to-v2.py`.

## Configuration Errors

Unknown keys, type errors, and validation failures are now reported against canonical config paths derived from `mapstructure` tags. In practice, that means the error messages refer to the same keys you see in the documentation and YAML examples.

Examples of canonical paths:

- `runtime.listen.address`
- `storage.redis.primary.address`
- `auth.controls.brute_force.protocols`
- `identity.frontend.assets.html_static_content_path`

## Main Sections

- [Includes](includes.md): split config across multiple files
- [Runtime, Observability, and Storage](server-configuration.md): process, listeners, HTTP behavior, logs, tracing, metrics, Redis
- [RBL Control](realtime-blackhole-lists.md): `auth.controls.rbl`
- [TLS Enforcement / Cleartext Allowlist](cleartext-networks.md): `auth.controls.tls_encryption.allow_cleartext_networks`
- [Relay Domains](relay-domains.md): `auth.controls.relay_domains`
- [Backend Health Checks](backend-server-monitoring.md): `auth.services.backend_health_checks`
- [Brute Force Protection](brute-force.md): `auth.controls.brute_force`
- [Password Nonce](password-nonce.md): `storage.redis.password_nonce`
- [Environment, Validation, and Dumps](reference.md)
- [Database Backends](database-backends/index.md)
- [Identity](idp/index.md)
- [Full Configuration Example](full-example.md)
- [Config v2 Migration Guide](../guides/config-v2-migration.md)

## Minimal Example

```yaml
runtime:
  listen:
    address: "127.0.0.1:9080"

observability:
  log:
    level: "info"

storage:
  redis:
    primary:
      address: "127.0.0.1:6379"
    password_nonce: "replace-with-a-long-random-string"

auth:
  backends:
    order:
      - cache
      - ldap
    ldap:
      default:
        server_uri:
          - "ldapi:///"
      search: []
```

## Reloading

Nauthilus still supports reloading configuration via signals. The exact semantics did not change with config v2:

- send `HUP` to reload configuration and rebuild dependent resources
- send `SIGUSR1` after that when runtime listener settings require a server restart

Environment variables still require a full process restart.
