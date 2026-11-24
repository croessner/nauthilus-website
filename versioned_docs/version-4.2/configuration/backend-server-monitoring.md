---
title: Backend Health Checks
description: Configuration for auth.services.backend_health_checks
keywords: [Configuration, Backend, Health Checks]
sidebar_position: 9
---

# Backend Health Checks

Backend health checks are a service, not a control.

The current configuration lives under:

- `auth.services.enabled`
- `auth.services.backend_health_checks`
- `auth.services.backend_health_checks.targets`

Enable the service with:

```yaml
auth:
  services:
    enabled:
      - backend_health_checks
```

## Example

```yaml
auth:
  services:
    enabled:
      - backend_health_checks
    backend_health_checks:
      connect_timeout: 2s
      tls_timeout: 2s
      deep_timeout: 5s
      connect_interval: 30s
      deep_interval: 2m
      failure_threshold: 3
      recovery_threshold: 2

      targets:
        - protocol: "imap"
          host: "imap.example.org."
          port: 993
          deep_check: true
          test_username: "healthcheck-user"
          test_password: "healthcheck-password"
          auth_mechanism: "auto"
          tls_mode: "implicit"
          tls_skip_verify: false
          haproxy_v2: false
          connect_timeout: 1s
          tls_timeout: 1s
          deep_timeout: 10s
```

## Global Settings

| Field | Default | Description |
|---|---:|---|
| `connect_timeout` | `5s` | Timeout for the TCP connect phase. |
| `tls_timeout` | `5s` | Timeout for an implicit TLS or STARTTLS handshake. |
| `deep_timeout` | `5s` | Timeout for the protocol-level deep check. |
| `connect_interval` | `10s` | Interval for connect probes. A connect probe verifies TCP, optional HAProxy v2 preface, and optional TLS only. |
| `deep_interval` | `10s` | Interval for protocol-level deep checks. When this equals `connect_interval`, Nauthilus runs one combined probe to preserve the previous default traffic pattern. |
| `failure_threshold` | `1` | Consecutive failed probes required before a backend is marked unhealthy. |
| `recovery_threshold` | `1` | Consecutive successful probes required before a backend is marked healthy again. |

## Target Settings

Each target supports the connection and authentication fields below.

- `protocol`
- `host`
- `port`
- `request_uri`
- `test_username`
- `test_password`
- `auth_mechanism`
- `deep_check`
- `tls_mode`
- `tls`
- `tls_skip_verify`
- `haproxy_v2`

The timeout fields can also be set per target:

- `connect_timeout`
- `tls_timeout`
- `deep_timeout`

Per-target timeout values override the global backend-health-check timeout values for that target only.

## TLS Transport Mode

Use target-local `tls_mode` for new configurations:

| Value | Behavior |
|---|---|
| `plain` | Keep the backend connection unencrypted. A check that would send credentials still fails closed. |
| `implicit` | Start TLS immediately after the optional PROXY v2 preface. |
| `starttls` | Negotiate an application-protocol upgrade before authentication. |

`starttls` requires `deep_check: true`. It is supported for SMTP, LMTP when the server advertises it, POP3, IMAP, and Sieve. HTTP rejects `starttls` because this health-check adapter has no corresponding in-band upgrade.

The legacy Boolean `tls` field remains supported. `tls: true` means implicit TLS. A Sieve target with neither `tls_mode` nor `tls` keeps the historical STARTTLS default; other protocols default to `plain`. Combining `tls: true` with `tls_mode: plain` or `tls_mode: starttls` is invalid. The redundant combination of `tls: true` and `tls_mode: implicit` is accepted for migration compatibility.

STARTTLS is required, not opportunistic. A missing capability, refused upgrade, TLS handshake failure, or failed protected capability refresh marks the target unhealthy. Nauthilus discards capabilities learned before TLS and selects an authentication mechanism only from the protected capability response.

When `haproxy_v2: true` is configured, the probe writes the PROXY v2 header before implicit TLS or application-protocol negotiation. A STARTTLS probe therefore runs in this order:

```text
TCP -> PROXY v2 -> greeting -> capabilities -> STARTTLS or STLS
    -> TLS handshake -> protected capabilities -> authentication
```

## Authentication Mechanism

`auth_mechanism` is target-local. Configure it inside one item under `auth.services.backend_health_checks.targets`.

There is no global `auth.services.backend_health_checks.auth_mechanism` setting, and Nauthilus does not inherit an authentication mechanism from the service level. A target without `auth_mechanism` behaves as if it had `auth_mechanism: "auto"`.

Supported values are:

| Value | Meaning |
|---|---|
| `auto` | Discover the backend capabilities when the protocol has a capability surface, then select an executable mechanism. This is the default. |
| `PLAIN` | Use SASL PLAIN when the target protocol advertises it. |
| `LOGIN` | Use SASL LOGIN when the target protocol advertises it. |
| `USERPASS` | Use POP3 native `USER`/`PASS` when POP3 `CAPA` advertises native user authentication. |
| `BASIC` | Use HTTP Basic authentication through the HTTP health-check adapter. |

Mechanism names are normalized by the configuration loader. `auto` remains lower-case; explicit mechanisms are stored in upper-case.

Unsupported mechanisms are not executable by backend health checks, even when a backend advertises them. This includes `SCRAM-*`, `OAUTHBEARER`, `XOAUTH2`, `EXTERNAL`, `CRAM-MD5`, and `DIGEST-MD5`. Do not configure them as `auth_mechanism`; they are outside the implemented credential model for health checks. Unsupported advertised mechanisms are ignored for selection, and unsupported configured values fail configuration validation.

## Protocol Behavior

When `deep_check: true` and both `test_username` and `test_password` are set, Nauthilus authenticates with the selected mechanism. Without both credentials, the deep check stops after the protocol greeting and capability path.

| Protocol | Capability source | Supported health-check auth behavior |
|---|---|---|
| SMTP | `EHLO` `AUTH` and `AUTH=...` capabilities | Selects executable SASL mechanisms from the advertised `AUTH` list. In `starttls` mode it sends `STARTTLS` after `EHLO` and refreshes capabilities. |
| LMTP | `LHLO` `AUTH` and `AUTH=...` capabilities | Uses the same selector as SMTP when credentials are configured. In `starttls` mode it upgrades only when advertised and then repeats `LHLO`. |
| IMAP | `CAPABILITY`, `AUTH=<mech>`, and `SASL-IR` | Selects executable SASL mechanisms from `AUTH=<mech>` tokens. In `starttls` mode it issues tagged `STARTTLS` and refreshes `CAPABILITY`. |
| POP3 | `CAPA`, `SASL ...`, and optional native `USER` | Selects executable SASL mechanisms from `SASL ...`; native `USER`/`PASS` is represented as `USERPASS` only when native user authentication is advertised. In `starttls` mode it uses `STLS` and refreshes `CAPA`. |
| Sieve | Greeting capabilities, optional `STARTTLS`, post-TLS capabilities, `SASL`, and `SASL-IR` | Uses the configured TLS mode. The compatibility default is STARTTLS; after an upgrade it evaluates protected capabilities before selecting SASL. |
| HTTP | Static adapter | Uses `BASIC` only. HTTP has no capability discovery. |

The common selector validates explicit mechanisms against the adapter-reported mechanisms. `auto` uses the first executable option in this order: `PLAIN` with initial response, `PLAIN` classic, `LOGIN` with initial response, `LOGIN` classic, `USERPASS`, then `BASIC`.

## Initial Response

Initial response support is protocol-specific:

- IMAP and Sieve use initial responses only when the backend advertises `SASL-IR`.
- SMTP and LMTP have no separate `SASL-IR` capability. Their adapter may use known valid initial-response forms for `PLAIN` and `LOGIN`.
- SMTP and LMTP retry once with the classic challenge/response form only when the server rejects the initial-response command form or syntax. Authentication denial, unavailable mechanisms, missing TLS, and already-started multi-step exchanges remain hard failures.
- POP3 does not infer generic initial-response support. It uses the implemented POP3 forms: native `USER`/`PASS` for `USERPASS` and classic SASL `PLAIN` or `LOGIN` from `CAPA`.
- HTTP Basic has no SASL initial-response concept.

## Failure Behavior

If a target explicitly configures a supported mechanism but the backend does not advertise it, the deep check fails and Nauthilus logs an ERROR with the configured mechanism, advertised mechanisms, protocol, host, port, capability source, and `sasl_ir` state.

Wrong credentials are not hidden by trying another mechanism. Once a mechanism is selected, authentication failure is the health-check failure.

Nauthilus does not log passwords or full authentication payloads. Diagnostic logs name the selected or unavailable mechanism and protocol state only.

## Probe Phases

Nauthilus separates backend checks into two phases:

- connect phase: opens the TCP connection and performs the optional PROXY v2 preface and implicit TLS setup
- deep phase: performs the protocol-level login or request when `deep_check: true`

A successful deep check also proves that the connect phase succeeded.

## Notes

- use `backend_health_checks`, not `backend_server_monitoring`
- do not list it under `auth.controls.enabled`
- hostnames may include a trailing dot when you want an explicit FQDN
