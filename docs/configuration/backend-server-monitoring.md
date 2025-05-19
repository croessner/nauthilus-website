---
title: Backend Server Monitoring
description: Configuration for backend server monitoring in Nauthilus
keywords: [Configuration, Backend, Monitoring]
sidebar_position: 7
---

# Backend Server Monitoring

If you have turned on the feature **backend_server_monitoring**, Nauthilus is able to do liveness probes for backend servers.
The result is updated every 20 seconds (hard-coded for now). This information can be used in Lua scripts. The initial idea was to
chose a backend server for the Nginx-based authentication process. Other usecases are also possible, depending on your needs.

## Configuration Options

### backend_server_monitoring::backend_servers

This configuration block defines servers to be monitored.

The following protocols can be used to monitor a backend server:

* smtp
* lmtp
* pop3
* imap
* sieve
* http

Servers can have a lightweight check, where only the connection is tested.

:::note
A connect timeout of 5 seconds is used. Also for reading and writing to an established connection.
:::

If the HAproxy flag is set, this is checked as well.

Having TLS settings for a backend, a handshake is done on top of the connection.

:::warning
We currently only support plain or TLS-on-connect connections. Only sieve has STARTTLS support 
:::

If deep checks are enabled, Nauthilus talks the configured protocol with each backend. Optionally, a givven test user and its password can
be used to verify a successful connection to the backend. We recommend to have one test user for each backend to prevent
technical problems with backend servers (for example index issues with Dovecot).

## Example Configuration

```yaml
backend_server_monitoring:
  backend_servers:
    - protocol: imap
      host: 192.168.0.2
      port: 993
      deep_check: true
      test_username: some_unique_test_user
      test_password: some_password
      tls: true
      tls_skip_verify: true
      haproxy_v2: true
```

The settings should be self-explained.