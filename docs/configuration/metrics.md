---
title: Metrics
description: Prometheus support in Nauthilus
keywords: [Metrics, Prometheus]
sidebar_position: 3
---
# Prometheus support

There is some limited support for Prometheus and Grafana. For an example have a look at the contrib folder included with
the source code.

## Prometheus

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

Lines 6 and below are required, if nauthilus is protected with HTTP basic authentication. Please include the correct
values.
