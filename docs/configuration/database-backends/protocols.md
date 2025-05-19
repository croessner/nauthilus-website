---
title: Protocols
description: Protocol-specific settings for backends in Nauthilus
keywords: [Configuration, Protocols, Backends]
sidebar_position: 2
---

# Protocols

Backends carry configuration information about protocols. A protocol is something like **smtp** or **imap** but can be
anything else. As Nauthilus is used over HTTP(S), the protocol is shiiped with the HTTP-request header Auth-Protocol as
described in the [Nginx-protocol](https://nginx.org/en/docs/mail/ngx_mail_auth_http_module.html#proxy_protocol).

If Nauthilus has a protocol definition for a protocol, rules applied to that section are taken for password validation.

You may add a **default** protocol to LDAP and Lua, which will be used for protocols without having their own section.
If there is no default keyword, the backend will fail for unknown protocols. In case of using Lua and LDAP at the same
time, there will be a chance that the other backend has information for the requested protocol.

If all backends fail due to a missing definition, a temporary error is raised and the client can not authenticate.

## Special Protocols

If Nauthilus is called with the location **/api/v1/service/nginx**, the protocols **smtp** and **imap** will return
additional HTTP response headers:

**Auth-Server** and **Auth-Port** (
see [Nginx-protocol](https://nginx.org/en/docs/mail/ngx_mail_auth_http_module.html#proxy_protocol))

If Nauthilus is used for HTTP basic authentication (Nginx backend), the protocol **http** and **internal-basic-auth** are
understood.

Both protocols will honor the **X-Forwarded-For** header to identify the real client IP address. This is important to
have the brute force feature working correctly. You do not want your reverse proxy (if any) be blocked.

Nauthilus can be protected with HTTP basic authorization, which is configured with the environment variables *
*HTTP_USE_BASIC_AUTH**, **HTTP_BASIC_AUTH_USERNAME** and **HTTP_BASIC_AUTH_PASSWORD**. If you do not want a static
username and password, you can add the **internal-basic-auth** protocol to one of your protocol definitions and Nauthilus
will use this backend for username and passowrd checks.

The protocol **ory-hydra** is for OAuth2/OpenID Connect. Note that it is ory-hydra and not oauth2, as other servers may
appear in the future with different bindings/dependencies to Nauthilus.

The protocol **account-provider** is used internally when Nauthilus needs to retrieve a list of all known user accounts from the backend databases. This happens when the API endpoint is called with the `mode=list-accounts` query parameter.

## Example Configuration

In the LDAP and Lua backend configurations, you can specify protocol-specific settings:

```yaml
ldap:
  search:
    - protocol:
        - imap
        - pop3
        - lmtp
        - sieve
        - doveadm
        - indexer-worker
        - default
      cache_name: dovecot
      base_dn: ou=people,ou=it,dc=example,dc=com
      # ...

    - protocol:
        - smtp
        - submission
      cache_name: submission
      # ...

    - protocol: ory-hydra
      cache_name: oidc
      # ...
```

Similarly for Lua:

```yaml
lua:
  search:
    - protocol:
        - imap
        - pop3
        - lmtp
        - sieve
        - doveadm
        - indexer-worker
        - default
      cache_name: dovecot

    - protocol:
        - smtp
        - submission
      cache_name: submission

    - protocol: ory-hydra
      cache_name: oidc
```