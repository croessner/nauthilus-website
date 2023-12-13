---
title: Features
description: This is an overview of features that are currently supported
keywords: [Features]
sidebar_position: 1
---
This is an overview of features that are currently supported.

<!-- TOC -->
  * [Database support](#database-support)
  * [Roadmap](#roadmap)
<!-- TOC -->

- Authentication service for Nginx using there HTTP-protocol
- Authentication service for Dovecot using a custom Lua backend
- Authentication service for Cyrus-SASL using the httppost-backend
- Realtime Blackhole lists support
- Using Redis (sentinel) for storing runtime information
- Redis cache backend in front of databases
- TLS support and HTTP basic authorization
- HTTP/2 support
- Metrics support for prometheus. A sample template for grafana is included
- Brute force buckets to detect password attacks
- Static list of known domains. If the login is equal to an email address, Nauthilus can check, if it is responsible for
  this domain
- OAuth2 and OpenID connect support using Ory Hydra. Nauthilus implements the login, consent and logout flows. It ships
  with templates that can be customized to suite your CI/CD.
- Fully optimized LDAP pooling with idle connections
- Basic reloading by reloading the configuration file and restarting database connections
- Nauthilus provides custom namespaces for the Redis cache to dynamically deal with different protocol dependent data
- Nauthilus support TOTP two-factor authentication. Therefor it requires a 3rd-party to manage the TOTP secrets. It uses
  a default of 6 digits with SHA1. If you need other options, please open a ticket.
- Register a user account for TOTP second factor authentication.
- Lua features to block unwanted authentication requests before talking to
  database backends.
- Lua filters to talk to 3rd party endpoints and override the authentication
  decision.
- Lua post actions to trigger some work flows after features were triggered
  (rejecting a request) or doing some other stuff after the request has already been processed.

## Database support

- OpenLDAP and Active-Directory support
- MySQL/MariaDB and PostgreSQL support
- Lua

## Roadmap

- Two-factor authentication – Webauthn
