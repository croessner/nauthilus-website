---
title: Reference
sidebar_position: 1
---
# Reference

This page describes all available environment variables, there meaning and there defaults.

<!-- TOC -->
* [Reference](#reference)
  * [Nauthilus](#nauthilus)
  * [Nginx](#nginx)
  * [Redis](#redis)
  * [SQL-Backend](#sql-backend)
  * [Cache-Backend](#cache-backend)
  * [OAuth2 / Ory Hydra settings](#oauth2--ory-hydra-settings)
    * [Login page (including 2FA page)](#login-page-including-2fa-page)
    * [Device page](#device-page)
    * [Consent page](#consent-page)
    * [Logout page](#logout-page)
    * [2FA specific settings](#2fa-specific-settings)
    * [WebAuthn](#webauthn)
<!-- TOC -->

> Note:
>
> All variables are prefixed with NAUTHILUS_. For better readability the prefix is left away in this document.

The list of parameters is not following a special order.

> Note 2:
>
> These configuration parameters are not reloaded, if the main process receives a HUP-signal! You must restart the
> service if settings have changed!

## Nauthilus

| Name    | **DNS_TIMEOUT**          |
|---------|--------------------------|
| Default | 2                        |
| Value   | Positive integer (2-255) |

DNS timeout for the resolver

| Name    | **PASSDB_BACKENDS**                    |
|---------|----------------------------------------|
| Default | "cache ldap"                           |
| Values  | * ldap<br/>* sql<br/>* cache<br/>* lua |

This variable specifies which backends should be used. Backends are processed from left to right and the golden rule is:
first match wins!

| Name    | **FEATURES**                                                                                                                                                                                                                                                                                                                                                                                                                          |
|---------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Default | "tls\_encryption rbl geoip relay\_domains"                                                                                                                                                                                                                                                                                                                                                                                            |
| Values  | * tls_encryption: Check, if a remote client used a secured connection to its service<br/>* rbl: Check, if a remote client is known to some RBL list<br/>* geoip: Get some GEO statistics from a remote clients IP address<br/>* relay_domains: Add a static domain list for known supported domains. Unknown requests will be rejected and brute force buckets will be updated<br/>* lua: Write your own features to detect attackers |

This parameter controls different aspects of a remote client that must be fulfilled. Geoip itself is currently just for
logging purposes.

| Name    | **BRUTE_FORCE_PROTECTION** |
|---------|----------------------------|
| Default | "http"                     |
| Values  | String                     |

The configuration file may list SQL and/or LDAP search definitions, which list all used protocols used by your
applications. The names are freely choosable. An example of this string may look like: "http imap pop3 sieve submission
smtp ory-hydra".

| Name    | **DEVELOPER_MODE** |
|---------|--------------------|
| Default | false              |
| Value   | Boolean            |

This parameter activates the developer mode. In this mode, redis keys are stored in plain text as well as you can see
passwords in plain text in the logs! Please really use this mode, if you are testing something and have full control
over the system its running on.

| Name    | **INSTANCE_NAME** |
|---------|-------------------|
| Default | nauthilus         |
| Value   | String            |

This is a unique name for one running instance.

| Name    | **HTTP_ADDRESS** |
|---------|------------------|
| Default | 127.0.0.1:9080   |
| Value   | String           |

This is a IPv4 or IPv6 address followed by ':' and a port number. IPv6 addresses must be enclosed in brackts,
i.e. [::1]. To listen on all interfaces IPv4 and IPv6, specify [::]:9080

| Name    | **HTTP_USE_SSL** |
|---------|------------------|
| Default | False            |
| Value   | Boolean          |

Turn on TLS for the server.

| Name    | **HTTP_TLS_CERT** |
|---------|-------------------|
| Default | -                 |
| Value   | String            |

Define a path to the HTTPS server TLS certificate file containg the certificate and its intermediate certificates (if
any).

| Name    | **HTTP_TLS_KEY** |
|---------|------------------|
| Default | -                |
| Value   | String           |

Define a HTTPS sevrer TLS key file.

| Name    | **HTTP_USE_BASIC_AUTH** |
|---------|-------------------------|
| Default | False                   |
| Value   | Boolean                 |

Turn on HTTP(S) basic authentication for the server.

| Name    | **HTTP_BASIC_AUTH_USERNAME** |
|---------|------------------------------|
| Default | -                            |
| Value   | String                       |

This defines the name for basic authentication.

| Name    | **HTTP_BASIC_AUTH_PASSWORD** |
|---------|------------------------------|
| Default | -                            |
| Value   | String                       |

This defines the password for basic authentication.

| Name    | **RESOLVE_IP** |
|---------|----------------|
| Default | False          |
| Value   | Boolean        |

Nauthilus can resolve the DNS name for a remote client IP address and log this information.

| Name    | **LOG_FORMAT_JSON** |
|---------|---------------------|
| Default | false               |
| Value   | Boolean             |

You can define the log format either being tuples of key=value pairs in a log line or packing it as JSON.

| Name    | **GEOIP_PATH**                        |
|---------|---------------------------------------|
| Default | "/usr/share/GeoIP/GeoLite2-City.mmdb" |
| Value   | String                                |

This is the path to the GEOIP maxmind database file. It can be a city or country databases, Lite or commercial. It is
used with the geoip feature. If you do not use this feature, you do not need to provide a GEOIP database file.

| Name    | **VERBOSE_LEVEL**                                    |
|---------|------------------------------------------------------|
| Default | "none"                                               |
| Value   | * none<br/>* error<br/>* warn<br/>* info<br/>* debug |

Specify the log level. The recommended log level is "info".

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

Specify the backend IP address for an SMTP server.

| Name    | **SMTP_BACKEND_PORT**                  |
|---------|----------------------------------------|
| Default | 5871                                   |
| Value   | Positive integer (a valid port number) |

This is the port of an SMTP server.

| Name    | **IMAP_BACKEND_ADDRESS** |
|---------|--------------------------|
| Default | "127.0.0.1"              |
| Value   | String                   |

Specify the backend IP address for a IMAP server.

| Name    | **IMAP_BACKEND_PORT**                  |
|---------|----------------------------------------|
| Default | 9931                                   |
| Value   | Positive integer (a valid port number) |

This is the port of a IMAP server.

## Redis

| Name    | **REDIS_ADDRESS** |
|---------|-------------------|
| Default | "127.0.0.1"       |
| Value   | String            |

Specify the IP address for a Redis server. This server receives write requests.

| Name    | **REDIS_PORT**                         |
|---------|----------------------------------------|
| Default | 6379                                   |
| Value   | Positive integer (a valid port number) |

This is the port of a Redis server.

| Name    | **REDIS_DATABASE_NUMBER** |
|---------|---------------------------|
| Default | 0                         |
| Value   | Positive integer          |

You can speciy the Redis database number that shall be used by nauthilus.

| Name    | **REDIS_USERNAME** |
|---------|--------------------|
| Default | -                  |
| Value   | String             |

If Redis needs authentication, you can specify a username here.

| Name    | **REDIS_PASSWORD** |
|---------|--------------------|
| Default | -                  |
| Value   | String             |

This is the password for a Redis server, if authentication is required.

| Name    | **REDIS_REPLICA_ADDRESS** |
|---------|---------------------------|
| Default | "127.0.0.1"               |
| Value   | String                    |

Specify the IP address for a Redis server. This server receives read requests.

| Name    | **REDIS_REPLICA_PORT**                 |
|---------|----------------------------------------|
| Default | 6379                                   |
| Value   | Positive integer (a valid port number) |

This is the port of a Redis server.

| Name    | **REDIS_PREFIX** |
|---------|------------------|
| Default | "as_"            |
| Value   | String           |

All Redis keys are prefixed.

| Name    | **REDIS_SENTINELS** |
|---------|---------------------|
| Default | -                   |
| Value   | String              |

If you want to use Redis sentinels, you can specify a space separated list of sntinel servers. Each of the form
IP-address:port.

| Name    | **REDIS_SENTINEL_MASTER_NAME** |
|---------|--------------------------------|
| Default | -                              |
| Value   | String                         |

This sets the sentinel master name and is required if using sentinels!

| Name    | **REDIS_SENTINEL_USERNAME** |
|---------|-----------------------------|
| Default | -                           |
| Value   | String                      |

If Redis sentinels need authentication, you can specify a username here.

| Name    | **REDIS_SENTINEL_PASSWORD** |
|---------|-----------------------------|
| Default | -                           |
| Value   | String                      |

This is the password for Redis sentinel servers, if authentication is required.

## SQL-Backend

| Name    | **SQL_MAX_CONNECTIONS** |
|---------|-------------------------|
| Default | 10                      |
| Value   | Positive integer        |

This is the maximum number of SQL connections that can be opened.

| Name    | **SQL_MAX_IDLE_CONNECTIONS** |
|---------|------------------------------|
| Default | 10                           |
| Value   | Integer                      |

This is the maximum number of idle SQL connections.

## Cache-Backend

| Name    | **REDIS_POSITIVE_CACHE_TTL** |
|---------|------------------------------|
| Default | 3600                         |
| Value   | Positive integer (seconds)   |

This sets the time-to-live parameter for objects in a positive Redis cache which hold user information about the known
passwords. Information on this cache is SHA-256 hashed and 128 bit truncated, if the developer mode is turned off (
default).

| Name    | **REDIS_NEGATIVE_CACHE_TTL** |
|---------|------------------------------|
| Default | 3600                         |
| Value   | Positive integer (seconds)   |

This sets the time-to-live parameter for objects in a negative Redis cache which hold user information about all known
passwords. Information on this cache is SHA-256 hashed and 128 bit truncated, if the developer mode is turned off (
default).

## OAuth2 / Ory Hydra settings

| Name    | **HTTP_STATIC_CONTENT_PATH** |
|---------|------------------------------|
| Default | "/usr/app/static"            |
| Value   | String                       |

Define the path where Nauthilus will find OAuth2 pages and content. The default is perfect if using Docker.

| Name    | **DEFAULT_LOGO_IMAGE** |
|---------|------------------------|
| Default | "/static/img/logo.png" |
| Value   | String                 |

Path to the company logo. The path is the location part of an HTTP url.

| Name    | **HYDRA_ADMIN_URI**     |
|---------|-------------------------|
| Default | "http://127.0.0.1:4445" |
| Value   | String                  |

This is the protected URI to the Ory Hydra admin endpoint. You must change this if you plan on using OAuth2!

| Name    | **HTTP_CLIENT_SKIP_TLS_VERIFY** |
|---------|---------------------------------|
| Default | false                           |
| Value   | Boolean                         |

Nauthilus does communicate to Ory Hydra using HTTP. If the server certificate can not be validated, you may turn of
verification

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

> Note:
> 
> The current implementation uses hard-coded settings for TOTP-secrets. These are:
> 
> * algorithm: SHA1
> * Digits: 6

| Name    | **LOGIN_2FA_PAGE** |
|---------|--------------------|
 | Default | "/register"        |
| Value   | String             |

This is the URL path where a user can register a second factor for authentication.

> Note:
> 
> The path is relative to /2fa/v1, which is a hardcoded default!

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