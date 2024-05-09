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
    volumes:
      - ./conf.d/nauthilus.yml:/etc/nauthilus/nautilus.yml
    healthcheck:
      test: [ "CMD", "/usr/app/healthcheck", "--url", "http://nauthilus:8080/ping" ]
      timeout: 60s
      interval: 30s
      retries: 2
      start_period: 3s
```

You need a **nauthilus.yml** file with minimum requirements. You may also consider using environment variables, but
a configuration file can be modified and the service can be reloaded! Enviroment settings need a full restart.