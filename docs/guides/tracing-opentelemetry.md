---
title: Tracing (OpenTelemetry)
description: Configure tracing with the current observability root
keywords: [Tracing, OpenTelemetry, OTLP, Observability]
sidebar_position: 40
---

# Tracing (OpenTelemetry)

Tracing is configured under:

- `observability.tracing`

## Minimal Example

```yaml
observability:
  tracing:
    enabled: true
    exporter: "otlphttp"
    endpoint: "otel-collector.example.com:4318"
    sampler_ratio: 0.1
    service_name: "nauthilus"
```

## Main Keys

- `enabled`
- `exporter`
- `endpoint`
- `sampler_ratio`
- `service_name`
- `propagators`
- `enable_redis`
- `log_export_results`
- `tls`

## Example with TLS and Redis Instrumentation

```yaml
observability:
  tracing:
    enabled: true
    exporter: "otlphttp"
    endpoint: "otel-collector.internal:4318"
    sampler_ratio: 1.0
    propagators:
      - "tracecontext"
      - "baggage"
    enable_redis: true
    tls:
      enabled: true
      ca_file: "/etc/ssl/certs/otel-ca.pem"
```

## Notes

- current tracing settings are no longer documented below `server.insights.tracing`
- Redis tracing is controlled by `observability.tracing.enable_redis`
- Lua scripts can create child spans through the Lua OpenTelemetry module when tracing is enabled
