---
title: Getting started
description: A comprehensive guide to deploying and configuring Nauthilus
keywords: [Quickstart, Setup, Configuration, Authentication]
sidebar_position: 3
---

# Getting Started with Nauthilus

This guide will help you understand, deploy, and configure Nauthilus for your environment.

## What is Nauthilus?

Nauthilus is a universal authentication and authorization platform written in Go. It serves as a central hub for handling various authentication requests from different services such as:

- Mail servers (SMTP, IMAP, POP3)
- Web applications via OAuth2/OpenID Connect
- Custom applications through its flexible API

Key features include:

- Multiple authentication backends (LDAP, Lua scripts)
- Redis-based caching for performance
- Brute force attack protection
- Realtime blackhole list (RBL) checking
- Two-factor authentication support
- OAuth2/OpenID Connect integration
- Extensibility through Lua scripts

## Prerequisites

Before deploying Nauthilus, ensure you have:

- A system with Docker installed (for containerized deployment)
- Redis server (standalone, master-replica, sentinel, or cluster)
- Authentication backend (LDAP server or Lua scripts)
- Basic understanding of YAML configuration

## Deployment Options

### Docker Deployment (Recommended)

1. **Create a Docker Compose File**

   Create a `docker-compose.yml` file with Nauthilus and Redis:

   ```yaml
   version: '3'

   services:
     nauthilus:
       image: nauthilus/nauthilus:latest
       ports:
         - "9443:9443"
       volumes:
         - ./config:/etc/nauthilus
       environment:
         - TZ=UTC
       depends_on:
         - redis

     redis:
       image: redis:alpine
       ports:
         - "6379:6379"
       volumes:
         - redis-data:/data
       command: redis-server --appendonly yes

   volumes:
     redis-data:
   ```

2. **Create Configuration Directory**

   ```bash
   mkdir -p config
   ```

3. **Create Configuration File**

   Create `config/nauthilus.yml` with your configuration (see example below).

4. **Start the Services**

   ```bash
   docker-compose up -d
   ```

### Manual Installation

For manual installation, refer to the project documentation or build from source:

1. Clone the repository
2. Build the binary
3. Configure the service
4. Set up as a system service

## Basic Configuration

Create a minimal `nauthilus.yml` configuration file:

```yaml
server:
  address: "0.0.0.0:9443"  # Listen on all interfaces
  log:
    level: "info"
  redis:
    master:
      address: "redis:6379"  # Use "localhost:6379" for non-Docker setup
    password_nonce: "generate-a-random-string-here"
    pool_size: 10
    positive_cache_ttl: 3600s
    negative_cache_ttl: 7200s
  backends:
    - cache
    - ldap  # Or "lua" if using Lua backend

# LDAP Backend Configuration (if using LDAP)
ldap:
  config:
    server_uri: "ldap://ldap-server:389"
    bind_dn: "cn=admin,dc=example,dc=com"
    bind_pw: "password"
    lookup_pool_size: 8
    auth_pool_size: 8
  search:
    - protocol:
        - "imap"
        - "smtp"
        - "default"
      cache_name: "mail"
      base_dn: "ou=people,dc=example,dc=com"
      filter:
        user: "(&(objectClass=inetOrgPerson)(uid=%L{user}))"
      mapping:
        account_field: "uid"
      attribute:
        - "uid"
        - "userPassword"
```

## Configuration Structure

Nauthilus configuration consists of several main sections:

1. **Server Configuration**: Core settings for the server
2. **Backend Configuration**: Authentication backends (LDAP, Lua)
3. **Feature Configuration**: Optional features like RBL checks
4. **Protocol Configuration**: Settings for different protocols

### Environment Variables

Some settings can be configured using environment variables. These are typically used for sensitive information like passwords. See the [Reference](/docs/configuration/reference) for details.

### Configuration File Location

By default, Nauthilus looks for its configuration file in these locations:

- `./nauthilus.yml` (current directory)
- `$HOME/.nauthilus/nauthilus.yml`
- `/etc/nauthilus/nauthilus.yml`
- `/usr/local/etc/nauthilus/nauthilus.yml`

_Search order changed in version 1.7.9_

### Command-Line Options

Nauthilus supports the following command-line options:

- `-config <path>`: Specify a custom path to the configuration file. This overrides the default search locations.
- `-config-format <format>`: Specify the configuration file format (yaml, json, toml, etc.). Default is "yaml".
- `-version`: Print the version information and exit.

_New in version 1.7.9_

## Understanding Backends and Protocols

### Backends

Nauthilus supports multiple authentication backends:

- **cache**: Redis-based caching (should always be first)
- **ldap**: LDAP directory service
- **lua**: Custom Lua scripts

A typical configuration uses cache followed by either LDAP or Lua (or both):

```yaml
server:
  backends:
    - cache
    - ldap
    - lua
```

### Protocols

Protocols define how Nauthilus handles different types of authentication requests. When a client connects to Nauthilus, it specifies a protocol in the `AUTH-Protocol` header.

Each protocol can have its own configuration for:
- Filters and attributes to retrieve
- Cache prefixes for Redis storage
- Authentication rules

Example protocol configuration for LDAP:

```yaml
ldap:
  search:
    - protocol:
        - "imap"
        - "pop3"
      cache_name: "mail"
      base_dn: "ou=people,dc=example,dc=com"
      filter:
        user: "(&(objectClass=inetOrgPerson)(uid=%L{user}))"
      mapping:
        account_field: "uid"
      attribute:
        - "uid"
        - "userPassword"
```

## Redis Configuration

Redis is essential for Nauthilus as it stores authentication results, brute force detection data, and more. You can configure Redis in several ways:

### Standalone or Master-Replica

```yaml
server:
  redis:
    master:
      address: "redis:6379"
    replica:
      addresses:
        - "redis-replica:6379"
```

### Redis Sentinel

```yaml
server:
  redis:
    sentinels:
      master: "mymaster"
      addresses:
        - "sentinel1:26379"
        - "sentinel2:26379"
        - "sentinel3:26379"
```

### Redis Cluster

```yaml
server:
  redis:
    cluster:
      addresses:
        - "redis1:6379"
        - "redis2:6379"
        - "redis3:6379"
```

## Integration Options

### Mail Server Integration

#### Dovecot Integration (Recommended)

Dovecot can be integrated with Nauthilus using its Lua backend:

1. Configure Dovecot to use the HTTP authentication backend
2. Set up the Lua script to communicate with Nauthilus
3. Configure Nauthilus to handle Dovecot authentication requests

See the [Dovecot Lua example](/docs/examples/dovecot-lua) for detailed instructions.

#### Nginx Mail Proxy

Nauthilus can be integrated with Nginx's mail module:

1. Configure Nginx to use the HTTP authentication backend
2. Set up Nginx to forward authentication requests to Nauthilus
3. Configure Nauthilus to handle Nginx authentication requests

See the [Nginx mail plugin example](/docs/examples/nginx-mail-plugin) for details.

#### Postfix with Cyrus SASL

For Postfix SMTP submission:

1. Configure Cyrus SASL to use the HTTP authentication backend
2. Set up Cyrus SASL to communicate with Nauthilus
3. Configure Nauthilus to handle SASL authentication requests

Note: This integration provides fewer features compared to Dovecot integration.

### Web Application Integration (OAuth2/OpenID Connect)

For Single Sign-On (SSO) with web applications:

1. Set up Ory Hydra as the OAuth2/OpenID Connect provider
2. Configure Nauthilus as the login and consent provider for Hydra
3. Configure your load balancer to route authentication requests to Nauthilus

Example HAProxy configuration:

```haproxy
acl oidc path_beg,url_dec -m beg -i /login /device /consent /logout /2fa/v1 /notify /static

use_backend be_nauthilus_oidc if oidc

backend be_nauthilus_oidc
  mode http
  balance roundrobin
  option forwardfor
  http-check connect ssl alpn h2,http/1.1
  http-check send meth GET uri /ping body "pong"
  http-check expect status 200
  server nauthilus1 nauthilus:9443 check ssl
```

## Security Features

### Brute Force Protection

Configure brute force protection to prevent password guessing attacks:

```yaml
server:
  brute_force_protocols:
    - imap
    - smtp
    - submission
    - ory-hydra

brute_force:
  buckets:
    - name: b_1min_ipv4_32
      period: 60
      cidr: 32
      ipv4: true
      failed_requests: 10
```

### Realtime Blackhole Lists (RBL)

Check client IP addresses against RBL services:

```yaml
server:
  features:
    - rbl

realtime_blackhole_lists:
  threshold: 10
  lists:
    - name: "SpamRats AuthBL"
      rbl: "auth.spamrats.com"
      ipv4: true
      ipv6: false
      return_code: "127.0.0.43"
      weight: 10
```

## Monitoring and Maintenance

### Health Checks

Nauthilus provides a `/ping` endpoint that returns "pong" when the service is healthy.

### Reloading Configuration

To reload the configuration without restarting Nauthilus:

```bash
kill -HUP $(pidof nauthilus)
```

For changes to web server settings, follow with:

```bash
kill -SIGUSR1 $(pidof nauthilus)
```

### Metrics

Enable Prometheus metrics for monitoring:

```yaml
server:
  prometheus_timer:
    enabled: true
    labels:
      - request
      - backend
      - brute_force
```

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Check LDAP connection and credentials
   - Verify protocol configuration matches client requests
   - Examine Redis connectivity

2. **Performance Issues**
   - Increase Redis pool size
   - Optimize LDAP queries
   - Enable caching for frequently used requests

3. **Configuration Errors**
   - Validate YAML syntax
   - Check log files for configuration parsing errors
   - Ensure all required fields are provided

### Logging

Increase log verbosity for troubleshooting:

```yaml
server:
  log:
    level: debug
    debug_modules:
      - auth
      - ldap
      - cache
```

## Next Steps

After basic setup, consider exploring:

- [Advanced Configuration](/docs/configuration/index.md) - Detailed configuration options
- [LDAP Backend](/docs/configuration/database-backends/ldap.md) - LDAP integration details
- [Lua Backend](/docs/configuration/database-backends/lua.md) - Custom authentication with Lua
- [OAuth2 Configuration](/docs/configuration/oauth2.md) - Setting up SSO
- [Full Configuration Example](/docs/configuration/full-example.md) - Complete configuration reference

## Getting Help

- Visit the [official website](https://nauthilus.org)
- Subscribe to the [mailing lists](https://lists.nauthilus.org)
- Check the [documentation](https://nauthilus.org/docs)
- Consider [commercial support](https://nauthilus.org) for enterprise deployments
