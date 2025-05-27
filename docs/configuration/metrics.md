---
title: Metrics
description: Prometheus support in Nauthilus
keywords: [Metrics, Prometheus]
sidebar_position: 3
---
# Prometheus support

There is some limited support for Prometheus and Grafana. For an example have a look at the contrib folder included with
the source code.

## Authentication for Metrics Endpoint

The metrics endpoint (`/metrics`) is secured with authentication to prevent unauthorized access to sensitive monitoring data. The following authentication methods are supported:

1. **JWT Authentication**: If JWT authentication is enabled, users must have the "security" role to access the metrics endpoint.
2. **Basic Authentication**: If Basic Authentication is enabled, users must provide valid credentials to access the metrics endpoint.
3. **No Authentication**: If neither JWT nor Basic Authentication is enabled, the metrics endpoint is accessible without authentication.

## Prometheus Configuration

### Basic Authentication

If you're using Basic Authentication, configure Prometheus as follows:

```yaml
  - job_name: nauthilus
    scheme: https
    static_configs:
      - targets:
          - nauthilus.example.test:9443
    basic_auth:
      username: "nauthilususer"
      password: "nauthiluspassword"
```

### JWT Authentication

If you're using JWT Authentication, configure Prometheus as follows:

```yaml
  - job_name: nauthilus
    scheme: https
    static_configs:
      - targets:
          - nauthilus.example.test:9443
    authorization:
      type: Bearer
      credentials: "your_jwt_token"
```

You can generate a JWT token with the "security" role using the `/api/v1/jwt/token` endpoint:

```bash
curl -X POST http://nauthilus:8080/api/v1/jwt/token \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your_password"}'
```

The response will include a token that you can use in the Prometheus configuration.
