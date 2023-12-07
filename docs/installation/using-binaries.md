---
title: Using binaries
sidebar_position: 3
---
<!-- TOC -->
  * [/etc/systemd/system/nauthilus.service](#etcsystemdsystemnauthilusservice)
  * [/etc/sysconfig/nauthilus](#etcsysconfignauthilus)
<!-- TOC -->
# Using binaries

There are no binaries yet. Please compile the code and come back here.

## Systemd unit file /etc/systemd/system/nauthilus.service

```
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

## /etc/sysconfig/nauthilus

It is recommended to put your configuration settings in a file under /etc/sysconfig/nauthilus (RHEL based systems) or
/etc/default/nauthilus (Debian based systems). For the latter you need to adjust the unit file above to match the given
path.

```
NAUTHILUS_VERBOSE_LEVEL="info"
NAUTHILUS_HTTP_ADDRESS="[::]:8080"
NAUTHILUS_PASSDB_BACKENDS="cache lua"
```
