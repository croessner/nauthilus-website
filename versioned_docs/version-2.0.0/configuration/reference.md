---
title: Reference
description: Configuration of environment variables in Nauthilus
keywords: [Configuration, Environment]
sidebar_position: 1
---
# Reference

This page describes all available environment variables, there meaning and there defaults.

:::note
All variables are prefixed with NAUTHILUS_. For better readability the prefix is left away in this document.
:::

The list of parameters is not following a special order.

There are much more environment variables available, if you look at the configuration file settings. Each of these may also be defined as environment variables by
joining the section keywords with an underscore.

Example:

```yaml
server:
  address: "[::]:9443"
  haproxy_v2: false

  tls:
    enabled: true
```

In env-form:

```shell
NAUTHILUS_SERVER_ADDRESS="[::]:9443"
NAUTHILUS_SERVER_HAPROXY_V2=false
NAUTHILUS_SERVER_TLS_ENABLED=true
```

:::warning
These configuration parameters are not reloaded, if the main process receives a HUP-signal! You must restart the
service if settings have changed!
:::

## Nauthilus

| Name    | **DEVELOPER_MODE** |
|---------|--------------------|
| Default | false              |
| Value   | Boolean            |

This parameter activates the developer mode. In this mode, redis keys are stored in plain text as well as you can see
passwords in plain text in the logs! Please really use this mode, if you are testing something and have full control
over the system its running on.

| Name    | **TRUSTED_PROXIES** |
|---------|---------------------|
| Default | "127.0.0.1 ::1"     |
| Value   | String              |

If Nauthilus runs behind a reverse proxy or a load balancer, it is necessary to define trusted proxies. This will trust
the X-Forwarded-To header in the HTTP protocol and track the real client IP. This especially needed when using the brute
force protection!

| Name    | **LANGUAGE_RESOURCES** |
|---------|------------------------|
| Default | "/usr/app/resources"   |
| Value   | String                 |

Specify the absolute path to the language resources. This directory contains the localized files need for Nauthilus.

| Name    | **SERVER_REDIS_ENCRYPTION_SECRET** |
|---------|------------------------------------|
| Default | ""                                 |
| Value   | String                              |

Secret used to encrypt sensitive data in Redis. Provide a long, random password (min. 16 characters, no spaces). Nauthilus derives a 32‑byte key internally (SHA‑256) and encrypts with ChaCha20‑Poly1305.

| Name    | **LDAP_CONFIG_ENCRYPTION_SECRET** |
|---------|-----------------------------------|
| Default | ""                                |
| Value   | String                             |

Secret for encrypting data stored in LDAP (optional). Required if you store TOTP secrets or recovery codes in LDAP. Same rules as above (password‑like; min. 16 chars; internal 32‑byte derivation via SHA‑256; ChaCha20‑Poly1305).

| Name    | **LOCAL_CACHE_AUTH_TTL** |
|---------|--------------------------|
| Default | 30                       |
| Value   | Positive integer         |

Specify how long a page hit in seconds has to be cached locally for each Nauthilus instance.

| Name    | **LUA_SCRIPT_TIMEOUT** |
|---------|------------------------|
| Default | 120                    |
| Value   | Positive integer       |

This parameter specifies how long in seconds a Lua script is allowed to run, until it is aborted by the interpreter.

| Name    | **PROTECT_ENFORCE_REJECT** |
|---------|----------------------------|
| Default | false                      |
| Value   | Boolean                    |

Controls enforcement of the Account Protection filter. When false or unset (default), the filter runs in dry‑run mode: applies progressive delay and sets Step‑Up/CAPTCHA hints via headers/Redis but does not reject the request. When true, unauthenticated requests are temporarily rejected while protection is active. Related headers: `X-Nauthilus-Protection`, `X-Nauthilus-Protection-Reason`, `X-Nauthilus-Protection-Mode` (dry‑run).

### Global Pattern Monitoring (GPM_*) — since v1.10.2
These variables tune the account-centric distributed pattern detection to reduce false positives (Carrier-NAT, mobile IP churn, TOR). Defaults are conservative.

| Name    | **GPM_THRESH_UNIQ_1H** |
|---------|------------------------|
| Default | 12                     |
| Value   | Positive integer       |

Minimum unique IPs within 1 hour required as a short-term signal. If this OR the 24h threshold is met, combined with the 7d threshold and other checks, an account is flagged as under distributed attack.

| Name    | **GPM_THRESH_UNIQ_24H** |
|---------|-------------------------|
| Default | 25                      |
| Value   | Positive integer        |

Minimum unique IPs within 24 hours used as an alternative short-/mid-term signal to the 1h threshold.

| Name    | **GPM_THRESH_UNIQ_7D** |
|---------|------------------------|
| Default | 60                     |
| Value   | Positive integer       |

Minimum unique IPs within 7 days (long-term signal). Must be met together with a short-term signal.

| Name    | **GPM_MIN_FAILS_24H** |
|---------|-----------------------|
| Default | 8                     |
| Value   | Positive integer      |

Minimum number of failed attempts in 24 hours. Prevents flagging cases with many unique IPs but very few failures (typical for benign churn).

| Name    | **GPM_THRESH_IP_TO_FAIL_RATIO** |
|---------|---------------------------------|
| Default | 1.2                             |
| Value   | Float                           |

Required ratio of unique IPs to failed attempts in 1h OR 24h. Higher values detect more broadly distributed failures.

| Name    | **GPM_ATTACK_TTL_SEC** |
|---------|------------------------|
| Default | 43200 (12h)            |
| Value   | Positive integer (sec) |

Sliding window horizon for the ZSET that tracks accounts under distributed attack. Lower values reduce the persistence of older spikes.

| Name    | **TERM_THEME**            |
|---------|---------------------------|
| Default | "light"                   |
| Value   | String: `light` or `dark` |

Controls the intensity of ANSI foreground colors used for full-line colorized text logs. `dark` uses bright/high-intensity colors optimized for dark terminals; `light` (default) uses standard-intensity colors better suited for light backgrounds. This only affects text logs when color output is enabled (`server.log.color: true`) and JSON logs remain uncolored.

## Nginx

| Name    | **NGINX_WAIT_DELAY**     |
|---------|--------------------------|
| Default | 1                        |
| Value   | Positive integer (2-255) |

If a login failed, this value is returned to Nginx to let a client wait. It is a setting for brute force prevention.

| Name    | **NGINX_MAX_LOGIN_ATTEMPTS** |
|---------|------------------------------|
| Default | 15                           |
| Value   | Positive integer (1-255)     |

Replay with Auth-Wait header as long as the maximum login attemtps does not raise the limit of this parameter.

| Name    | **SMTP_BACKEND_ADDRESS** |
|---------|--------------------------|
| Default | "127.0.0.1"              |
| Value   | String                   |

Specify the backend IP address for an SMTP server. This setting is used, if backend monitoring is turned off.

| Name    | **SMTP_BACKEND_PORT**                  |
|---------|----------------------------------------|
| Default | 5871                                   |
| Value   | Positive integer (a valid port number) |

This is the port of an SMTP server. This setting is used, if backend monitoring is turned off.

| Name    | **IMAP_BACKEND_ADDRESS** |
|---------|--------------------------|
| Default | "127.0.0.1"              |
| Value   | String                   |

Specify the backend IP address for a IMAP server. This setting is used, if backend monitoring is turned off.

| Name    | **IMAP_BACKEND_PORT**                  |
|---------|----------------------------------------|
| Default | 9931                                   |
| Value   | Positive integer (a valid port number) |

This is the port of a IMAP server. This setting is used, if backend monitoring is turned off.

## Identity Provider settings

| Name    | **IDP_OIDC_ISSUER** |
|---------|---------------------|
| Default | ""                  |
| Value   | String              |

The public issuer URL for the OpenID Connect provider.

| Name    | **IDP_SAML2_ENTITY_ID** |
|---------|-------------------------|
| Default | ""                      |
| Value   | String                  |

The Entity ID for the SAML 2.0 Identity Provider.

| Name    | **SERVER_FRONTEND_HTML_STATIC_CONTENT_PATH** |
|---------|----------------------------------------------|
| Default | "/usr/app/static"                            |
| Value   | String                                       |

Define the path where Nauthilus will find IdP templates, CSS, and other static content.

| Name    | **SERVER_FRONTEND_DEFAULT_LOGO_IMAGE** |
|---------|----------------------------------------|
| Default | "/static/img/logo.png"                 |
| Value   | String                                 |

Path to the company logo used in the IdP frontend.

| Name    | **HOMEPAGE**            |
|---------|-------------------------|
| Default | "https://nauthilus.org" |
| Value   | String                  |

After a user has logged out, there may exist a user defined post URL. If none was defined, Nauthilus will redirect the
user to this page.

### Login page (including 2FA page)

| Name    | **LOGIN_PAGE** |
|---------|----------------|
| Default | "/login"       |
| Value   | String         |

This is the URI path for the login page. If you change this, you also must modify the page template! Leave it unchanged
if possible!

| Name    | **LOGIN_PAGE_LOGO_IMAGE_ALT**            |
|---------|------------------------------------------|
| Default | "Logo (c) by Roessner-Network-Solutions" |
| Value   | String                                   |

The HTML image alt text for the company logo.

| Name    | **LOGIN_REMEMBER_FOR** |
|---------|------------------------|
| Default | 10800                  |
| Value   | Integer                |

This is the number of seconds a user will not be asked to log in again, if the checkbox to remember the user was checked.
This has nothing to do with the calling application, which may keep a user logged in differently. Setting this to 0 (
zero), will keep the user logged in forever. This is not recommended! If you want to disable this feature, you may
consider modifying the page template and removing the checkbox entirely.

| Name    | **LOGIN_PAGE_WELCOME** |
|---------|------------------------|
| Default | -                      |
| Value   | String                 |

If you define this string, a headline will appear on top of the company logo

### Device page

| Name    | **DEVICE_PAGE** |
|---------|-----------------|
| Default | "/device"       |
| Value   | String          |

See LOGIN_PAGE

### Consent page

| Name    | CONSENT_PAGE |
|---------|--------------|
| Default | "/consent"   |
| Value   | String       |

See LOGIN_PAGE

| Name    | **CONSENT_PAGE_LOGO_IMAGE_ALT**          |
|---------|------------------------------------------|
| Default | "Logo (c) by Roessner-Network-Solutions" |
| Value   | String                                   |

See LOGIN_PAGE_LOGO_IMAGE_ALT

| Name    | **CONSENT_REMEMBER_FOR** |
|---------|--------------------------|
| Default | 3600                     |
| Value   | Integer                  |

See LOGIN_REMEMBER_FOR

| Name    | **CONSENT_PAGE_WELCOME** |
|---------|--------------------------|
| Default | -                        |
| Value   | String                   |

See LOGIN_PAGE_WELCOME

### Logout page

| Name    | **LOGOUT_PAGE** |
|---------|-----------------|
| Default | "/logout"       |
| Value   | String          |

See LOGIN_PAGE

| Name    | **LOGOUT_PAGE_WELCOME** |
|---------|-------------------------|
| Default | -                       |
| Value   | String                  |

See LOGIN_PAGE_WELCOME

### 2FA specific settings

If you provide two-factor authentication, the following settings are available:

| Name    | **TOTP_ISSUER** |
|---------|-----------------|
| Default | "nauthilus.me"  |
| Value   | String          |

This field is used in the **otpauth://** URL parameter, when restoring a secret key. It should match the issuer that was
used when creating the key (and read from database afterward).

:::warning
The current implementation uses hard-coded settings for TOTP-secrets. These are:

* algorithm: SHA1
* Digits: 6
:::
 
| Name    | **LOGIN_2FA_PAGE** |
|---------|--------------------|
 | Default | "/register"        |
| Value   | String             |

This is the URL path where a user can register a second factor for authentication.

:::warning
The path is relative to /2fa/v1, which is a hardcoded default!
:::
> 
| Name    | **LOGIN_2FA_PAGE_WELCOME** |
|---------|----------------------------|
| Default | -                          |
| Value   | String                     |

See LOGIN_PAGE_WELCOME

| Name    | **LOGIN_2FA_POST_PAGE** |
|---------|-------------------------|
| Default | "/totp"                 |
| Value   | String                  |

This is the URL path where a user gets redirected to after logging in at the registration endpoint. This may change in
future releases, when webauthn is supported.

> Note:
>
> The path is relative to /2fa/v1, which is a hardcoded default!

| Name    | **TOTP_PAGE** |
|---------|---------------|
| Default | "/totp"       |
| Value   | String        |

This is the URL where a user can fetch a QR code of a newly created TOTP code. After the code has been verified by the
user, the code will finally be stored in the user backend database.

> Note:
>
> The path is relative to /2fa/v1, which is a hardcoded default!

| Name    | **TOTP_WELCOME** |
|---------|------------------|
| Default | -                |
| Value   | String           |

See LOGIN_PAGE_WELCOME

| Name    | **TOTP_PAGE_LOGO_IMAGE_ALT**             |
|---------|------------------------------------------|
| Default | "Logo (c) by Roessner-Network-Solutions" |
| Value   | String                                   |

See LOGIN_PAGE_LOGO_IMAGE_ALT

| Name    | **TOTP_SKEW**    |
|---------|------------------|
| Default | 1                |
| Value   | Positive integer |

When using TOTP secrets, this variable is used to allow the server adding **TOTP_SKEW** times 30 seconds periods before 
and after the current time slot. Disable this by setting the variable to 0. Values larger than 1 are sketchy.

| Name    | **NOTIFY_PAGE** |
|---------|-----------------|
| Default | "/notify"       |
| Value   | String          |

This is an endpoint for user information returned by Nauthilus.

| Name    | **NOTIFY_WELCOME** |
|---------|--------------------|
| Default | -                  |
| Value   | String             |

See LOGIN_PAGE_WELCOME

| Name    | **NOTIFY_PAGE_LOGO_IMAGE_ALT**           |
|---------|------------------------------------------|
| Default | "Logo (c) by Roessner-Network-Solutions" |
| Value   | String                                   |

See LOGIN_PAGE_LOGO_IMAGE_ALT

### WebAuthn

This is work in progress and under active development.


## Lua Plugins (Features, Filters, Actions, Hooks)

The following environment variables are read directly by bundled Lua scripts. They complement the main configuration and can be used to tune behavior without changing Lua code. Unless stated otherwise, variables are optional.

### Common (used by many Lua scripts)

| Name                   | Default   | Type   | Used by                           | Description                                                                                                      |
|------------------------|-----------|--------|-----------------------------------|------------------------------------------------------------------------------------------------------------------|
| CUSTOM_REDIS_POOL_NAME | — (unset) | String | features, filters, actions, hooks | Name of a non-default Redis connection pool to use for this Lua execution. When unset, the default pool is used. |

### Account Protection filter (filters/account_protection_mode.lua)

| Name                      | Default | Type              | Description                                                                                                                                                                                                                                    |
|---------------------------|---------|-------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| PROTECT_THRESH_UNIQ24     | 12      | Integer           | Minimum unique scoped IPs in 24h window to consider an account under protection.                                                                                                                                                               |
| PROTECT_THRESH_UNIQ7D     | 30      | Integer           | Minimum unique scoped IPs in 7d window to consider an account under protection.                                                                                                                                                                |
| PROTECT_THRESH_FAIL24     | 7       | Integer           | Minimum failed attempts in 24h window to consider an account under protection.                                                                                                                                                                 |
| PROTECT_THRESH_FAIL7D     | 15      | Integer           | Minimum failed attempts in 7d window to consider an account under protection.                                                                                                                                                                  |
| PROTECT_BACKOFF_MIN_MS    | 150     | Integer (ms)      | Minimum backoff delay applied when protection is active.                                                                                                                                                                                       |
| PROTECT_BACKOFF_MAX_MS    | 1000    | Integer (ms)      | Upper bound for applied backoff delay.                                                                                                                                                                                                         |
| PROTECT_BACKOFF_MAX_LEVEL | 5       | Integer           | Maximum backoff escalation level.                                                                                                                                                                                                              |
| PROTECT_MODE_TTL_SEC      | 3600    | Integer (seconds) | TTL for the protection state and step-up requirement hints.                                                                                                                                                                                    |
| PROTECT_ENFORCE_REJECT    | false   | Boolean           | Enforcement switch. When false or unset (default), the filter runs in dry‑run mode (no blocking, only delay + step-up hints). When true, unauthenticated requests are rejected while protection is active. See also the dedicated entry above. |
| CUSTOM_REDIS_POOL_NAME    | —       | String            | Redis pool override for this filter’s Redis operations.                                                                                                                                                                                        |

Emits headers for HTTP/OIDC frontends: X-Nauthilus-Protection, X-Nauthilus-Protection-Reason; and in dry‑run mode: X-Nauthilus-Protection-Mode: dry-run.

### Security metrics feature (features/security_metrics.lua)

| Name                              | Default                      | Type            | Description                                                                                                                                           |
|-----------------------------------|------------------------------|-----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| SECURITY_METRICS_PER_USER_ENABLED | false                        | Boolean         | When true, emits per‑user security_* metrics (guarded by sampling). When false, per‑user emission is disabled except for protected users.             |
| SECURITY_METRICS_SAMPLE_RATE      | 1.0 (effective when enabled) | Float (0.0–1.0) | Sampling rate for per‑user metrics; users currently in protection mode are always emitted. Unset is treated as 1.0 when per‑user metrics are enabled. |
| CUSTOM_REDIS_POOL_NAME            | —                            | String          | Redis pool override for metrics reads.                                                                                                                |

### Account long‑window metrics feature (features/account_longwindow_metrics.lua)

| Name                   | Default | Type   | Description                                                                 |
|------------------------|---------|--------|-----------------------------------------------------------------------------|
| CUSTOM_REDIS_POOL_NAME | —       | String | Redis pool override. Used for HLL (PFADD/PFCOUNT) and failure ZSET updates. |

This feature already uses scoped IPs when computing uniq_ips_24h and uniq_ips_7d (see Lua Backend config ip_scoping_v6_cidr / ip_scoping_v4_cidr).

### Failed login hotspot feature (features/failed_login_hotspot.lua)

| Name                       | Default | Type              | Description                                                          |
|----------------------------|---------|-------------------|----------------------------------------------------------------------|
| FAILED_LOGIN_HOT_THRESHOLD | 10      | Integer           | ZSET score threshold for a username to be considered “hot”.          |
| FAILED_LOGIN_TOP_K         | 20      | Integer           | Consider users within Top‑K by rank as potential hotspots.           |
| FAILED_LOGIN_SNAPSHOT_SEC  | 30      | Integer (seconds) | Rate‑limit for emitting a small Top‑N snapshot as Prometheus gauges. |
| FAILED_LOGIN_SNAPSHOT_TOPN | 10      | Integer           | Size of the Top‑N snapshot to expose as gauges.                      |
| CUSTOM_REDIS_POOL_NAME     | —       | String            | Redis pool override for ZSET reads.                                  |

### Dynamic response action (actions/dynamic_response.lua)

Administration alerting controls and warm‑up parameters for dynamic threat response.

| Name                                 | Default | Type              | Description                                                                            |
|--------------------------------------|---------|-------------------|----------------------------------------------------------------------------------------|
| ADMIN_ALERTS_ENABLED                 | true    | Boolean           | Master toggle for sending administrator alert emails.                                  |
| ADMIN_ALERT_MIN_UNIQUE_IPS           | 100     | Integer           | Baseline: minimum global unique IPs before alerts are considered.                      |
| ADMIN_ALERT_MIN_IPS_PER_USER         | 2.5     | Float             | Baseline: minimum IPs per user before alerts are considered.                           |
| ADMIN_ALERT_REQUIRE_EVIDENCE         | false   | Boolean           | If true, require additional evidence (e.g., suspicious regions/IPs) besides baselines. |
| ADMIN_ALERT_COOLDOWN_SECONDS         | 900     | Integer (seconds) | Per‑subject cooldown to avoid alert storms.                                            |
| DYNAMIC_RESPONSE_WARMUP_SECONDS      | 604800  | Integer (seconds) | Warm‑up period length before full automated responses are enabled.                     |
| DYNAMIC_RESPONSE_WARMUP_MIN_ATTEMPTS | 1000    | Integer           | Minimum number of attempts observed before warm‑up can end.                            |
| DYNAMIC_RESPONSE_WARMUP_MIN_USERS    | 10      | Integer           | Minimum number of distinct users observed before warm‑up can end.                      |
| CUSTOM_REDIS_POOL_NAME               | —       | String            | Redis pool override for dynamic response data access and rate‑limits.                  |

### ClickHouse post‑action (actions/clickhouse.lua)

| Name                  | Default                   | Type         | Description                                                                                                               |
|-----------------------|---------------------------|--------------|---------------------------------------------------------------------------------------------------------------------------|
| CLICKHOUSE_INSERT_URL | —                         | String (URL) | Full HTTP endpoint including SQL, e.g. `http://host:8123/?query=INSERT%20INTO%20nauthilus.logins%20FORMAT%20JSONEachRow`. |
| CLICKHOUSE_USER       | —                         | String       | Optional basic auth user (also sent via X‑ClickHouse-User).                                                               |
| CLICKHOUSE_PASSWORD   | —                         | String       | Optional basic auth password (also sent via X‑ClickHouse-Key).                                                            |
| CLICKHOUSE_BATCH_SIZE | 100                       | Integer      | Batch size for buffered inserts.                                                                                          |
| CLICKHOUSE_CACHE_KEY  | "clickhouse:batch:logins" | String       | Cache key used for the in‑process batching queue.                                                                         |

### ClickHouse query hook (hooks/clickhouse-query.lua)

| Name                   | Default          | Type         | Description                                                    |
|------------------------|------------------|--------------|----------------------------------------------------------------|
| CLICKHOUSE_SELECT_BASE | —                | String (URL) | Base URL of ClickHouse HTTP endpoint, e.g. `http://host:8123`. |
| CLICKHOUSE_TABLE       | nauthilus.logins | String       | Table to query for read‑only operations.                       |
| CLICKHOUSE_USER        | —                | String       | Optional basic auth user (also sent via headers).              |
| CLICKHOUSE_PASSWORD    | —                | String       | Optional basic auth password (also sent via headers).          |

### Blocklist feature (features/blocklist.lua)

| Name          | Default | Type         | Description                                      |
|---------------|---------|--------------|--------------------------------------------------|
| BLOCKLIST_URL | —       | String (URL) | Endpoint for retrieving external blocklist data. |

---

See also:
- Release Notes → 1.10.x (Security and protection)
- Configuration → Database Backends → Lua Backend (ip_scoping_v6_cidr, ip_scoping_v4_cidr)
- Lua API → HTTP response (headers used by filters)
- Filters → Account protection
