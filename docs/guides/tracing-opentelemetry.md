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

## Native Go Plugins

The host wraps native request-time component calls with spans from the `nauthilus/plugin/runtime` instrumentation scope. Automatic attributes identify only bounded module, component, extension point, method, and result values.

Plugin code can create child spans through `Host.Tracer(scope)`. `Tracer.Start` accepts the current call context and returns a derived context plus a host-owned span supporting events, attributes, error recording, and `End`.

Plugins are responsible for the sensitivity and cardinality of their own attributes. `Span.RecordError` records the supplied error, and non-primitive attribute values are stringified; redact before recording. Do not attach usernames, client IPs, accounts, tokens, credentials, raw LDAP/SQL, message bodies, or unbounded external errors.

Use the derived context for `Host.HTTP`, `Host.LDAP`, Redis, or plugin-owned downstream calls so trace parentage and propagation remain intact. `Host.Go` preserves trace/context values for supervised work but replaces request cancellation with host-lifetime cancellation.

See [Host Services](../developer/go-plugins/host-services.md#tracing) and the [Tracing API reference](../developer/go-plugins/api-reference/services.md#tracing).
