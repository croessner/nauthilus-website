---
title: Account Protection Filter
description: Progressive backoff and Step-Up signaling with optional enforcement for per-account protection in Nauthilus
keywords: [Security, Filters, Account Protection, CAPTCHA, Step-Up]
sidebar_position: 30
---

# Account Protection (Lua Filter)

The Account Protection filter protects individual accounts under suspicious activity. It applies a progressive delay (backoff) and signals Step-Up/Challenge to frontends. Starting with v1.10.0, enforcement is disabled by default (dry-run): requests are not blocked unless explicitly enabled.

## What it does

- Evaluates long-window, per-account metrics (24h/7d) and attack flags:
  - `uniq_ips_24h`, `uniq_ips_7d`
  - `fails_24h`, `fails_7d`
  - distributed-attack participation flag
- Applies progressive backoff (sleep) to slow down automated attacks.
- Records protection mode state in Redis and exposes Step-Up hints for HTTP/OIDC frontends.
- Optionally rejects unauthenticated requests while protection is active (enforcement mode).

## Headers and Redis keys

When protection is active, the filter sets:

- HTTP headers (for HTTP/OIDC flows):
  - `X-Nauthilus-Protection: stepup`
  - `X-Nauthilus-Protection-Reason: <comma-separated reasons>`
  - `X-Nauthilus-Protection-Mode: dry-run` (only when enforcement is disabled)

- Redis keys:
  - `ntc:acct:<username>:protection` (HASH: `active`, `reason`, `backoff_level`, `until_ts`, `updated`)
  - `ntc:acct:<username>:stepup` (HASH: `required`, `reason`, `until_ts`, `updated`)
  - `ntc:acct:protection_active` (SET of usernames currently under protection)

## Configuration

### Environment variables (thresholds and timing)

| Name                        | Default | Description                             |
|-----------------------------|---------|-----------------------------------------|
| `PROTECT_THRESH_UNIQ24`     | 12      | Min unique scoped IPs in 24h to trigger |
| `PROTECT_THRESH_UNIQ7D`     | 30      | Min unique scoped IPs in 7d to trigger  |
| `PROTECT_THRESH_FAIL24`     | 7       | Min failed attempts in 24h to trigger   |
| `PROTECT_THRESH_FAIL7D`     | 15      | Min failed attempts in 7d to trigger    |
| `PROTECT_BACKOFF_MIN_MS`    | 150     | Minimum backoff per step (ms)           |
| `PROTECT_BACKOFF_MAX_MS`    | 1000    | Maximum backoff per step (ms)           |
| `PROTECT_BACKOFF_MAX_LEVEL` | 5       | Backoff steps until capped              |
| `PROTECT_MODE_TTL_SEC`      | 3600    | Protection mode TTL in seconds          |

### Enforcement switch (v1.10.0)

| Name                     | Default | Description                                                                                         |
|--------------------------|---------|-----------------------------------------------------------------------------------------------------|
| `PROTECT_ENFORCE_REJECT` | false   | If `true`, unauthenticated requests are rejected while under protection. If `false` (or unset), the |
|                          |         | filter runs in dry‑run: applies delay and Step‑Up hints, but does not block pre‑auth.               |

### Scoped IP normalization (cluster-wide dedup)

Per-account unique IP metrics and attack heuristics work best with IP scoping to avoid counting IPv6 privacy addresses
and large NAT pools as distinct clients. Nauthilus exposes scoping controls to Lua features in v1.10.0:

- `lua.config.ip_scoping_v6_cidr` (e.g., `64`)
- `lua.config.ip_scoping_v4_cidr` (e.g., `24`)

See also: Lua API `nauthilus_misc.scoped_ip` below.

## Frontend integration (CAPTCHA/Step‑Up)

Use the headers to enforce a challenge in your IdP or reverse proxy. The Step‑Up/Redis flags allow consistent UX across protocols.

Example (pseudo):

```nginx
if ($http_x_nauthilus_protection = "stepup") {
  return 403;
}
```

In dry‑run, prefer showing a CAPTCHA/MFA step based on headers without hard-blocking at Nauthilus.

## Lua API and metrics

- Prometheus counters incremented by the filter:
  - `security_stepup_challenges_issued_total`
  - `security_slow_attack_suspicions_total`

- Lua API for scoping: `nauthilus_misc.scoped_ip(ctx, ip)`
  - Contexts: `"lua_generic"` (default), `"rwp"`, `"tolerations"`

## Related documentation

- Release Notes → 1.10 → Security and protection
- Configuration → Lua Backend → `ip_scoping_*` options
- Configuration → Reference → `PROTECT_ENFORCE_REJECT`
