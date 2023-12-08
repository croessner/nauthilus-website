---
title: Getting started
sidebar_position: 3
---
# Getting started

Find out how to deploy Nauthilus.

<!-- TOC -->
* [Getting started](#getting-started)
  * [Preliminary consideration](#preliminary-consideration)
  * [Example use cases](#example-use-cases)
  * [Install software](#install-software)
  * [Integration](#integration)
    * [Dovecot](#dovecot)
    * [Nginx](#nginx)
    * [Cyrus SASL](#cyrus-sasl)
    * [SSO](#sso)
  * [Final words](#final-words)
<!-- TOC -->

## Preliminary consideration

Before starting to deply a service such as Nauthilus, you must know what you want
to achieve with this software. Below is just an example of what it can do for you.

## Example use cases

1. Using Nauthilus in your mail server environment
2. Using Nauthilus for web pages that support OAuth 2 Open-ID Connect

## Install software

First install docker on a system that shall be the host for Nauthilus. After that
create your docker compose file with Nauthilus. You may also add additional services
like redis or SQL as well.

Configure your environment variables documented in [Reference](/docs/configuration/reference). This
settings are static and changes will always need a restart of the service.

Create the nauthilus yaml configuration file. See the [configuration file](/docs/configuration/configuration-file)
document for details.

Depending on the backend you wish to use, you must provide the required settings.

A normal Nauthilus installation always uses **cache** as its first backend followed by
one of **ldap**, **sql** or **lua. You may also specify all of them, but you can only
address one single instance of a database type at runtime, meaning there do not exist
to **ldap** or three **sql** chained backends.

The next step is to decide what protocols you want to serve. Nauthilus is desinged
to lookup several settings depending on a protocol. The protocol is set in an HTTP
request using the header **AUTH-Protocol**. This information is required to select the
correct configuration block inside a backend section of the configuration file.

You can also define a **default** protocol in exactly one of the protocol sections
for each backend. In this case the settings will be taken from there, if no protocol
information was provided.

A protocol section will then list all required filters/attributes and mappings to gather
runtime settings for an incoming request.

In addition to this, each protocol block does define a cache prefix, so the underlying
Redis database has different places to store different information for all protocol
requests.

This brings us to Redis. This is the main store for Nauthilus. You must decide on
how to create this environment. At the current moment you can use a single
instance of a master node and one slave. If you need more replicas, it is suggested
to use Redis sentinel for that purpose. You may also use a load balancer like
HAProxy and fake such a distributed Redis system.

## Integration

### Dovecot

You can integrate Nautilus in many ways. One is Dovecot with its Lua backend. An
HTTP client must provide all required information for a request. Nauthilus will
anser with HTTP response headers (or JSON, if using a different endpoint...).
For this have a look at the Dovecot Lua example [here](/docs/examples/dovecot-lua).

### Nginx

An alternative is the Nginx reverse proxy. For details on how to integrate it,
follow [this link](/docs/examples/nginx-mail-plugin).

The recommended way of using it is the Dovecot Lua plugin, as it provides most
flexible settings.

### Cyrus SASL

If Dovecot is not your SMTP submission service and you are using Postfix, you
may want to use Cyrus SASL with the http interface. This is the most weakiest
integration and not all power of Nauthilus can be used to fight attackers!

### SSO

If you plan on using Nauthilus for SSO and your web applications, you should
integrate the software into a load balancer. Define routes for the following
endpoints (example is for HAProxy):

```haproxy
acl oidc path_beg,url_dec -m beg -i /login /device /consent /logout /2fa/v1 /notify /static
```

Now you can route to a different backend:

```haproxy
backend be_nauthilus_oidc
  mode http
  balance roundrobin
  option forwardfor
  option log-health-checks
  option httpchk
  http-check connect ssl alpn h2,http/1.1
  http-check send meth GET uri /ping body "pong"
  http-check expect status 200
  http-request set-header X-SSL %[ssl_fc]
  http-request set-header X-SSL-Session-ID %[ssl_fc_session_id,hex]
  http-request set-header X-SSL-Client-Verify %[ssl_c_verify]
  http-request set-header X-SSL-Client-DN %{+Q}[ssl_c_s_dn]
  http-request set-header X-SSL-Client-CN %{+Q}[ssl_c_s_dn(cn)]
  http-request set-header X-SSL-Issuer %{+Q}[ssl_c_i_dn]
  http-request set-header X-SSL-Client-NotBefore %{+Q}[ssl_c_notbefore]
  http-request set-header X-SSL-Client-NotAfter %{+Q}[ssl_c_notafter]
  http-request set-header X-SSL-Subject-DN %{+Q}[ssl_c_s_dn]
  http-request set-header X-SSL-Issuer-DN %{+Q}[ssl_c_i_dn]
  http-request set-header X-SSL-Client-Subject-DN %{+Q}[ssl_c_s_dn]
  http-request set-header X-SSL-Client-Issuer-DN %{+Q}[ssl_c_i_dn]
  http-request set-header X-SSL-Cipher %[ssl_fc_cipher]
  http-request set-header X-SSL-Protocol %[ssl_fc_protocol]
  ... other settings ...
```

Nauthilus is not an OAuth 2 Open-ID server! It requires additional software to
be part of such. In this case Ory Hydra is required. See [this link](https://ory.sh/hydra)
to learn on how to install and configure the required service.

If hydra was installed, you must configure each of your web services. Each
client ID must be mirrored to the Nauthilus configuration file, because
Nauthilus does provide several **claims** to the HTTP client upon a successful
login.

## Final words

This is just a qick walk-through and you are definetely invited to read all the
other documents as well. Especially the reference and configuration file documents
are the first place for settings in Nauthilus.

Have fun.
