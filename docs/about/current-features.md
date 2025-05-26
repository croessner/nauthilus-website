---
title: Features
description: A comprehensive overview of features supported by Nauthilus
keywords: [Features, Authentication, Authorization, Security]
sidebar_position: 1
---

# Nauthilus Features

This document provides a comprehensive overview of all features currently supported by Nauthilus.

## Core Authentication Features

- **Multi-Protocol Authentication Service**
  - HTTP/Nginx authentication using the HTTP protocol
  - Dovecot authentication using a custom Lua backend
  - Cyrus-SASL authentication using the httppost-backend
  - Support for mail protocols (IMAP, POP3, SMTP, LMTP, Sieve)
  - Support for web applications via OAuth2/OpenID Connect

- **Multiple Authentication Backends**
  - LDAP backend with support for OpenLDAP and Active Directory
  - Lua backend for custom authentication logic
  - Redis cache backend for improved performance

- **Authentication Methods**
  - Password-based authentication with secure password handling
  - JWT (JSON Web Token) authentication with role-based access control
  - HTTP Basic Authentication for simple integrations

## Security Features

- **Brute Force Protection**
  - Configurable brute force buckets to detect password attacks
  - Multiple bucket types based on time periods and network ranges
  - Customizable thresholds and actions
  - Adaptive toleration mechanism that dynamically adjusts tolerance thresholds (v1.7.7)

- **Realtime Blackhole Lists (RBL)**
  - Integration with multiple RBL services
  - Configurable thresholds and scoring
  - IPv4 and IPv6 support

- **Network Security**
  - TLS support with certificate validation
  - Cleartext network definitions for enforcing encryption
  - Client IP verification and filtering

- **Domain Security**
  - Static list of known domains for email address validation
  - Relay domain verification for email authentication

## Performance and Reliability

- **Redis Integration**
  - Support for multiple Redis deployment models:
    - Standalone Redis
    - Master-replica configuration
    - Redis Sentinel
    - Redis Cluster
  - Configurable connection pooling
  - Custom namespaces for protocol-dependent data

- **Connection Handling**
  - HTTP/2 and HTTP/3 support
  - HAproxy v2 protocol support
  - Keep-alive optimization
  - Connection monitoring

- **Caching**
  - Redis-based caching for authentication results
  - Configurable TTLs for positive and negative caches
  - Optimized LDAP pooling with idle connections

## Extensibility

- **Lua Scripting**
  - Lua features to filter authentication requests before backend processing
  - Lua filters to integrate with third-party endpoints and override authentication decisions
  - Lua post-actions for workflow triggers after request processing
  - Custom HTTP endpoints via Lua hooks
  - Shared in-memory cache for Lua scripts
  - Redis and LDAP integration in Lua scripts

- **Monitoring and Metrics**
  - Prometheus metrics support
  - Grafana dashboard templates included
  - Backend server monitoring
  - Detailed logging with configurable levels

- **API Integration**
  - RESTful API for authentication requests
  - JSON response format
  - Custom headers support

## Single Sign-On (SSO)

- **OAuth2/OpenID Connect**
  - Integration with Keycloak via [nauthilus-keycloak](https://github.com/croessner/nauthilus-keycloak)
  - Customizable templates for CI/CD integration
  - Role-based access control

## Administration

- **Configuration**
  - YAML-based configuration
  - Environment variable support
  - Hot reloading of configuration
  - Restart of LDAP connections without service interruption

- **Deployment**
  - Docker support
  - Kubernetes compatibility
  - Systemd integration

## Deprecated Features

The following features were originally designed to work with Ory Hydra. It is recommended to use Keycloak instead, as it offers full compatibility with [nauthilus-keycloak](https://github.com/croessner/nauthilus-keycloak).

- OAuth2 and OpenID Connect support with Ory Hydra, including implementations for login, consent, and logout flows
- TOTP-based two-factor authentication support in Nauthilus
- User account registration with TOTP as a second-factor authentication (requires the build tag **register2fa**)

## Roadmap

- WebAuthn support for two-factor authentication
