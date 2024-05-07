---
title: Reference
description: Configuration of environment variables in Nauthilus
keywords: [Configuration, Environment]
sidebar_position: 1
---
# Reference

This page describes all available environment variables, there meaning and there defaults.

<!-- TOC -->
* [Reference](#reference)
  * [Nauthilus](#nauthilus)
  * [Nginx](#nginx)
  * [OAuth2 / Ory Hydra settings](#oauth2--ory-hydra-settings)
    * [Login page (including 2FA page)](#login-page-including-2fa-page)
    * [Device page](#device-page)
    * [Consent page](#consent-page)
    * [Logout page](#logout-page)
    * [2FA specific settings](#2fa-specific-settings)
    * [WebAuthn](#webauthn)
<!-- TOC -->

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
