---
title: Environment, Validation, and Dumps
description: Environment variable mapping, validation, and configuration dump modes
keywords: [Configuration, Environment, Validation, Dump]
sidebar_position: 2
---

# Environment, Validation, and Dumps

This page documents how the current config-v2 surface maps to environment variables, how validation behaves, and how to use the built-in dump modes.

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
| `runtime.servers.grpc.authority.address` | `NAUTHILUS_RUNTIME_SERVERS_GRPC_AUTHORITY_ADDRESS` |
| `runtime.servers.grpc.authority.tls.min_tls_version` | `NAUTHILUS_RUNTIME_SERVERS_GRPC_AUTHORITY_TLS_MIN_TLS_VERSION` |
| `runtime.clients.grpc.nauthilus_authorities.primary.address` | `NAUTHILUS_RUNTIME_CLIENTS_GRPC_NAUTHILUS_AUTHORITIES_PRIMARY_ADDRESS` |
| `runtime.clients.grpc.nauthilus_authorities.primary.caller_auth.oidc_bearer.client_id` | `NAUTHILUS_RUNTIME_CLIENTS_GRPC_NAUTHILUS_AUTHORITIES_PRIMARY_CALLER_AUTH_OIDC_BEARER_CLIENT_ID` |
| `runtime.timeouts.lua_script` | `NAUTHILUS_RUNTIME_TIMEOUTS_LUA_SCRIPT` |
| `observability.log.level` | `NAUTHILUS_OBSERVABILITY_LOG_LEVEL` |
| `storage.redis.primary.address` | `NAUTHILUS_STORAGE_REDIS_PRIMARY_ADDRESS` |
| `auth.request.headers.username` | `NAUTHILUS_AUTH_REQUEST_HEADERS_USERNAME` |
| `auth.backchannel.basic_auth.username` | `NAUTHILUS_AUTH_BACKCHANNEL_BASIC_AUTH_USERNAME` |
| `auth.backends.remote.default.authority` | `NAUTHILUS_AUTH_BACKENDS_REMOTE_DEFAULT_AUTHORITY` |
| `auth.backends.remote.default.allowed_operations` | `NAUTHILUS_AUTH_BACKENDS_REMOTE_DEFAULT_ALLOWED_OPERATIONS` |
| `identity.frontend.assets.html_static_content_path` | `NAUTHILUS_IDENTITY_FRONTEND_ASSETS_HTML_STATIC_CONTENT_PATH` |
| `identity.oidc.issuer` | `NAUTHILUS_IDENTITY_OIDC_ISSUER` |

Use environment variables primarily for:

- deployment-specific values
- secrets
- containerized setups

## Loader-Only Roots

These top-level keys are loader mechanics, not runtime roots:

- `includes`
- `env`
- `patch`

They are processed before the final runtime configuration is built.

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

This prints only values that differ from defaults after includes, environment overrides, and patches have been applied.

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
