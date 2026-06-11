---
title: Metrics
description: Prometheus support in Nauthilus
keywords: [Metrics, Prometheus]
sidebar_position: 3
---
# Prometheus support

There is some limited support for Prometheus and Grafana. For an example have a look at the contrib folder included with
the source code.

## Endpoint Authentication

Nauthilus exposes Prometheus metrics on the HTTP listener at `/metrics`.
The endpoint is open unless dedicated metrics authentication is enabled.

Use `observability.metrics.endpoint_auth.basic` to protect `/metrics` with HTTP Basic authentication:

```yaml
observability:
  metrics:
    endpoint_auth:
      basic:
        enabled: true
        username: prometheus
        password: "replace-with-a-long-random-secret"
```

This authentication block is specific to the metrics endpoint.
It does not reuse `auth.backchannel.basic_auth`, and `/metrics` does not accept Bearer or OIDC authentication.

When `observability.metrics.endpoint_auth.basic.enabled=true`, both `username` and `password` are required during configuration validation.
Requests without valid credentials return HTTP `401` with a Basic authentication challenge.

If the block is disabled or omitted, `/metrics` remains accessible without authentication.

## Prometheus Configuration

Configure Prometheus with matching credentials:

```yaml
scrape_configs:
  - job_name: nauthilus
    metrics_path: /metrics
    scheme: https
    static_configs:
      - targets:
          - nauthilus.example.test:9443
    basic_auth:
      username: prometheus
      password: "replace-with-a-long-random-secret"
```

For scrapes that cross a trust boundary, use HTTPS or a private scrape network in addition to Basic authentication.
