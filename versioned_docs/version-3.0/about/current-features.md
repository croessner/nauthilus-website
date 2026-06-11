---
title: Current Features
description: Overview of current Nauthilus capabilities
keywords: [Features, Overview]
sidebar_position: 2
---

# Current Features

## Core Platform

- unified authentication hub for mail, HTTP, OIDC, and SAML flows
- Redis-backed caching and operational state
- LDAP and Lua authentication backends
- remote authority backend for split edge/authority deployments
- canonical config-v2 structure with validation and dump tooling

## Policy Controls

- brute-force protection
- RBL checks
- relay-domain validation
- TLS enforcement with cleartext allowlists
- Lua environment and subject sources

## Services and Observability

- backend health checks
- structured logging
- Prometheus metrics
- connection monitoring
- OpenTelemetry tracing

## Identity

- native OIDC provider
- native SAML IdP
- edge-hosted OIDC/SAML flows backed by a private Nauthilus authority over gRPC
- integrated frontend
- TOTP and WebAuthn MFA
- authority-owned TOTP, recovery-code, and WebAuthn persistence for distributed IdP deployments
- remember-me/session controls
