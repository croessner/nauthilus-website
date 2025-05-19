---
title: Cleartext Networks
description: Configuration for cleartext networks in Nauthilus
keywords: [Configuration, Cleartext, Networks]
sidebar_position: 5
---

# Cleartext Networks

Nauthilus can check, if a remote client connected using TLS. This test will reject clients that do not communicate
secured. The whitelist is for trusted local IPs and networks that are allowed to authenticate unencrypted.

:::note
Connections from "localhost" are allways trusted unencrypted!
:::

## Configuration Options

### cleartext_networks
_Default: empty list_

IPs with an optional CIDR mask:

```yaml
cleartext_networks:
  - 127.0.0.0/8
  - ::1
```

## Example Configuration

```yaml
cleartext_networks:
  - 127.0.0.0/8
  - ::1
  - 192.168.0.200
  - 172.16.0.0/12
```