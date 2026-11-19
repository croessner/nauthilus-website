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
- positive password cache (UCP) for LDAP, Lua, and opted-in native backend plugins, and an optional, encrypted LDAP
  identity lookup cache (UCI) for passwordless identity lookups with prefix-wide flush invalidation
- LDAP and Lua authentication backends
- versioned native Go plugin API with typed backends, policy sources/effects, hooks, and host service facades
- bundled GeoIP/ASN, ClickHouse, Have I Been Pwned, reputation, and DKIM2 intelligence Go plugins
- reputation learning from authentication outcomes and observations, with an optional durable Kafka journal worker and
  an audited management API
- remote authority backend for split edge/authority deployments
- canonical config-v2 structure with validation and dump tooling

## Policy Controls

- brute-force protection
- RBL checks
- relay-domain validation
- TLS enforcement with cleartext allowlists
- Lua environment and subject sources
- native Go environment and subject sources with registered typed policy facts
- protected Generic Policy REST and gRPC evaluation with strict typed values, ordered records, caller admission, and bounded effects
- generic native Go and sandboxed Lua fact/effect providers with declared effect replay safety
- record-local composite Policy expressions
- conditional LDAP updates (RFC 4528 assertions) from Lua and native plugins
- host-evidence auth FSM guard: Policy can tighten but never loosen an authentication result, with load-time
  validation of authn rule decisions and FSM markers per checkpoint
- bounded post-action supervisor and optional internal authentication admission limits that answer saturation with
  temporary failures

## Services and Observability

- backend health checks
- dependency-free liveness probe (`/livez`) and readiness that detects stalled LDAP worker queues
- structured logging with configurable NOTICE field exclusion
- Prometheus metrics
- connection monitoring
- OpenTelemetry tracing

## Identity

- native OIDC provider
- restricted RFC 7591 Dynamic Client Registration for public native mail clients with RFC 8252 loopback redirects and
  mandatory PKCE `S256`, including native application profiles
- dedicated OIDC backchannel introspection clients
- native SAML IdP
- edge-hosted OIDC/SAML flows backed by a private Nauthilus authority over gRPC, with connection ageing for rebalancing
- integrated frontend
- TOTP and WebAuthn MFA
- password-authenticated MFA self-service portal for TOTP, WebAuthn credentials, and recovery codes
- configurable MFA assurance levels with global and per-OIDC-client/SAML-SP policy
- authority-owned TOTP, recovery-code, and WebAuthn persistence for distributed IdP deployments
- remember-me/session controls
- opaque browser-session envelopes with typed, revisioned Redis state for OIDC, SAML, MFA, consent, and logout flows
