---
title: Backend Health Checks
description: Configuration for auth.services.backend_health_checks
keywords: [Configuration, Backend, Health Checks]
sidebar_position: 9
---

# Backend Health Checks

Backend health checks are a service, not a control.

The current configuration lives under:

- `auth.services.enabled`
- `auth.services.backend_health_checks`
- `auth.services.backend_health_checks.targets`

Enable the service with:

```yaml
auth:
  services:
    enabled:
      - backend_health_checks
```

## Example

```yaml
auth:
  services:
    enabled:
      - backend_health_checks
    backend_health_checks:
      connect_timeout: 2s
      tls_timeout: 2s
      deep_timeout: 5s
      connect_interval: 30s
      deep_interval: 2m
      failure_threshold: 3
      recovery_threshold: 2

      targets:
        - protocol: "imap"
          host: "imap.example.org."
          port: 993
          deep_check: true
          test_username: "healthcheck-user"
          test_password: "healthcheck-password"
          tls: true
          tls_skip_verify: false
          haproxy_v2: false
          connect_timeout: 1s
          tls_timeout: 1s
          deep_timeout: 10s
```

## Global Settings

| Field | Default | Description |
|---|---:|---|
| `connect_timeout` | `5s` | Timeout for the TCP connect phase. |
| `tls_timeout` | `5s` | Timeout for the TLS handshake when `tls: true` is configured on the target. |
| `deep_timeout` | `5s` | Timeout for the protocol-level deep check. |
| `connect_interval` | `10s` | Interval for connect probes. A connect probe verifies TCP, optional HAProxy v2 preface, and optional TLS only. |
| `deep_interval` | `10s` | Interval for protocol-level deep checks. When this equals `connect_interval`, Nauthilus runs one combined probe to preserve the previous default traffic pattern. |
| `failure_threshold` | `1` | Consecutive failed probes required before a backend is marked unhealthy. |
| `recovery_threshold` | `1` | Consecutive successful probes required before a backend is marked healthy again. |

## Target Settings

Each target supports the existing connection fields:

- `protocol`
- `host`
- `port`
- `request_uri`
- `test_username`
- `test_password`
- `deep_check`
- `tls`
- `tls_skip_verify`
- `haproxy_v2`

The timeout fields can also be set per target:

- `connect_timeout`
- `tls_timeout`
- `deep_timeout`

Per-target timeout values override the global backend-health-check timeout values for that target only.

## Probe Phases

Nauthilus separates backend checks into two phases:

- connect phase: opens the TCP connection and performs optional HAProxy v2 and TLS setup
- deep phase: performs the protocol-level login or request when `deep_check: true`

A successful deep check also proves that the connect phase succeeded.

## Notes

- use `backend_health_checks`, not `backend_server_monitoring`
- do not list it under `auth.controls.enabled`
- hostnames may include a trailing dot when you want an explicit FQDN
