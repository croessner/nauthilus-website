---
title: Docker
description: Run Nauthilus in a Docker container
keywords: [Docker, Compose, Container, Installation, Configuration]
sidebar_position: 1
---

# Docker Installation

Docker is the recommended way to deploy Nauthilus, providing a consistent and isolated environment for running the authentication service.

:::note
As of v1.9.12, official images are built without Hydra/OIDC by default. If you need Hydra (login/consent, 2FA/WebAuthn UI), build your own image with BUILD_TAGS=hydra as shown below.
:::

## Available Docker Images

Nauthilus offers several Docker images to suit different needs:

| Image                                  | Description           | Use Case                        |
|----------------------------------------|-----------------------|---------------------------------|
| `ghcr.io/croessner/nauthilus:latest`   | Latest stable release | Production environments         |
| `ghcr.io/croessner/nauthilus:features` | Development branch    | Testing new features            |
| `ghcr.io/croessner/nauthilus:dev-dbg`  | Debug version         | Development and troubleshooting |

Additionally, a separate image is available for the blocklist service:

| Image                                          | Description           |
|------------------------------------------------|-----------------------|
| `ghcr.io/croessner/nauthilus-blocklist:latest` | Blocklist HTTP server |

## Quick Start with Docker Compose

The simplest way to get started is with Docker Compose. Create a `docker-compose.yml` file:

```yaml
services:
  nauthilus:
    container_name: nauthilus
    image: ghcr.io/croessner/nauthilus:latest
    restart: unless-stopped
    ports:
      - "8180:8180"
    environment:
      TZ: "Europe/Berlin"
    volumes:
      - ./nauthilus.yml:/etc/nauthilus/nauthilus.yml:ro
    healthcheck:
      test: [ "CMD", "/usr/app/healthcheck", "--url", "http://localhost:8180/ping" ]
      timeout: 60s
      interval: 30s
      retries: 2
      start_period: 3s
```

Create a minimal `nauthilus.yml` configuration file in the same directory:

```yaml
# Basic configuration example
server:
  address: "0.0.0.0:8180"  # Listen on all interfaces
  log:
    level: "info"
  redis:
    master:
      address: "redis:6379"  # Redis server address
    password_nonce: "generate-a-random-string-here"
  backends:
    - cache
    - ldap  # Or "lua" if using Lua backend

# Note: This is a minimal example. You'll need to configure at least one 
# authentication backend (LDAP or Lua) for Nauthilus to function properly.
# For detailed configuration examples, see the Configuration section in the documentation.
```

Start the service:

```bash
docker-compose up -d
```

## Configuration Options

### Using Configuration Files

The recommended approach is to mount a configuration file into the container:

```yaml
volumes:
  - ./nauthilus.yml:/etc/nauthilus/nauthilus.yml:ro
```

This allows you to:
- Modify the configuration without rebuilding the container
- Use the `reload` endpoint to apply changes without restarting
- Maintain complex configurations in version control

## Hydra-enabled image builds

To build an image that includes Hydra/OIDC, pass BUILD_TAGS=hydra at build time. The project Dockerfile already supports this argument.

```bash
# Build without Hydra (default)
docker build -t ghcr.io/yourorg/nauthilus:1.9.12 .

# Build with Hydra enabled
docker build --build-arg BUILD_TAGS=hydra -t ghcr.io/yourorg/nauthilus:1.9.12-hydra .
```

At runtime, configure the oauth2 section only when using a hydra-enabled image. 2FA/WebAuthn UI routes are present only in hydra builds.

## Advanced Docker Compose Setup

For production deployments, you might want a more comprehensive setup:

```yaml
version: "3.8"

services:
  nauthilus:
    image: ghcr.io/croessner/nauthilus:latest
    container_name: nauthilus
    restart: always
    ports:
      - "127.0.0.1:8180:8180"
    environment:
      TZ: "Europe/Berlin"
      # Load sensitive values from .env file
      NAUTHILUS_HTTP_BASIC_AUTH_USERNAME: ${HTTP_BASIC_AUTH_USERNAME}
      NAUTHILUS_HTTP_BASIC_AUTH_PASSWORD: ${HTTP_BASIC_AUTH_PASSWORD}
    volumes:
      - ./nauthilus.yml:/etc/nauthilus/nauthilus.yml:ro
      - ./certs/tls.crt:/etc/nauthilus/tls.crt:ro
      - ./certs/tls.key:/etc/nauthilus/tls.key:ro
    healthcheck:
      test: [ "CMD", "/usr/app/healthcheck", "--url", "http://localhost:8180/ping" ]
      timeout: 30s
      interval: 10s
      retries: 2
      start_period: 10s
    networks:
      - nauthilus-net
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  redis:
    image: redis:alpine
    container_name: nauthilus_redis
    restart: always
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    networks:
      - nauthilus-net

networks:
  nauthilus-net:

volumes:
  redis-data:
```

Create a `.env` file for sensitive information:

```
HTTP_BASIC_AUTH_USERNAME=admin
HTTP_BASIC_AUTH_PASSWORD=secure_password
```

## Monitoring and Metrics

Nauthilus provides Prometheus metrics. To set up monitoring:

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: nauthilus_prometheus
    restart: always
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - ./prometheus/:/etc/prometheus/
      - prometheus_data:/prometheus
    networks:
      - nauthilus-net

  grafana:
    image: grafana/grafana:latest
    container_name: nauthilus_grafana
    restart: always
    ports:
      - "127.0.0.1:3000:3000"
    volumes:
      - grafana_storage:/var/lib/grafana
    networks:
      - nauthilus-net

volumes:
  prometheus_data:
  grafana_storage:
```

## Using the Blocklist Service

To use the blocklist service alongside Nauthilus:

```yaml
services:
  blocklist:
    image: chrroessner/nauthilus-blocklist:latest
    container_name: nauthilus_blocklist
    restart: always
    ports:
      - "127.0.0.1:8080:8080"
    networks:
      - nauthilus-net
```

## Security Considerations

### Running as Non-Root

Nauthilus Docker images already run as a non-root user (`nauthilus`) by default.

### Network Security

Restrict access to the Nauthilus API:

```yaml
ports:
  - "127.0.0.1:8180:8180"  # Only accessible from localhost
```

### TLS Configuration

For production, enable TLS:

```yaml
volumes:
  - ./certs/tls.crt:/etc/nauthilus/tls.crt:ro
  - ./certs/tls.key:/etc/nauthilus/tls.key:ro
```

And in your `nauthilus.yml`:

```yaml
http:
  address: 0.0.0.0:8180
  tls:
    enabled: true
    cert: /etc/nauthilus/tls.crt
    key: /etc/nauthilus/tls.key
```

## Troubleshooting

### Health Checks

The Docker image includes a health check utility. You can customize it:

```yaml
healthcheck:
  test: [ "CMD", "/usr/app/healthcheck", "--url", "https://localhost:8180/ping", "--tls-skip-verify" ]
  timeout: 30s
  interval: 10s
  retries: 2
  start_period: 10s
```

### Checking Logs

View container logs:

```bash
docker logs nauthilus
```

### Common Issues

1. **Configuration errors**: Check your `nauthilus.yml` for syntax errors
2. **Permission issues**: Ensure volume mounts have correct permissions
3. **Network connectivity**: Verify network settings if connecting to external services

## Building Custom Images

You can build custom Nauthilus images:

```bash
docker build -t my-nauthilus:custom .
```

For the debug version:

```bash
docker build -t my-nauthilus:dev-dbg -f Dockerfile.debug .
```

## Honeypot Servers

The Nauthilus Docker image includes honeypot servers that can be used to redirect detected attackers:

- `/usr/app/fakesmtp`: SMTP honeypot server
- `/usr/app/fakeimap`: IMAP honeypot server

These servers are designed to be integrated with HAproxy to redirect detected attackers, providing a better approach than using tools like fail2ban. When an attacker is redirected to these servers, they will experience delays and receive generic error messages, while their attempts are logged.

Example integration with HAproxy:

```
# HAproxy configuration example
frontend mail_frontend
    bind *:25
    # Normal traffic goes to the real mail server
    default_backend real_mail_server

    # Detected attackers are redirected to the honeypot
    acl blocked src_is_blocked
    use_backend honeypot_smtp if blocked

backend real_mail_server
    server mail1 real-mail-server:25

backend honeypot_smtp
    server honeypot nauthilus:10587
```

The honeypot servers accept authentication attempts and log them, but always return errors after a short delay, effectively slowing down brute force attacks while gathering information about the attackers.

## Additional Resources

- [Full Configuration Reference](/docs/configuration/server-configuration)
- [Database Backends](/docs/configuration/database-backends)
- [Monitoring Setup](/docs/configuration/backend-server-monitoring)
