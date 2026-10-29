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
| `runtime.servers.grpc.authority.backend_refs.enabled` | `NAUTHILUS_RUNTIME_SERVERS_GRPC_AUTHORITY_BACKEND_REFS_ENABLED` |
| `runtime.servers.grpc.authority.tls.min_tls_version` | `NAUTHILUS_RUNTIME_SERVERS_GRPC_AUTHORITY_TLS_MIN_TLS_VERSION` |
| `runtime.servers.grpc.authority.keep_alive.max_connection_age` | `NAUTHILUS_RUNTIME_SERVERS_GRPC_AUTHORITY_KEEP_ALIVE_MAX_CONNECTION_AGE` |
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

## File Artifacts and Symbolic Links

Files referenced by the configuration, such as TLS certificates and keys, LDAP and Lua files, IdP keys and
certificates, frontend `*.html` templates, Lua package modules, and plugin artifacts, are captured as a validated
snapshot at startup and reload. Such a file must be a regular file. A symbolic link is accepted only in the Kubernetes
projected-volume layout used by ConfigMap and Secret mounts: the file is a relative link to `..data/<same name>`, and
its resolved target stays inside the mount directory. Directory entries whose names start with `..` are skipped when
Lua package directories are scanned, so the hidden timestamped directories of a projected volume are not loaded twice.

Every other symbolic link is rejected. The frontend asset directories (`css`, `js`, `img`, and `fonts` next to the
templates) must not contain symbolic links at all, so do not serve them from a projected volume. See
[Kubernetes ConfigMap and Secret Mounts](../installation/docker.md#kubernetes-configmap-and-secret-mounts).

## Native Plugin Configuration

`plugins` is a normal top-level Config v2 section, not a loader-only root. Its shared fields configure artifact verification and module instances. The contents of each `plugins.modules[].config` mapping are deliberately opaque to the Nauthilus schema because the selected plugin owns their types and defaults.

Opaque plugin config is not traversed by the normal config-dump schema and is omitted from plugin discovery output. Validate it by loading the corresponding module: the public plugin `ConfigView.Decode` path is strict and rejects unknown keys or incompatible types during registration/reload.

`plugins.modules[].allow_capabilities` accepts `credentials`, `mail`, and `password_hash`; other values fail validation.

`plugins.opaque_identifier_tagger` configures the host-owned keys that plugins use to derive opaque identifiers. It
declares 1 to 32 unique `scopes`, each with an `active` key and an optional `previous` key for rotation:

```yaml
plugins:
  opaque_identifier_tagger:
    scopes:
      - scope: "reputation_subject"
        active:
          version: "v2"
          secret_ref:
            file: "/etc/nauthilus/secrets/reputation-subject-v2.key"
        previous:
          version: "v1"
          secret_ref:
            file: "/etc/nauthilus/secrets/reputation-subject-v1.key"
```

`secret_ref.file` must be an absolute, clean path to a file that contains exactly 32 key bytes. `previous` must use a
different `version` and a different file than `active`. The key files are part of the validated file-artifact snapshot
described above, so they may be mounted from a Kubernetes Secret. The scope names a plugin expects are documented by
that plugin.

Prefer YAML/includes or a mounted plugin-owned secret file for module config. Environment-variable derivation is well suited to fixed canonical scalar paths, but not to arbitrary keys inside a module list's opaque mapping. See [Native Go Plugins](native-go-plugins.md).

## Validation

Validate a configuration file with:

```bash
nauthilus --config /etc/nauthilus/nauthilus.yml --config-check
```

Behavior:

- exit code `0`: configuration is valid
- exit code `1`: configuration is invalid

Validation also reports warnings that keep a configuration loadable, for example a `cache` entry before a native
backend plugin that has not opted into the positive password cache (see
[Native Go Plugins](native-go-plugins.md#positive-password-cache-for-backend-modules)).

Validation errors are reported with canonical config-v2 paths. Unknown keys are not translated from Go field names anymore; the message points directly to the documented YAML surface.

## Dump Modes

Nauthilus provides a `postconf`/`doveconf`-style view of the effective schema.

### Print Defaults

```bash
nauthilus -d
```

This prints the canonical default configuration as sorted `path = value` lines.

The output is a dump of the built-in defaults, not a loadable profile. Secrets such as `storage.redis.password_nonce`
and `storage.redis.encryption_secret` print empty, and LDAP pool sizes such as `auth_pool_size` and
`lookup_pool_size` print as `0`; set them before the output can be used as a configuration. Runtime defaults that the
schema does not carry are included, for example `storage.redis.identity_cache.ttl = 1m`,
`policy.runtime.post_actions.workers`, `policy.runtime.post_actions.queue_capacity`,
`policy.runtime.authn.max_concurrency`, and `policy.runtime.authn.requests_per_second` (see
[Identity Lookup Cache](server-configuration.md#identity-lookup-cache) and
[Runtime capacity](auth-policy.md#runtime-capacity)).

The dump prints the `storage.redis.sentinels` block with empty values. Such an all-empty block is treated as "Sentinel
not configured" when it is loaded; once any Sentinel field is set, `master` and at least one entry in `addresses` are
required.

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
- `identity.oidc.dynamic_client_registration.source_hmac_key`
- `identity.saml.key`

File paths such as `client_private_key_file` and `static_token_file` are not themselves redacted secrets, but the files they point to must be readable only by trusted Nauthilus runtime users.

## Operational Workflow

Recommended operator workflow:

1. validate with `--config-check`
2. inspect defaults with `-d`
3. inspect effective deviations with `-n`
4. use `-P` only in trusted environments

This gives you a stable, canonical view of the current configuration surface without relying on internal Go struct names.

For split edge/authority deployments, validate the authority config and every edge config separately. Confirm that the authority explicitly enables `runtime.servers.grpc.authority.backend_refs`, the edge config has only remote backends in `auth.backends.order`, authority-client caller auth is enabled, and edge Redis and authority Redis addresses are different. Backend references default to disabled and enabling them requires authority Redis.
