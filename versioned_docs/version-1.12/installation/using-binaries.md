---
title: Using binaries
description: Installing and configuring Nauthilus using binary packages
keywords: [Systemd, Unit, Configuration, Binary, Installation]
sidebar_position: 3
---

# Using Binaries

This guide explains how to install and configure Nauthilus using pre-compiled binary packages. This method is recommended for production environments where you want a straightforward installation process.

## Binary Availability

Nauthilus binaries are available for various platforms:

- Linux (x86_64, ARM64)
- FreeBSD (x86_64)
- macOS (x86_64, ARM64)

You can download the latest release from the [GitHub Releases page](https://github.com/croessner/nauthilus/releases).

:::note
If binaries are not yet available for your platform, you can [compile Nauthilus from source](/docs/installation/compiling) instead.
:::

## Installation Steps

### 1. Download the Binary

```bash
# Example for Linux x86_64
curl -LO https://github.com/croessner/nauthilus/releases/latest/download/nauthilus-linux-amd64.tar.gz
tar -xzf nauthilus-linux-amd64.tar.gz
```

### 2. Move the Binary to a System Directory

```bash
sudo mv nauthilus /usr/local/sbin/
sudo chmod +x /usr/local/sbin/nauthilus
```

### 3. Create a Dedicated User (Recommended)

For security reasons, it's recommended to run Nauthilus as a dedicated non-privileged user:

```bash
sudo useradd -r -s /bin/false nauthilus
```

### 4. Create Configuration Directory

```bash
sudo mkdir -p /etc/nauthilus
sudo chown nauthilus:nauthilus /etc/nauthilus
```

### 5. Create a Basic Configuration File

Create a file at `/etc/nauthilus/nauthilus.yml` with your configuration. See the [Configuration Reference](/docs/configuration/server-configuration) for details.

## Systemd Integration

For Linux systems using systemd, you can set up Nauthilus as a service for automatic startup and management.

### Create a Systemd Unit File

Create the file `/etc/systemd/system/nauthilus.service`:

```ini
[Unit]
Description=Central authentication server
After=network.target nss-lookup.target syslog.target

[Service]
Type=simple
EnvironmentFile=-/etc/sysconfig/nauthilus
ExecStart=/usr/local/sbin/nauthilus
Restart=on-failure
User=nauthilus
Group=nauthilus

[Install]
WantedBy=multi-user.target
```

### Enable and Start the Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable nauthilus
sudo systemctl start nauthilus
```

### Check Service Status

```bash
sudo systemctl status nauthilus
```

## Configuration Options

Nauthilus can be configured in multiple ways:

1. **YAML Configuration File**: The primary method, using `/etc/nauthilus/nauthilus.yml`
2. **Environment Variables**: As shown in the environment file above
3. **Command-Line Flags**: For overriding specific settings

See the [Configuration Reference](/docs/configuration/server-configuration) for a complete list of options.

## Upgrading

To upgrade Nauthilus to a newer version:

1. Download the new binary
2. Replace the existing binary
3. Restart the service:
   ```bash
   sudo systemctl restart nauthilus
   ```

## Troubleshooting

### Checking Logs

View service logs:

```bash
sudo journalctl -u nauthilus
```

### Common Issues

1. **Permission problems**: Ensure the nauthilus user has access to the configuration directory
2. **Configuration errors**: Verify your configuration file syntax
3. **Port conflicts**: Check if another service is using the same port

## Next Steps

After installation, you might want to:

- [Configure authentication backends](/docs/configuration/database-backends)
- [Set up monitoring](/docs/configuration/backend-server-monitoring)
- [Configure brute force protection](/docs/configuration/brute-force)
