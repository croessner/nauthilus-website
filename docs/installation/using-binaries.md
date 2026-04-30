---
title: Using binaries
description: Installing and configuring Nauthilus using binary packages
keywords: [Systemd, Unit, Configuration, Binary, Installation]
sidebar_position: 3
---

# Using Binaries

This guide explains how to install and run Nauthilus from release binaries.

## Installation

Download the release archive, unpack it, and install the server binary:

```bash
curl -LO https://github.com/croessner/nauthilus/releases/latest/download/nauthilus-linux-amd64.tar.gz
tar -xzf nauthilus-linux-amd64.tar.gz
sudo mv nauthilus /usr/local/sbin/
sudo chmod +x /usr/local/sbin/nauthilus
```

Create a dedicated user and config directory:

```bash
sudo useradd -r -s /bin/false nauthilus
sudo mkdir -p /etc/nauthilus
sudo chown nauthilus:nauthilus /etc/nauthilus
```

## Minimal Config File

Create `/etc/nauthilus/nauthilus.yml`:

```yaml
runtime:
  servers:
    http:
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
```

## Systemd Unit

```ini
[Unit]
Description=Nauthilus authentication service
After=network.target nss-lookup.target

[Service]
Type=simple
EnvironmentFile=-/etc/sysconfig/nauthilus
ExecStart=/usr/local/sbin/nauthilus --config /etc/nauthilus/nauthilus.yml
Restart=on-failure
User=nauthilus
Group=nauthilus

[Install]
WantedBy=multi-user.target
```

Enable and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable nauthilus
sudo systemctl start nauthilus
```

## Useful Commands

Validate configuration:

```bash
nauthilus --config /etc/nauthilus/nauthilus.yml --config-check
```

Show defaults:

```bash
nauthilus -d
```

Show only changed values:

```bash
nauthilus -n --config /etc/nauthilus/nauthilus.yml
```

Show changed values including secrets:

```bash
nauthilus -n -P --config /etc/nauthilus/nauthilus.yml
```

## Configuration Sources

Nauthilus can be configured with:

1. a YAML/JSON/TOML/HCL/INI config file
2. environment variables derived from canonical config-v2 paths
3. command-line flags for loader behavior

For example:

```bash
export NAUTHILUS_STORAGE_REDIS_PRIMARY_ADDRESS=127.0.0.1:6379
export NAUTHILUS_OBSERVABILITY_LOG_LEVEL=debug
```

## Next Steps

- [Configuration Overview](../configuration/index.md)
- [Runtime, Observability, and Storage](/docs/configuration/server-configuration)
- [Database Backends](/docs/configuration/database-backends)
- [Brute Force Protection](/docs/configuration/brute-force)
