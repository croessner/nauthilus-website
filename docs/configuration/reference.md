---
title: Environment, Validation, and Dumps
description: Environment variable mapping, validation, and configuration dump modes
keywords: [Configuration, Environment, Validation, Dump]
sidebar_position: 2
---

# Environment, Validation, and Dumps

This page documents how the current config-v2 surface maps to environment variables, how value placeholders work, how validation behaves, and how to use the built-in dump modes.

## Environment Variables

All environment variables are prefixed with `NAUTHILUS_`.

For normal configuration values, derive the variable name from the canonical config path:

1. start with the documented YAML path
2. replace `.` with `_`
3. convert to upper case
4. prepend `NAUTHILUS_`

Examples:

| YAML path | Environment variable |
|---|---|
| `runtime.servers.http.address` | `NAUTHILUS_RUNTIME_SERVERS_HTTP_ADDRESS` |
| `runtime.servers.http.openapi_validation.enabled` | `NAUTHILUS_RUNTIME_SERVERS_HTTP_OPENAPI_VALIDATION_ENABLED` |
| `runtime.servers.http.openapi_validation.operations` | `NAUTHILUS_RUNTIME_SERVERS_HTTP_OPENAPI_VALIDATION_OPERATIONS` |
| `runtime.servers.grpc.authority.address` | `NAUTHILUS_RUNTIME_SERVERS_GRPC_AUTHORITY_ADDRESS` |
| `runtime.servers.grpc.authority.tls.min_tls_version` | `NAUTHILUS_RUNTIME_SERVERS_GRPC_AUTHORITY_TLS_MIN_TLS_VERSION` |
| `runtime.clients.grpc.nauthilus_authorities.primary.address` | `NAUTHILUS_RUNTIME_CLIENTS_GRPC_NAUTHILUS_AUTHORITIES_PRIMARY_ADDRESS` |
| `runtime.clients.grpc.nauthilus_authorities.primary.caller_auth.oidc_bearer.client_id` | `NAUTHILUS_RUNTIME_CLIENTS_GRPC_NAUTHILUS_AUTHORITIES_PRIMARY_CALLER_AUTH_OIDC_BEARER_CLIENT_ID` |
| `runtime.timeouts.lua_script` | `NAUTHILUS_RUNTIME_TIMEOUTS_LUA_SCRIPT` |
| `observability.log.level` | `NAUTHILUS_OBSERVABILITY_LOG_LEVEL` |
| `observability.metrics.endpoint_auth.basic.enabled` | `NAUTHILUS_OBSERVABILITY_METRICS_ENDPOINT_AUTH_BASIC_ENABLED` |
| `observability.metrics.endpoint_auth.basic.username` | `NAUTHILUS_OBSERVABILITY_METRICS_ENDPOINT_AUTH_BASIC_USERNAME` |
| `observability.metrics.endpoint_auth.basic.password` | `NAUTHILUS_OBSERVABILITY_METRICS_ENDPOINT_AUTH_BASIC_PASSWORD` |
| `storage.redis.primary.address` | `NAUTHILUS_STORAGE_REDIS_PRIMARY_ADDRESS` |
| `auth.request.headers.username` | `NAUTHILUS_AUTH_REQUEST_HEADERS_USERNAME` |
| `auth.pipeline.master_user.user_format` | `NAUTHILUS_AUTH_PIPELINE_MASTER_USER_USER_FORMAT` |
| `auth.backchannel.basic_auth.username` | `NAUTHILUS_AUTH_BACKCHANNEL_BASIC_AUTH_USERNAME` |
| `auth.backends.remote.default.authority` | `NAUTHILUS_AUTH_BACKENDS_REMOTE_DEFAULT_AUTHORITY` |
| `auth.backends.remote.default.allowed_operations` | `NAUTHILUS_AUTH_BACKENDS_REMOTE_DEFAULT_ALLOWED_OPERATIONS` |
| `identity.frontend.assets.html_static_content_path` | `NAUTHILUS_IDENTITY_FRONTEND_ASSETS_HTML_STATIC_CONTENT_PATH` |
| `identity.oidc.issuer` | `NAUTHILUS_IDENTITY_OIDC_ISSUER` |

Use environment variables primarily for:

- deployment-specific values
- secrets
- containerized setups

These variables are Viper overrides. They replace the effective value of the matching canonical configuration path after the file tree has been loaded.

## Value Placeholders

String values in configuration files may reference operating-system environment variables with `${NAME}` placeholders:

```yaml
storage:
  redis:
    primary:
      address: "${REDIS_ADDRESS}"
      password: "${REDIS_PASSWORD}"

auth:
  backends:
    ldap:
      default:
        server_uri:
          - "ldap://${LDAP_HOST}:389"
        bind_pw: "${LDAP_BIND_PASSWORD}"
```

`NAME` must start with a letter or `_` and may then contain letters, digits, or `_`. Placeholders are expanded only inside string values, including values nested in maps and lists.

Expansion happens after root config, includes, and patch `value` payloads have been merged, and before strict decoding and validation. Missing variables are fatal during startup and `--config-check`; the error includes the affected config path and the missing variable name. Expanded secret values are not printed in those errors.

Built-in placeholders are available even when the OS environment does not define them:

| Placeholder | Non-container default | Docker image default |
|---|---|---|
| `${NAUTHILUS_CONF_DIR}` | `/etc/nauthilus` | `/etc/nauthilus` |
| `${NAUTHILUS_PLUGINS_DIR}` | `/usr/local/share/nauthilus/lua-plugins.d` | `/usr/app/lua-plugins.d` |

An OS environment variable with the same name overrides the compiled built-in value.

Use `$${NAME}` when a literal `${NAME}` string should remain in the final configuration.

### Placeholders versus `NAUTHILUS_*` Overrides

Value placeholders and `NAUTHILUS_*` overrides are different mechanisms:

| Mechanism | Example | Scope | Precedence |
|---|---|---|---|
| Value placeholder | `address: "${REDIS_ADDRESS}"` | interpolates a string value inside the loaded file tree | happens before Viper environment overrides |
| Viper override | `NAUTHILUS_STORAGE_REDIS_PRIMARY_ADDRESS=redis:6379` | replaces the canonical config path `storage.redis.primary.address` | wins over the expanded file value |

This means a file value such as `storage.redis.primary.address: "${REDIS_ADDRESS}"` can still be overridden by `NAUTHILUS_STORAGE_REDIS_PRIMARY_ADDRESS`.

Placeholders do not expand map keys. They also do not expand `includes` paths, patch `path` fields, or YAML structure. If you need a dynamic value inside a map, keep the key static and put the placeholder in the value.

## Loader-Only Roots

These top-level keys are loader mechanics, not runtime roots:

- `includes`
- `env`
- `patch`

They are processed before the final runtime configuration is built. Include paths and patch paths are loader controls and are not environment-template strings; final values produced by included files and patch payloads are expanded.

## Validation

Validate a configuration file with:

```bash
nauthilus --config /etc/nauthilus/nauthilus.yml --config-check
```

Behavior:

- exit code `0`: configuration is valid
- exit code `1`: configuration is invalid

Validation errors are reported with canonical config-v2 paths. Unknown keys are not translated from Go field names anymore; the message points directly to the documented YAML surface.

## Dump Modes

Nauthilus provides a `postconf`/`doveconf`-style view of the effective schema.

### Print Defaults

```bash
nauthilus -d
```

This prints the canonical default configuration as sorted `path = value` lines.

### Print Non-Defaults

```bash
nauthilus -n --config /etc/nauthilus/nauthilus.yml
```

This prints only values that differ from defaults after includes, patches, value expansion, and environment overrides have been applied.

### Print Sensitive Values

By default, dump output redacts sensitive values:

```bash
nauthilus -n --config /etc/nauthilus/nauthilus.yml
```

To print them explicitly:

```bash
nauthilus -n -P --config /etc/nauthilus/nauthilus.yml
```

Without `-P`, sensitive values are rendered as:

```text
***REDACTED***
```

## Typical Sensitive Paths

Examples of values redacted by default:

- `storage.redis.password_nonce`
- `storage.redis.encryption_secret`
- `observability.metrics.endpoint_auth.basic.password`
- `runtime.clients.grpc.nauthilus_authorities.<name>.caller_auth.basic_auth.password`
- `runtime.clients.grpc.nauthilus_authorities.<name>.caller_auth.oidc_bearer.client_secret`
- `auth.request.headers.password`
- `auth.request.headers.password_encoded`
- `auth.backends.ldap.default.bind_pw`
- `identity.saml.key`

File paths such as `client_private_key_file` and `static_token_file` are not themselves redacted secrets, but the files they point to must be readable only by trusted Nauthilus runtime users.

## Operational Workflow

Recommended operator workflow:

1. validate with `--config-check`
2. inspect defaults with `-d`
3. inspect effective deviations with `-n`
4. use `-P` only in trusted environments

This gives you a stable, canonical view of the current configuration surface without relying on internal Go struct names.

For split edge/authority deployments, validate the authority config and every edge config separately. Confirm that the edge config has only remote backends in `auth.backends.order`, that authority-client caller auth is enabled, and that edge Redis and authority Redis addresses are different.
