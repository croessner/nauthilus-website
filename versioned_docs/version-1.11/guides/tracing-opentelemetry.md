---
title: Tracing (OpenTelemetry)
description: Configure and use distributed tracing in Nauthilus via OpenTelemetry
keywords: [Tracing, OpenTelemetry, OTLP, Observability]
sidebar_position: 40
---

# Tracing (OpenTelemetry)

Nauthilus supports distributed tracing via OpenTelemetry. When enabled, spans are emitted for incoming HTTP requests and internal operations; Lua scripts can create child spans via the `nauthilus_opentelemetry` module.

Tracing is disabled by default and can be enabled and configured under `server.insights.tracing`.

## Quick start

Minimal example to send traces to an OTLP/HTTP endpoint (e.g., Tempo, Grafana Cloud, or the OpenTelemetry Collector):

```yaml
server:
  insights:
    tracing:
      enabled: true
      exporter: otlphttp
      endpoint: otel-collector.example.com:4318
      sampler_ratio: 0.1        # sample 10% of traces
      service_name: nauthilus    # optional; falls back to instance name
```

- Endpoint authentication: supply headers via the HTTP client environment (e.g., reverse proxy) or configure TLS below for custom CAs. If your collector requires a bearer token, put it behind an authenticating reverse proxy.

## Configuration reference (server.insights.tracing)

All keys live under `server.insights.tracing`.

- `enabled` (bool): Toggle tracing. Default false.
- `exporter` (string): Exporter type. Supported: `otlphttp` or `none`. Default empty (treated as `none`).
- `endpoint` (string): Collector host and port only (no scheme, no path). Path defaults to `/v1/traces`; scheme is chosen by TLS settings. Example: `collector.example.com:4318`.
- `sampler_ratio` (float 0..1): Parent-based TraceID ratio sampler. 0 disables new root spans (except children of sampled parents). 1 samples all. Default 0.
- `service_name` (string): Overrides the reported service name. Defaults to `server.instance_name` or `nauthilus-server` if unset.
- `propagators` (array of string): Incoming/outgoing text map propagators. Supported values: `tracecontext`, `baggage`, `b3`, `b3multi`, `jaeger`. When unset, W3C TraceContext and Baggage are used. Example:
  ```yaml
  propagators: [tracecontext, baggage, b3]
  ```
- `enable_redis` (bool): Also instrument the Redis client (adds span events/attributes for Redis commands). Default false.
- `log_export_results` (bool): Log DEBUG messages for successful exporter batches. Default false to reduce log noise.
- `tls` (object): TLS for the OTLP HTTP exporter.
  - `enabled` (bool): Enable TLS. Set to true for HTTPS endpoints (typical). If your endpoint is `https://...`, leave this true.
  - `ca_file` (string): Path to a custom CA bundle file to trust the collector’s certificate.
  - `skip_verify` (bool): Disable certificate verification. Not recommended for production.

Notes:
- The exporter currently supports OTLP over HTTP. If you use gRPC or custom auth headers, place an authenticating reverse proxy in front of your collector.
- Traces carry resource attributes such as `service.name`, `service.version`, and an `instance` label from `server.instance_name`.

## Example configurations

### 1) Local OpenTelemetry Collector (self-signed CA)

```yaml
server:
  instance_name: auth-eu-1
  insights:
    tracing:
      enabled: true
      exporter: otlphttp
      endpoint: otel-collector.internal:4318
      sampler_ratio: 1.0
      propagators: [tracecontext, baggage]
      enable_redis: true
      tls:
        enabled: true
        ca_file: /etc/ssl/certs/otel-ca.pem
```

### 2) Minimal, sampling 5%, B3 compatibility

```yaml
server:
  insights:
    tracing:
      enabled: true
      exporter: otlphttp
      endpoint: collector.example.com:4318
      sampler_ratio: 0.05
      propagators: [tracecontext, baggage, b3]
```

## Lua: create spans in scripts

Lua scripts can create spans when tracing is enabled. See Lua API → OpenTelemetry for details and examples.

```lua
local otel = require("nauthilus_opentelemetry")
if otel.is_enabled() then
  local tr = otel.tracer("nauthilus/policy")
  tr:with_span("policy.evaluate", function(span)
    span:set_attribute("rule", "A1")
  end)
end
```

## Redis tracing

When `server.insights.tracing.enable_redis` is true, the Redis client is instrumented to include span events for commands issued by Nauthilus. Use this to correlate application spans with backend latency.
