---
title: Docker
description: Run Nauthilus in a docker container
keywords: [Docker, Compose]
sidebar_position: 1
---
# Docker
#
The recommended way of installing Nauthilus is using docker.

## Using docker compose

The following docker-compose.yml file is a really basic example. Please have a look at the reference page and the
configuration page to build your own docker environment:

```yaml
services:

  nauthilus:
    container_name: nauthilus
    image: gitlab.roessner-net.de:5050/croessner/nauthilus:latest
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      TZ: "Europe/Berlin"
      NAUTHILUS_VERBOSE_LEVEL: "info"
      NAUTHILUS_FEATURES: "tls_encryption rbl"
      NAUTHILUS_HTTP_ADDRESS: "[::]:8080"
      NAUTHILUS_PASSDB_BACKENDS: "cache lua"

    healthcheck:
      test: [ "CMD", "/usr/app/healthcheck", "--url", "http://nauthilus:8080/ping" ]
      timeout: 60s
      interval: 30s
      retries: 2
      start_period: 3s
```
