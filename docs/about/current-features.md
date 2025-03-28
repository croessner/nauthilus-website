---
title: Features
description: This is an overview of features that are currently supported
keywords: [Features]
sidebar_position: 1
---
# Features

This is an overview of features that are currently supported.

- Authentication service for Nginx using there HTTP-protocol
- Authentication service for Dovecot using a custom Lua backend
- Authentication service for Cyrus-SASL using the httppost-backend
- Realtime Blackhole lists support
- Using Redis (standalone, sentinel and cluster) for storing runtime information
- Redis cache backend in front of database backends
- TLS support and HTTP basic authorization
- HTTP/2, HTTP/3 support and HAproxy v2 support
- Metrics support for prometheus. A sample template for grafana is included
- Brute force buckets to detect password attacks
- Static list of known domains. If the login is equal to an email address, Nauthilus can check, if it is responsible for
  this domain
- SSO support in keycloak is also available with the custom authenticator found [here](https://github.com/croessner/nauthilus-keycloak)
  with templates that can be customized to suite your CI/CD.
- Fully optimized LDAP pooling with idle connections
- Basic reloading by reloading the configuration file and restarting LDAP connections
- Nauthilus provides custom namespaces for the Redis cache to dynamically deal with different protocol dependent data
- Lua features to block unwanted authentication requests before talking to
  database backends.
- Lua filters to talk to third party endpoints and override the authentication
  decision. This can also be used in conjunction with Dovecot to provide dynamic proxy settings (Dovecot 2.4 and later
  do not contain the director code anymore).
- Lua post actions to trigger some work flows after features were triggered
  (rejecting a request) or doing some other stuff after the request has already been processed.
- All Lua hooks can use a shared in-memory cache as well as basic Redis support (GET, SET, DEL and EXPIRE).
- All Lua hooks contain LDAP search functions to incorporate with the LDAP pool, if the LDAP backend is tunred on.
- A POC for Nauthilus as a replacement in Dovecot >2.4.0 is shown [here](https://github.com/croessner/nauthilus-demo)

## Database support aka backends

- OpenLDAP and Active-Directory support
- Lua

## Roadmap

- Two-factor authentication – Webauthn

# Deprecated features

The following features were originally designed to work with Ory Hydra. However, it is recommended to use Keycloak 
instead, as it offers full compatibility with [nauthilus-keycloak](https://github.com/croessner/nauthilus-keycloak).

-  OAuth2 and OpenID Connect support with Ory Hydra, including implementations for login, consent, and logout flows.
-  TOTP-based two-factor authentication support in Nauthilus.
-  User account registration with TOTP as a second-factor authentication (requires the build tag **register2fa**).

No further developments are planned for Webauthn.
