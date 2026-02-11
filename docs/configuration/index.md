---
title: Configuration File
description: Details about the Nauthilus configuration file format and structure
keywords: [Configuration, YAML, File]
sidebar_position: 1
---

# Configuration File

Nauthilus uses a configuration file to define its behavior. By default, the configuration is in YAML format, but other formats like JSON, TOML, etc. are also supported. This document explains the general structure and format of this file.

## File Format

By default, the configuration file is written in YAML format. YAML is a human-readable data serialization standard that is commonly used for configuration files. The file should have a `.yml` extension.

Nauthilus also supports other configuration formats such as JSON, TOML, HCL, and INI. You can specify the format using the `-config-format` command-line flag.

## File Location

By default, Nauthilus looks for its configuration file named `nauthilus.yml` in the following locations:

- Current directory
- `$HOME/.nauthilus`
- `/etc/nauthilus/`
- `/usr/local/etc/nauthilus/`

The first file found in these locations will be used.

_Search order changed in version 1.7.9_

## Command-Line Options

Nauthilus supports the following command-line options:

- `-config <path>`: Specify a custom path to the configuration file. This overrides the default search locations.
- `-config-format <format>`: Specify the configuration file format (yaml, json, toml, etc.). Default is "yaml".
- `-version`: Print the version information and exit.

_New in version 1.7.9_

## Environment Variables

Some configuration options can be set using environment variables. These are typically used for settings that don't change frequently or that might contain sensitive information like passwords. See the [Reference](/docs/configuration/reference) document for details on available environment variables.

## Structure

The configuration file contains several main sections, where each is responsible for a particular category of runtime behavior.

### Features

* realtime\_blackhole\_lists
* cleartext\_networks
* relay\_domains
* brute\_force
* lua
* backend\_server\_monitoring

### Experimental Features

Nauthilus includes several experimental features that are under active development:

* **Machine Learning Enhanced Brute Force Detection**: A neural network approach to enhance the rule-based brute force detection system. This feature is configured in the `brute_force::neural_network` section. **Deprecated Feature**: This functionality has been dropped in version 1.8.0 and is no longer available.

To enable experimental machine learning features, set the `NAUTHILUS_EXPERIMENTAL_ML` environment variable to `true`.

### General configuration settings

* server
* ldap
* lua

Each section has individual subsections. See details in the specific documentation pages. If you do not require some sections, please do not include it into the configuration file.

## Configuration Sections

The configuration is divided into the following main sections:

- [Server Configuration](server-configuration.md) - Core server settings including address, TLS, logging, Redis, and more
- [Realtime Blackhole Lists](realtime-blackhole-lists.md) - Configuration for RBL checks
- [Cleartext Networks](cleartext-networks.md) - Settings for allowing unencrypted connections
- [Relay Domains](relay-domains.md) - Domain validation for email addresses
- [Backend Server Monitoring](backend-server-monitoring.md) - Health checks for backend servers
- [Brute Force Protection](brute-force.md) - Settings for brute force attack prevention
- [Password Nonce](password-nonce.md) - Password hashing configuration
- [Identity Provider](idp/index.md) - Native OIDC (Authorization Code) and SAML2
- [Database Backends](database-backends/index.md) - Configuration for authentication backends
  - [Protocols](database-backends/protocols.md) - Protocol-specific settings
  - [Macros](database-backends/macros.md) - Macro definitions for queries
  - [Cache Namespaces](database-backends/cache-namespaces.md) - Redis cache namespace configuration
  - [Encrypted Passwords](database-backends/encrypted-passwords.md) - Supported password encryption formats
  - [LDAP](database-backends/ldap.md) - LDAP backend configuration
  - [Lua](database-backends/lua.md) - Lua backend configuration
- [Full Example](full-example.md) - Complete configuration example

## Example

Here's a minimal example of a Nauthilus configuration file:

```yaml
server:
  address: "127.0.0.1:9080"
  log:
    level: "info"
  redis:
    master:
      address: "127.0.0.1:6379"

ldap:
  config:
    server_uri:
      - "ldap://127.0.0.1:389"
    bind_dn: "cn=admin,dc=example,dc=com"
    bind_pw: "password"
    lookup_pool_size: 8
    auth_pool_size: 8
  search:
    - protocol:
        - "imap"
      cache_name: "imap"
      base_dn: "ou=people,dc=example,dc=com"
      filter:
        user: "(&(objectClass=inetOrgPerson)(uid=%L{user}))"
      mapping:
        account_field: "uid"
      attribute:
        - "uid"
        - "userPassword"
```

For a complete example with all available options, see the [Full Example](full-example.md) page.

## Reloading Configuration

You can reload the configuration file without restarting Nauthilus by sending a HUP signal to the process:

```bash
kill -HUP $(pidof nauthilus)
```

This will stop LDAP connections, reload the configuration file, and restart the database connections. The main web server process will remain running.

If you change settings related to the web server itself, you must first reload the configuration file and then send a second signal to restart the server process:

```bash
kill -HUP $(pidof nauthilus)
kill -SIGUSR1 $(pidof nauthilus)
```

:::::warning
Changing environment variables require a full restart of the service, as they cannot be reloaded by sending signals.
::::

## Validation

Nauthilus validates the configuration file when it starts up and will report any errors it finds. Make sure to check the logs if Nauthilus fails to start after changing the configuration.
