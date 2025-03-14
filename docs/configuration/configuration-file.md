---
title: Configuration file
description: Full documentation for the configuration file
keywords: [Configuration, File]
sidebar_position: 2
---
<!-- TOC -->
  * [Structure](#structure)
    * [Features](#features)
    * [General configuration settings](#general-configuration-settings)
  * [Reloading](#reloading)
  * [server](#server)
    * [Meaning](#meaning)
    * [server::address](#serveraddress)
    * [server::haproxy_v2](#serverhaproxy_v2)
    * [server::http3](#serverhttp3)
    * [server::disabled\_endpoints](#serverdisabled_endpoints)
      * [Meaning](#meaning-1)
    * [server::http\_client](#serverhttp_client)
    * [server::tls](#servertls)
      * [server::tls::enabled](#servertlsenabled)
      * [server::tls::cert and server::tls::key](#servertlscert-and-servertlskey)
      * [server::tls::http\_client\_skip\_verify](#servertlshttp_client_skip_verify)
    * [server::basic\_auth](#serverbasic_auth)
      * [server::basic\_auth::enabled](#serverbasic_authenabled)
      * [server::basic\_auth::username and server::basic\_auth::password](#serverbasic_authusername-and-serverbasic_authpassword)
    * [server::instance\_name](#serverinstance_name)
    * [server::logs](#serverlogs)
      * [server::log::json](#serverlogjson)
      * [server::log::level](#serverloglevel)
      * [server::log::debug\_modules](#serverlogdebug_modules)
    * [server::backends](#serverbackends)
    * [server::features](#serverfeatures)
    * [server::brute\_force\_protocols](#serverbrute_force_protocols)
    * [server::ory\_hydra\_admin\_url](#serverory_hydra_admin_url)
    * [server::dns](#serverdns)
      * [server::dns::resolver](#serverdnsresolver)
      * [server::dns::timeout](#serverdnstimeout)
      * [server::dns::resolve\_client\_ip](#serverdnsresolve_client_ip)
    * [server::insights](#serverinsights)
      * [server::insights::enable\_pprof](#serverinsightsenable_pprof)
      * [server::insights::enable\_block\_profile](#serverinsightsenable_block_profile)
    * [server::redis](#serverredis)
      * [server::redis::database\_number](#serverredisdatabase_number)
      * [server::redis::prefix](#serverredisprefix)
      * [server::redis::pool\_size](#serverredispool_size)
      * [server::redis::idle\_pool\_size](#serverredisidle_pool_size)
      * [server::redis::positive\_cache\_ttl and server::redis::negative\_cache\_ttl](#serverredispositive_cache_ttl-and-serverredisnegative_cache_ttl)
      * [server::redis::master](#serverredismaster)
      * [server::redis::master::address](#serverredismasteraddress)
      * [server::redis::master::username and server::redis::master::password](#serverredismasterusername-and-serverredismasterpassword)
      * [server::redis::replica](#serverredisreplica)
      * [server::redis::replica::address](#serverredisreplicaaddress)
      * [server::redis::sentinels](#serverredissentinels)
      * [server::redis::sentinels::master](#serverredissentinelsmaster)
      * [server::redis::sentinels::addresses](#serverredissentinelsaddresses)
      * [server::redis::sentinels::username and server::reids::sentinels::password](#serverredissentinelsusername-and-serverreidssentinelspassword)
      * [server::redis::cluster](#serverrediscluster)
      * [server::redis::cluster::addresses](#serverredisclusteraddresses)
    * [server::master\_user](#servermaster_user)
      * [server::master\_user::enabled](#servermaster_userenabled)
      * [server::master\_user::delimiter](#servermaster_userdelimiter)
    * [server::frontend](#serverfrontend)
      * [server::frontend::enabled](#serverfrontendenabled)
      * [server::frontend::csrf\_secret](#serverfrontendcsrf_secret)
      * [server::frontend::cookie\_store\_auth\_key and server::frontend::cookie\_store\_encryption\_key](#serverfrontendcookie_store_auth_key-and-serverfrontendcookie_store_encryption_key)
    * [server::prometheus\_timer](#serverprometheus_timer)
      * [server::prometheus\timer::enabled](#serverprometheustimerenabled)
      * [server::prometheus\timer::labels](#serverprometheustimerlabels)
  * [realtime\_blackhole\_lists](#realtime_blackhole_lists)
    * [realtime\_blackhole\_lists::lists:](#realtime_blackhole_listslists)
    * [realtime\_blackhole\_lists::threshold](#realtime_blackhole_liststhreshold)
    * [realtime\_blackhole\_lists::ip\_whitelist](#realtime_blackhole_listsip_whitelist)
  * [cleartext\_networks](#cleartext_networks)
  * [relay\_domains](#relay_domains)
    * [relay\_domains::static](#relay_domainsstatic)
  * [backend\_server\_monitoring](#backend_server_monitoring)
    * [backend\_server\_monitoring::backend\_servers](#backend_server_monitoringbackend_servers)
  * [brute\_force](#brute_force)
      * [Recommendation](#recommendation)
    * [brute\_force::buckets](#brute_forcebuckets)
    * [brute\_force::ip\_whitelist](#brute_forceip_whitelist)
  * [password\_nonce](#password_nonce)
  * [oauth2](#oauth2)
      * [Configuration flow](#configuration-flow)
      * [About scopes and claims](#about-scopes-and-claims)
      * [User defined scopes and claims](#user-defined-scopes-and-claims)
    * [oauth2::clients](#oauth2clients)
    * [oauth2::custom\_scopes](#oauth2custom_scopes)
* [Database backends](#database-backends)
  * [Protocols](#protocols)
    * [Special protocols](#special-protocols)
  * [Macros](#macros)
    * [Macro form](#macro-form)
    * [Modifier](#modifier)
    * [Long variables](#long-variables)
      * [Macro example](#macro-example)
  * [Cache namespaces](#cache-namespaces)
  * [Encrypted passwords](#encrypted-passwords)
  * [LDAP](#ldap)
    * [Structure](#structure-1)
    * [ldap::config](#ldapconfig)
      * [If using SASL/EXTERNAL:](#if-using-saslexternal)
      * [Pooling](#pooling)
      * [Bind method](#bind-method)
    * [ldap::search](#ldapsearch)
    * [Definition of a search list](#definition-of-a-search-list)
      * [Filter](#filter)
      * [Mapping](#mapping)
  * [Lua backend](#lua-backend)
    * [lua::features](#luafeatures)
    * [Definition of a "feature" list](#definition-of-a-feature-list)
    * [lua::filters](#luafilters)
    * [Definition of a "filter" list](#definition-of-a-filter-list)
    * [lua::actions](#luaactions)
    * [Definition of an "actions" list](#definition-of-an-actions-list)
    * [lua::config](#luaconfig)
    * [lua::search](#luasearch)
    * [Definition of a "search" list](#definition-of-a-search-list-1)
  * [Full example (standalone)](#full-example-standalone)
<!-- TOC -->

## Structure

The configuration file contains several main sections, where each is responsible for a particular category of runtime behavior. A
full example is shown at the end of this document.

### Features

* realtime\_blackhole\_lists
* cleartext\_networks
* relay\_domains
* brute\_force
* lua
* backend\_server\_monitoring

### General configuration settings

* server
* csrf\_secret
* cookie\_store\_auth\_key
* cookie\_store\_encryption\_key
* oauth2
* ldap
* lua

Each section has individual subsections. See details below. If you do not require some sections, please do not include
it into the configuration file.

--- 

## Reloading

You can send a HUP-signal to Nauthilus, which will stop LDAP connections, reload the configuration file and
restart the database connections. The main web server process will be still alive.

If you change settings deticated to the web server itself, you must first reload the configuration file and send a 
second signal **-SIGUSR1** to restart the server process itself.

:::warning
Changing environment variables need a full restart of the service. Re-reading variables can not be done by sending signals.
:::

---

## server

### Meaning

This section defines all required settings that are required to run the server.

### server::address
_Default: "127.0.0.1:9080"_

This is the IPv4 or IPv6 addresses combined with a TCP port.

```yaml
server:
  address: "[::]:9443"
```

### server::haproxy_v2
_Default: false_

If this setting is turned on (true), Nauthilus can make use of the HAproxy version 2 protocol header to identify the original client request.

```yaml
server:
  haproxy_v2: true
```

### server::http3
_Default: false_

Enable HTTP/3 support for the server. There does not exist the PROXY protocol for this version!

### server::disabled\_endpoints

_New in version 1.4.9_<br/>
_Default: All endpoints are enabled_

It is possible to disable certain HTTP location endpoints that are not needed.

```yaml
server:
  disabled_endpoints:
    auth_header: false
    auth_json: false
    auth_basic: false
    auth_nginx: false
    auth_saslauthd: false
```

:::tip
Disableing unused endpoints may enhance overall security!
:::

#### Meaning

| Key-name        | location               | description                                                    |
|-----------------|------------------------|----------------------------------------------------------------|
| auth\_header    | /api/v1/auth/header    | Turn off requests based on HTTP headers                        |
| auth\_json      | /api/v1/auth/json      | Turn off HTTP JSON-POST requests                               |
| auth\_basic     | /api/v1/auth/basic     | Turn off HTTP Basic Authorization requests (recommended!)      |
| auth\_nginx     | /api/v1/auth/nginx     | Turn off Nginx based requests used by the mail plugin of Nginx |
| auth\_saslauthd | /api/v1/auth/saslauthd | Turn off saslauthd requests used with cyrus-sasl               |
| custom\_hooks   | /api/v1/custom/*       | Turn off all Lua based custom hooks                            |

### server::http\_client

Whenever Nauthilus is acting as an HTTP client, a common shared Go-builtin HTTP client is used to handle all requests.

There do exist the following HTTP clients in Nauthilus:

| Scope   | Usage                                                                                     |
|---------|-------------------------------------------------------------------------------------------|
| core    | If the Ory hydra frontend is turned on, all admin-API requests are handled by this client |
| action  | Used for Lua actions, if HTTP requests are used                                           |
| filter  | Used for Lua filters, if HTTP requests are used                                           |
| feature | Used for Lua featuress, if HTTP requests are used                                         |
| hook    | Used for Lua custom hooks, if HTTP requests are used                                      |

Settings are shared with all HTTP clients!

| Setting                           | Meaning (Used from official Go docs)                                                                                                                  | Default      |
|-----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|--------------|
| max\_connections\_per\_host       | Limits the total number of connections per host, including connections in the dialing, active, and idle states. On limit violation, dials will block. | 0, no limits |
| max\_idle\_connections            | Controls the maximum number of idle (keep-alive) connections across all hosts.                                                                        | 0, no limits |
| max\_idle\_connections\_per\_host | Controls the maximum idle (keep-alive) connections to keep per-host.                                                                                  | 0, no limits |
| idle\_connection\_timeout         | Is the maximum amount of time an idle (keep-alive) connection will remain idle before closing itself.                                                 | 0, no limits |

Units for the timeout option should add a time unit like

* s - seconds
* m - minutes
* h - hours

```yaml
server:
  http_client:
      max_connections_per_host: 10
      max_idle_connections: 5
      max_idle_connections_per_host: 1
      idle_connection_timeout: 60s
```

### server::tls

This object defines TLS related settings.

#### server::tls::enabled
_Default: false_

This flag turns on (true) TLS support in the server.

```yaml
server:
  tls:
    enabled: true
```

#### server::tls::cert and server::tls::key
_Default: ""_

These two settings define a path to an X509 PEM-formatted certificate and key.

```yaml
server:
  tls:
    cert: /usr/local/etc/nauthilus/localhost.localdomain.pem
    key: /usr/local/etc/nauthilus/localhost.localdomain.key.pem
```

#### server::tls::http\_client\_skip\_verify
_Default: false_

This flag turns on (true) insecure TLS connections for HTTP(s) requests that are originating from Nauthilus to some remote.

```yaml
server:
  tls:
    http_client_skip_verify: true
```

### server::basic\_auth

This object defines basic authorization settings.

#### server::basic\_auth::enabled
_Default: false_

This flag turns on (true) **Basic Auth support** in the server.

#### server::basic\_auth::username and server::basic\_auth::password
_Default: ""_

These settings define a username and its password that is required by HTTP(s) clients to communicate with Nauthilus.

### server::instance\_name
_Default: "nauthilus"_

This defines the application name. If not defined, it defaults to **nauthilus**

### server::logs

This object defined logging relates settings.

#### server::log::json
_Default: false_

This flag turns on (true) logging in JSON format.

```yaml
server:
  log:
    json: true
```

#### server::log::level
_Default: "none"_

This string defines the log level. It is one of:

| **Level** | Comment                  |
|-----------|--------------------------|
| none      | Entirely turn of logging |
| debug     | See debug modules below! |
| info      |                          |
| warn      |                          |
| error     |                          |

```yaml
server:
  log:
    level: debug
```
#### server::log::debug\_modules
_Default: empty list_

if debugging is turned on, only very limited debug messages are logged by default. You can increase logging by activating
additional log modules. This is the list of all available debug modules:

| **Module**   | Application                                                                            |
|--------------|----------------------------------------------------------------------------------------|
| all          | Full debugging                                                                         |
| auth         | This turns on logging for the main authentication process                              |
| hydra        | Communication with the Ory hydra server                                                |
| webauthn     | Turn on debugging for WebAuthn (under development)                                     |
| statistics   | Prometheus related debugging                                                           |
| whitelist    | Show whitelist related debugging                                                       |
| ldap         | Show LDAP command and filter related debugging                                         |
| ldap\_pool   | Show LDAP-pool related debugging such as free/busy/closed connections and housekeeping |
| cache        | Turn on cache backend related debugging                                                |
| brute\_force | Turn on brute-force releated debugging                                                 |
| rbl          | Turn on RBL (realtime-blackhole-list) related debugging                                |
| action       | Turn on Lua post-action related debugging                                              |
| feature      | Turn on feature related debugging                                                      |
| lua          | Turn on Lua releated debugging                                                         |
| filter       | Turn on filter related debugging                                                       |

```yaml
server:
  log:
    debug_modules:
      - auth
      - ldap 
      - filter
```

### server::backends
_Default: none_<br/>
_required_

This object defines, which backends are enabled. You **must** define at least one backend!

| Name  | Comment                                                                                          |
|-------|--------------------------------------------------------------------------------------------------|
| cache | The Redis cache backend is used for positive and failed login requests and **should** be enabled |
| ldap  | This is the native LDAP backend. See settings below for configuration                            |
| lua   | This is a Lua backend                                                                            |

:::note
The **cache* backend not only caches positive and negative requests. It is also a major component for the brute force buckets to detect
users with repetitive wrong passwords.
:::

:::warning
The cache backend should always be the first backend. The order of backends matters!
:::

### server::features
_Default: empty list_

This object defines runtime features.

Here is a list of features that can be turned on:

| Name                        | Usage                                                                                                     |
|-----------------------------|-----------------------------------------------------------------------------------------------------------|
| lua                         | General purpose Lua feature. You can have as many features as you like. They run in sequential order      |
| tls\_encryption             | Clients must be connected securely to a service to be allowed to authenticate                             |
| relay\_domains              | If the login name equals to an email address, the domain component is compared to a list of known domains |
| rbl                         | Check a client IP address against realtime blackhole lists                                                |
| backend\_server\_monitoring | This is a special feature that is not used for filtering                                                  |

These features are primarely used to filter out requests before the main authentication process starts.

:::note
The features are run one-by-one. The rbl feature does query lists in parallel. The lua feature is always run as first feature and is the only one that can
skip further processing of other features!
:::

The **backend\_server\_monitoring** feature turns on a background job that does a health check for any kind of backend servers. It holds an in-memory list of alive servers that can be
used in Lua scripts to select healthy servers.

```yaml
server:
  features:
    - tls_encryption
    - lua
    - rbl 
```

### server::brute\_force\_protocols
_Default: empty list_

This object defines a list of protocols for which the brute force protection is turned on.

When a service talks to Nauthilus, it must provide a **protocol** that is used by a remote client while authenticating.

This list describes protocols for which Nauthilus does brute force checks.

Here is a good working example that can be taken in a production environment:

```yaml
server:
  brute_force_protocols:
    - imap
    - imaps
    - submission
    - smtp
    - smtps
    - ory-hydra
    - http
```

:::note
While most of the protocols are free to chose, **ory-hydra** has a special meaning for Nauthilus and is assigned to the
communication between Nauthilus and the Ory hydra serverr.
:::

### server::ory\_hydra\_admin\_url
_Default: "http://127.0.0.1:4445"_

This setting is the Ory hydra admin URL.

```yaml
server:
  ory_hydra_admin_url: https://hydra.example.com:4445
```

### server::dns

This object defines settings related to the DNS name resolver.

#### server::dns::resolver
_Default: ""_

If this setting is given, Nauthilus does not use the Go internal DNS resolver. Instead, it uses the provided resolver for DNS resolution.

```yaml
server:
  dns:
    resolver: 192.168.0.1
```

#### server::dns::timeout
_Default: 5_

If a custom DNS resolver is set, you can specify a default timeout in seconds, after which DNS queries are aborted without waiting for a result.

```yaml
server:
  dns:
    timeout: 3
```

#### server::dns::resolve\_client\_ip
_Default: false_

If a DNS reverse lookup should be done for incoming client requests, you can turn on (true) this feature.

```yaml
server:
  dns:
    resolve_client_ip: true
```

:::warning
Turning on this feature will heavily increase network latency and DNS resolver load. It is suggested to use this feature with care.
:::

### server::insights

This object defines settings related to **go pprof** and is mainly useful for developers.

#### server::insights::enable\_pprof
_Default: false_

Enable (true) pprof in Go for debugging purposes.

```yaml
server:
  insights:
    enable_pprof: true
```
#### server::insights::enable\_block\_profile
_Default: false_

If pprof is enabled (required for this flag), you can also activate a block profile, which helps to find blocking code.

```yaml
server:
  insights:
      enable_block_profile: true
```

### server::redis

This object defines settings related to the Redis server.

#### server::redis::database\_number
_Default: 0_

If Redis is configured to run standalone, master-slave or as sentinel, you can select the database number that Nauthilus must use.

```yaml
server:
  redis:
      database_number: 2
```

#### server::redis::prefix
_Default: ""_

You can define a prefix that has to be used for any keys in Redis.

```yaml
server:
  redis:
    prefix: "nt_"
```

:::note
This prefix is for Nauthilus internal keys only. If you chode to use Redis within Lua, you have to manage Redis keys yourself
:::

:::tip
You may define custom prefixes in Lua with "ntc:" Like "Nauthilus-custom". That way you have a difference between built-in keys and user defined keys.
:::

#### server::redis::pool\_size
_Default: 0_<br/>
_required_

This is a Redis pool size. The pool is managed by the underlying redis library go-redis.

```yaml
server:
  redis:
    pool_size: 10
```

#### server::redis::idle\_pool\_size
_Default: 0_

This is a Redis idle pool size. The pool is managed by the underlying redis library go-redis.

```yaml
server:
  redis:
    idle_pool_size: 2
```

#### server::redis::positive\_cache\_ttl and server::redis::negative\_cache\_ttl
_Default: 3600_

Both values set the expiration value for Redis keys in seconds. The positive cache TTL is for authenticated users, while the
negative cache TTL is for authentication failures. The latter may be larger as it is also used in the brute-force logic to
detect users that try to log in with a repeating wrong password. Such requests are never treated as an attack.

```yaml
server:
  redis:
    positive_cache_ttl: 3600
    negative_cache_ttl: 7200
```

_Changes in version 1.4.9:_

Units should now add a time unit like

* s - seconds
* m - minutes
* h - hours

#### server::redis::master

If running Redis standalone or in master-slave mode, you have to define the master object.

#### server::redis::master::address
_Default: "127.0.0.1:6379"_

This is the socket for a Redis connection to either a standalone server or for a master.

```yaml
server:
  redis:
    master:
      address: 127.0.0.1:6379
```

#### server::redis::master::username and server::redis::master::password
_Default: empty_

This is an optional username and password for Redis, if the service requires authentication.

```yaml
Server:
  redis:
    master:
      username: some_user
      password: some_secret
```

#### server::redis::replica

This object defines a replica to a master. Currently, there is only support for one master and one replica. If you need more
replica server, consider using sentinel instead or use some load balancer in front of Nauthilus that may distribute replica
connections to more than one replica instance.

#### server::redis::replica::address
_Default: ""_

This is the socket for a Redis connection to a replica instance.

```yaml
server:
  redis:
    replica:
      address: 10.10.10.10:6379
```

#### server::redis::sentinels

NAuthilus can connect to Redis sentinels. The following options define such a setup.

#### server::redis::sentinels::master
_Default: ""_

This is the name of the sentinel master.

```yaml
server:
  redis:
    sentinels:
      master: mymaster
```

#### server::redis::sentinels::addresses
_Default: empty list_

This is a list of Redis sentienl sockets.

```yaml
server:
  redis:
    sentinels:
      addresses:
        - 127.0.0.1:26379
        - 127.0.0.1:26378
        - 127.0.0.1:26377
```

:::note
At least one sentinel address is required.
:::

Here is an example for K8s redis-operator sentinel, if you run Nauthilus in Kubernetes on-premise and a NodePort service:

```yaml
server:
  redis:
    sentinels:
      master: myMaster
      addresses:
        - redis-sentinel-sentinel-0.redis-sentinel-sentinel-headless.ot-operators.svc.cluster.local:26379
        - redis-sentinel-sentinel-1.redis-sentinel-sentinel-headless.ot-operators.svc.cluster.local:26379
        - redis-sentinel-sentinel-2.redis-sentinel-sentinel-headless.ot-operators.svc.cluster.local:26379
```

#### server::redis::sentinels::username and server::reids::sentinels::password
_Default: ""_

Both of these parameters are optional settings, if your Redis sentinels require authentication.

```yaml
server:
  redis:
    sentinels:
      username: some_user
      password: some_secret
```

#### server::redis::cluster

If NAuthilus should be connected to a Redis cluster, the following settings can be set to do so.

#### server::redis::cluster::addresses
_Default: empty list_

This is a list of one or more Redis sockets pointing to a Redis cluster.

```yaml
server:
  redis:
    cluster:
      addresses:
      - 127.0.0.1:6379
      - 127.0.0.1:6378
      - 127.0.0.1:6377
```

### server::master\_user

This object defines settings related to a so-called **master user**

#### server::master\_user::enabled
_Default: false_

If this flag is turned on (true), Nauthilus honors login usernames that are master users. A master user looks something like this:

```
user@domain.tld*masteruser
```

As you can see, the master user is separated from the real login name by a "*" character followed by the name of a master user. If NAuthilus
detecs such a user, it will do authentication against the master user.

```yaml
server:
  master_user:
    enabled: true
```

#### server::master\_user::delimiter
_Default: "*"_

This is the character that splits the real username from the master user.

```yaml
server:
  master_user:
    delimiter: "*"
```

### server::frontend

Nauthilus specific settings for the frontend (OIDC)

#### server::frontend::enabled
_Default: false_

Turn on the frontend.

```yaml
server:
  frontend:
    enabled: true
```

#### server::frontend::csrf\_secret
_Default: ""_<br/>
_required_

This key is required whenever CSRF (cross-site-request-forgery) attacks must be prevented. This is currently used, if
Nauthilus is configured to communicate with Ory Hydra. The login, consent and logout pages are protected with a CSRF
token. This value defines the secret used for that token.

This value **MUST** be 32 bytes long.

#### server::frontend::cookie\_store\_auth\_key and server::frontend::cookie\_store\_encryption\_key
_Default: ""_<br/>
_required_

These keys are used to encrypt and decrypt session cookies.

Both values **MUST** be 32 bytes long.

### server::prometheus\_timer

Turn on several Prometheus labels, which are timers for certain aspects of the application.

#### server::prometheus\timer::enabled

Turn on the prometheus timers.

```yaml
server:
  prometheus_timer:
    enabled: true
```

#### server::prometheus\timer::labels

The following labels can be turned on:

| Label name   | Description                                              |
|--------------|----------------------------------------------------------|
| account      | Mode "list-accounts" timer                               |
| action       | Timers for Lua actions                                   |
| backend      | Timers for backends                                      |
| brute\_force | Timers for the brute force functions                     |
| feature      | Timers for all features                                  |
| filter       | Timers for Lua filters                                   |
| request      | Timer for the entire client request without post actions |
| store\_totp  | Timer for storing a new TOTP secret to a backend         |
| post\_action | Timers for Lua post actions                              |
| dns          | Timers for DNS queries                                   |

Example:

```yaml
server:
  prometheus_timer:
    enabled: true
    labels:
      - request
      - dns
```

---

## realtime\_blackhole\_lists

This is the *rbl* feature. It checks a remote client IP address against a list of defined RBL lists. The lists are run
simultaneously. They may contain a weight parameter which is added to a total value. If that value raises a threshold,
the features directly returns with a client reject.

### realtime\_blackhole\_lists::lists:
_Default: empty list_

This section defines one or more RBL lists. A RBL list requires the following fields:

| Field name     | Description                                                                                             |
|----------------|---------------------------------------------------------------------------------------------------------|
| name           | Example RBL name                                                                                        |
| rbl            | Domain part that is appended to the reversed IP address                                                 |
| ipv4           | Boolean that enables the list for IPv4 support                                                          |
| ipv6           | Boolean that enables the list for IPv6 support                                                          |
| return\_code   | Expected DNS return code, if an IP address was listed                                                   |
| allow\_failure | Return a temporary failure, if a DNS lookup to the given list failed (not NXDOMAIN errors!)             |
| weight         | This value defines the weight for the given RBL list. See the **threshold** description for the meaning |

The **weight** value may be negative.

:::tip
The suggested **weight** value should be between -255 and 255. A negative weight turns the list into a whitelist
:::
> 
### realtime\_blackhole\_lists::threshold
_Default: 0_

The threshold parameter defines an absolute value which tells Nauthilus, when to abort further list lookups. If the sum
of all weights is above the threshold value, the feature triggers an immediate client reject.

### realtime\_blackhole\_lists::ip\_whitelist
_Default: empty list_

You can define IPv4 and IPv6 addresses with a CIDR mask to whitelist clients from this feature. If a client was found
on this list, the feature is not enabled while processing the authentication request.

```yaml
realtime_blackhole_lists:
  ip_whitelist:
    - 127.0.0.0/8
    - ::1
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
    - fd00::/8
    - 169.254.0.0/16
    - fe80::/10
```

---

## cleartext\_networks
_Default: empty list_

Nauthilus can check, if a remote client connected using TLS. This test will reject clients that do not communicate
secured. The whitelist is for trusted local IPs and networks that are allowed to authenticate unencrypted.

:::note
Connections from "localhost" are allways trusted unencrypted!
:::

IPs with an optional CIDR mask:

```yaml
cleartext_networks:
  - 127.0.0.0/8
  - ::1
```

---

## relay\_domains

If the username equals to an email address, Nauthilus can split the login into the local and domain part. The latter is
compared against a (currently) static list. If the domain is unknown, the client will be rejected.

### relay\_domains::static
_Default: empty list_

This key holds a list of domain names.

```yaml
relay_domains:
  static:
    - example.com
    - foobar.org
```

---

## backend\_server\_monitoring

If you have turned on the feature **backend\_server\_monitoring**, Nauthilus is able to do liveness probes for backend servers.
The result is updated every 20 seconds (hard-coded for now). This information can be used in Lua scripts. The initial idea was to
chose a backend server for the Nginx-based authentication process. Other usecases are also possible, depending on your needs.

### backend\_server\_monitoring::backend\_servers

This configuration block defines servers to be monitored.

The following protocols can be used to monitor a backend server:

* smtp
* lmtp
* pop3
* imap
* sieve
* http

Servers can have a lightweight check, where only the connection is tested.

:::note
A connect timeout of 5 seconds is used. Also for reading and writing to an established connection.
:::

If the HAproxy flag is set, this is checked as well.

Having TLS settings for a backend, a handshake is done on top of the connection.

:::warn
We currently only support plain or TLS-on-connect connections. Only sieve has STARTTLS support 
:::

If deep checks are enabled, Nauthilus talks the configured protocol with each backend. Optionally, a givven test user and its password can
be used to verify a successful connection to the backend. We recommend to have one test user for each backend to prevent
technical problems with backend servers (for example index issues with Dovecot).

Example usage:

```yaml
backend_server_monitoring:

  backend_servers:
    - protocol: imap
      host: 192.168.0.2
      port: 993
      deep_check: true
      test_username: some_unique_test_user
      test_password: some_password
      tls: true
      tls_skip_verify: true
      haproxy_v2: true
```

The settings should be self-explained.

---

## brute\_force

This feature allows you to define brute force buckets. A bucket is a container on Redis that will collect failed login
attempts from remote clients. Each time a client fails the authentication process, the buckets are updated. If a bucket
is full, a client is rejected directly without validating the credentials against password database backends.

A bucket has an expiration time stamp. As long as failed logins are stored, a bucket will be refreshed. A bucket will be
removed from Redis, if no requests trigger the bucket and the TTL is expired.

You can define as many buckets as you want. A bucket has a name, a period, an indicator, if the bucket handles IPv4 or
IPv6 IPs and a maximum allowed failed requests counter.

These buckets are independent of a user login name. They will count strictly each failed login request. Features like
the **realtime\_blackhole\_lists** feature (and others) will also update the buckets directly.

If the **brute\_force** feature recognizes a misconfigured MUA, it will not block the client forever!

#### Recommendation

If you define chains of buckets, user lower TTLs for buckets that hold IPs with a smaller IP range. Use higher TTLs for
networks. See the example below.

### brute\_force::buckets
_Default: empty list_

This section lists chains of buckets. Here is the definition of a bucket:

| Field name       | Description                                                                                    |
|------------------|------------------------------------------------------------------------------------------------|
| name             | A user friendly name for the bucket                                                            |
| period           | The TTL after which an unused bucket is removed from Redis                                     |
| cidr             | The network mask of an IP address                                                              |
| ipv4             | Boolean that enables the bucket for IPv4 support                                               |
| ipv6             | Boolean that enables the bucket for IPv6 support                                               |
| failed\_requests | Threshold value unitl a client will be blocked directly without asking authentication backends |

### brute\_force::ip\_whitelist
_Default: empty list_

You can define a list of IPs and networks that are whitelisted from the **brute\_force** feature.

```yaml
brute_force:
  ip_whitelist:
    - 127.0.0.0/8
    - ::1
    - 192.168.0.0/16
```

---

## password\_nonce
_Default: ""_<br/>
_required_

This is a random string that is used to concatenate it with the password. The result will be hashed and truncated and
is used in Redis.

```mermaid
flowchart LR
  Password --> prep["Nonce\0Password"] --> SHA256 -- truncate --> bytes["Pseudo password"]
```

---

## oauth2
_Default: nil_

Nauthilus currently supports Ory Hydra to deal as authentication backend for OAuth2/OpenID Connect.

There are two sections that define the behavior of Nauthilus when it comes to the point of building the ID token.

#### Configuration flow

The first step is to create a new Ory Hydra client for your application. Here is an example:

```shell
hydra create oauth2-client \
    --endpoint https://ORY-HYDRA-ADMIN:4445 \
    --format json \
    --name "Some name for your application" \
    --secret SomeSecretPasswordForYourClient \
    --grant-type authorization_code,refresh_token \
    --response-type token,code,id_token \
    --token-endpoint-auth-method client_secret_post \
    --scope openid,offline,profile,email,dovecot \
    --redirect-uri https://your-redirect-url-that-MUST-exactly-match \
    --policy-uri https://link-to-a-policy-website/ \
    --tos-uri https://link-to-a-terms-of-service-website/ \
    --client-uri https://link-to-a-page-that-describes-the-application/
```

Some of these parameters are optional like --policy-uri, --tos-uri and --client-uri, but if they were found, Nauthilus
will render them in the page templates.

Next step is to add a section to Nauthilus, where you tell the server what data from the authentication backends are used
to build the ID- and access token. The most important field is the **subject** field.

:::warning
Make sure to pick a subject that is realy unique to identify your user inside your company. Furthermore, make sure to
stay with the subject accross all your applications defined in Nauthilus, as it will for sure have unwanted behavior if
mixing it!
:::

Besides the subject, Nauthilus can send arbitrary data to Ory Hydra upon an accepted consent request that will be sent
out to the remote client as claims. You need to define a mapping in Nauthilus that maps the LDAP attributes to claim
names.

If a user was authenticated on the login page, the server will have LDAP results that will be taken with this
mapping. Therefor it is important to tell each backend, which data needs to be retrieved. Data will be cached on Redis.
If you modify applications and require more fields/results from the underlying backends, you must clear the Redis
objects or wait for an expiration.

The LDAP backend section will tell you more about this later on this page.

After you have refreshed Nauthilus, you can configure your web application, Dovecot or whatever with the new settings.

#### About scopes and claims

Nauthilus is aware of the following built-in scopes:

* profile
* address
* email
* phone

The OpenID 1.0 core spec associates several claims to each of these scopes:

For the scope **profile**

* name
* given\_name
* family\_name
* middle\_name
* nickname
* preferred\_username
* website
* profile
* picture
* gender
* birthdate
* zoneinfo
* locale
* updated\_at

For the scope **address**

* address

Nauthilus does return addresses only as **formatted** JSON onject.

For the scope **email**

* email
* email\_verified

For the scope **phone**

* phone\_number
* phone\_number\_verfied

Each of these claims can be mapped in the oauth2 section.

Nauthilus does also support a **groups** claim, which is a list of strings, each containing a group membership value.

#### User defined scopes and claims

If the default scopes and claims are not enough for your application, you can define your own sets yourself. This has
some current limitations! By defining claims, you must tell Nauthilus a type for each value. Currently supported types
include:

| Type    | Name    | Size | Example            |
|---------|---------|:----:|--------------------|
| String  | string  |  -   | custom\_claim\_foo |
| Boolean | boolean |  -   | true / false       |
| Integer | integer |  64  | -45366473          |
| Float   | float   |  64  | 3.1415             |

Numers are signed. It may happen that the communication between Nauthilus and Ory Hydra will modify integers by using
their exponential form. This is a known issue and can not be fixed at the moment. If this happens, try using a string
instead and let the final application convert it into its representing value.

### oauth2::clients

This section defines your OAuth2 clients, containing a name, the client\_id, the subject and the claim mapping.

```yaml
oauth2:
  clients:
    - name: Testing
      client_id: THIS-IS-THE-CLIENT-ID-FROM-ORY-HYDRA
      skip_consent: false
      skip_totp: false
      subject: entryUUID
      claims:
        name: cn
        given_name: givenName
        family_name: sn
        nickname: uniqueIdentifier
        preferred_username: uniqueIdentifier
        email: mail
```

Your LDAP backend does return results for attributes. The example is a mapping for OpenLDAP.

As you can see in the example, there is no need to deliver all possible claims. Which claims are required is dependent
to your consuming application.

:::note
Make sure to list claims for which you have defined the matching scopes! If you define an email mapping whithout the
matching scope, your user seeing the consent page will not be able to accept the scope and therefor the claim will not
be available!
:::

:::note
If you configure Nauthilus to deal with a service hosted at your companies site, you may want to skip the consent 
page. Do so by setting **skip\_consent** to **true**.
:::

:::note
Some applications provide their own second factor implementation. If you want to prevent duplicated second factor
authentication, you can skip TOTP for a client, by adding **skip\_totp** with a value of **true**.
:::
> 
### oauth2::custom\_scopes

This section allows you to define custom scopes and there claim definition as described earlier on this page. It lists
objects like the following:

```yaml
oauth2:
  custom_scopes:
    - name: dovecot
      description: Some description
      description_de: Optional German description
      description_fr: Optional French description
      claims:
        - name: dovecot_user
          type: string
    
        - name: dovecot_mailbox_home
          type: string
    
        - name: dovecot_mailbox_path
          type: string
    
        - name: dovecot_acl_groups
          type: string
```

:::note
Claims are not updated after first delivery! So do not send data that may change dynamically!
:::

The **description** field will be used in the consent.html template to give the user more information about this 
scope. You can add descriptions with an underscore followed by a lower case country code, do translate the 
description into other languages. The default is English and taken from the **description** key.

Supported languages:

* en
* de
* fr

# Database backends

Nauthilus needs database backends to validate user credentials. Besides the **cache** backend, which is special, 
Nauthilus can use LDAP and Lua based backends. The current implementation is limited to use one LDAP and one Lua
backend at the same time.

If you define an LDAP and a Lua backend, both will be queried in the order you have defined in **server::backends**

:::warning
The "idea" of a backend is to check user credentials!

Do not mix password verification and policy tasks in the backends!

If you want to enforce policies, make use of Lua filters, because they never influence the brute-force-logic nor is it cached on Redis.
If you combine both aspects in the backends, you will risk of learning correct passwords as wrong!
:::

---

## Protocols

Backends carry configuration information about protocols. A protocol is something like **smtp** or **imap** but can be
anything else. As Nauthilus is used over HTTP(S), the protocol is shiiped with the HTTP-request header Auth-Protocol as
described in the [Nginx-protocol](https://nginx.org/en/docs/mail/ngx\_mail\_auth\_http\_module.html#proxy\_protocol).

If Nauthilus has a protocol definition for a protocol, rules applied to that section are taken for password validation.

You may add a **default** protocol to LDAP and Lua, which will be used for protocols without having their own section.
If there is no default keyword, the backend will fail for unknown protocols. In case of using Lua and LDAP at the same
time, there will be a chance that the other backend has information for the requested protocol.

If all backends fail due to a missing definition, a temporary error is raised and the client can not authenticate.

### Special protocols

If Nauthilus is called with the location **/api/v1/service/nginx**, the protocols **smtp** and **imap** will return
additional HTTP response headers:

**Auth-Server** and **Auth-Port** (
see [Nginx-protocol](https://nginx.org/en/docs/mail/ngx\_mail\_auth\_http\_module.html#proxy\_protocol))

If Nauthilus is used for HTTP basic authentication (Nginx backend), the protocol **http** and **internal-basic-auth** are
understood.

Both protocols will honor the **X-Forwarded-For** header to identify the real client IP address. This is important to
have the brute force feature working correctly. You do not want your reverse proxy (if any) be blocked.

Nauthilus can be protected with HTTP basic authorization, which is configured with the environment variables *
*HTTP\_USE\_BASIC\_AUTH**, **HTTP\_BASIC\_AUTH\_USERNAME** and **HTTP\_BASIC\_AUTH\_PASSWORD**. If you do not want a static
username and password, you can add the **internal-basic-auth** protocol to one of your protocol definitions and Nauthilus
will use this backend for username and passowrd checks.

The protocol **ory-hydra** is for OAuth2/OpenID Connect. Note that it is ory-hydra and not oauth2, as other servers may
appear in the future with different bindings/dependencies to Nauthilus.

---

## Macros

As LDAP queries have to deal with usernames or other information, it may be required to define several macros
inside the queries, which must be replaced by Nauthilus.

The main implementation is adopted from Dovecot, but only a subset of all possible macros is currently provided.

### Macro form

The general form is as follows:

```
%Modifiers{long variables}
```

### Modifier

Modifiers are optional. Currently, the following modifiers are known:

| Modifier | Meaning                         |
|:--------:|---------------------------------|
|    L     | Treat all characters lower case |
|    U     | Treat all characters upper case |
|    R     | Reverse a string                |
|    T     | Trim a string                   |

> Note:
>
> Do not combine **L** and **U** at the same time for one macro, as this causes unpredictable results!

### Long variables

The following macro names are known and described in the following table:

| Varaible name | Meaning                                                                                    |
|---------------|--------------------------------------------------------------------------------------------|
| user          | Full username, i.e. localpart@domain.tld                                                   |
| username      | The local part of \{user\}, if user has a domain part, else user and username are the same |
| domain        | The domain part of \{user\}. Empty string, if \{user\} did not contain a domain part       |
| service       | The service name, i.e. imap, pop3, lmtp                                                    |
| local\_ip     | Local IP address                                                                           |
| local\_port   | Local port                                                                                 |
| remote\_ip    | Remote client IP address                                                                   |
| remote\_port  | Remote client port                                                                         |
| totp\_secret  | This macros gets replaced when adding or removing a TOTP secret to a user account.         |

#### Macro example

Lower case form of a username (full email, if user string contains a '@' character).

```
%L{user}
```

---

## Cache namespaces

Each protocol block can define a Redis cache namespace. That is especially useful, if you require different results
for different protocols. By not using a namespace, a default namspace "**\_\_default\_\_**" is used.

You can apply the same namespaces to different protocols as long as the requested results carry the same information. If
you use the Dovecot IMAP/POP3 server i.e. with the submission proxy feature, Dovecot requires the same information for *
*imap** and **submission**, but your protocol sections may serve different queries/filters. But the list of returned
keys (not values) will be the same. See the full example below to get an idea.

---

## Encrypted passwords

Passwords can be stored encrypted inside a SQL database (Lua backend). Nauthilus needs to know this and can deal with the following
password schemas:

PHP versions:

* \{SSHA256\}
* \{SSHA512\}

Encoded formats:

* MD5
* SSHA256
* SSHA512
* bcrypt
* Argon2i
* Argon2id

The Lua backend can use a built-in function to compare such passwords.

---

## LDAP
_Default: nil_

### Structure

The LDAP section has two keywords **config** and **search**. The first is used for the backend configuration, the latter
for certain protocols.

### ldap::config

The config section defines the main pool settings and one or more LDAP servers. The principal of work is that Nauthilus
tries to connect to the first available server. If a server connection fails, Nauthilus tries to reconnect to an LDAP
server in the order that was defined.

The following table list keys and examples to configure LDAP:

| Key                      | Required | Description                                                           | Example               |
|--------------------------|:--------:|-----------------------------------------------------------------------|-----------------------|
| lookup\_pool\_size       |    no    | Maximum number of connection that can be opened                       | 8                     |
| lookup\_idle\_pool\_size |    no    | Minimum number of connections that must be kept open                  | 2                     |
| auth\_pool\_size         |    no    | Maximum number of connection that can be opened                       | 8                     |
| auth\_idle\_pool\_size   |    no    | Minimum number of connections that must be kept open                  | 2                     |
| server\_uri              |   yes    | A string containing a LDAP URI or a list of URIs                      | ldap://localhost:389/ |
| starttls                 |    no    | Is STARTTLS used with the LDAP connection                             | true / false          |
| tls\_skip\_verify        |    no    | If you use self signed certificates, you may to skip TLS verification | ture / false          |
| sasl\_external           |    no    | Use simple bind or SASL/EXTERNAL                                      | true / false          |
| pool\_only               |    no    | Use Lua to communicate with LDAP                                      | true / false          |

The **lookup** pool settings define a pooling to find user objects in LDAP. The **auth** pooling is used to authenticate users.

:::note
By using the **pool\_only** option, the authentication pool is not started and no authentication attempts are done against
the **ldap**-backend. You have to implement the password-verify logic as well as the list-accounts routine completely in Lua.

To verify a user password, you must retrieve the userPassword attribute and make use of the compare-function in Lua.

The **ldap** backend must still be enabled!
:::

#### If using SASL/EXTERNAL:

| Key               |           Required           | Description                           | Example                      |
|-------------------|:----------------------------:|---------------------------------------|------------------------------|
| tls\_ca\_cert     | (yes) if starttls is enabled | CA bundle or CA file in PEM format    | /path/to/company/ca-file.pem |
| tls\_client\_cert |            (yes)             | X509 client certificate in PEM format | /path/to/client/cert.pem     |
| tls\_client\_key  |            (yes)             | X509 client key in PEM format         | /path/to/client/key.pem      |

> Note:
>
> Make sure to remove a key passphrase from the key.

#### Pooling

Nauthilus will open as many connections, as the **\*\_idle\_pool\_size** value defines. All other connections are done on demand. A background thread (30
seconds delay) will observe a pool and will close unused connections.

If a new connection is required, Nauthilus first checks, if there is some free connection available and picks it up. If none
is free, a new connection is opened. If the pool is exhausted, requests are enqueued until a new connection is free
again.

#### Bind method

Nauthilus can either do a so-called simple bind, using a bind DN and a bind password, or it can do SASL/EXTERNAL usinga
X509 client certificate and key. Please check your LDAP configuration to find out, which mode is available for you.

### ldap::search

This section defines blocks that combine protocols and LDAP filters. Here is a table of keys that are known:

### Definition of a search list

| Key         | Required | Description                                                                                                                                                                                                                                    | Example |
|-------------|:--------:|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| protocol    |   yes    | A protocol name or a list of protocols in YAML format                                                                                                                                                                                          | imap    |
| cache\_name |    no    | A namespace for the Redis cache                                                                                                                                                                                                                | dovecot |
| base\_dn    |   yes    | The LDAP base DN for the queries                                                                                                                                                                                                               |         |
| filter      |   yes    | Section of LDAP filters                                                                                                                                                                                                                        | -       |
| mapping     |   yes    | Query result attribute/logic mapping                                                                                                                                                                                                           | -       |
| attribute   |   yes    | One string representing an attribute from the user object or a YAML-list of attributes from an user object. The results are used either in HTTP-response-headers with a **X-Nauthilus-Attributename** or used to assemble Open ID token claims | uid     |

#### Filter

| Key                 | Required | Description                                                                                                                                                                                                                                    | Example           |
|---------------------|:--------:|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------|
| user                |   yes    | LDAP filter to retrieve a user DN for a re-bind operation                                                                                                                                                                                      | Example see below |
| list\_accounts      |    no    | Nauthilus may return a list of known account names in an HTTP response, if the GET query string contains mode=list-accounts                                                                                                                    | Example see below |

#### Mapping

| Key                 | Required | Description                                                                                                                                                                                                                                    | Example          |
|---------------------|:--------:|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------|
| account\_field      |   yes    | This result of this attribute is returned as the user account                                                                                                                                                                                  | uid              |
| totp\_secret\_field |    no    | Tell Nauthilus which field is used for the TOTP secret key                                                                                                                                                                                     | rns2FATOTPSecret |                                                                                                            

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
        
      filter:
          user: |
            (&
              (memberOf=cn=Dovecot,ou=Mail,ou=groups,ou=it,dc=example,dc=com)
              (objectClass=rnsMSDovecotAccount)
              (rnsMSEnableDovecot=TRUE)
              (|
                (uniqueIdentifier=%L{user})
                (rnsMSRecipientAddress=%L{user})
              )
            )
          list_accounts: |
            (&
              (memberOf=cn=Dovecot,ou=Mail,ou=groups,ou=it,dc=example,dc=com)
              (objectClass=rnsMSDovecotAccount)
              (rnsMSEnableDovecot=TRUE)
              (!
                (rnsMSDovecotMaster=TRUE)
              )
            )
            
      mapping:
        account_field: rnsMSDovecotUser
        
      attribute:
        - uid
        - rnsMSMailboxHome
        - rnsMSMailPath
        - rnsMSACLGroups
        - rnsMSDovecotUser
```

If you need a schema for the TOTP stuff, you could use the following draft:

```schema
objectidentifier RNSRoot     1.3.6.1.4.1.31612
objectidentifier RNSLDAP     RNSRoot:1
objectidentifier RNS2FA      RNSLDAP:4
objectidentifier RNSLDAPat   RNS2FA:1
objectidentifier RNSLDAPoc   RNS2FA:2

attributetype ( RNSLDAPat:1
  NAME 'rns2FATOTPSecret'
  DESC 'TOTP secret'
  EQUALITY caseExactMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE )

attributetype ( RNSLDAPat:2
  NAME 'rns2FATOTPRecoveryCode'
  DESC 'TOTP backup recovery code'
  EQUALITY caseExactMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 )

objectclass ( RNSLDAPoc:1
  NAME 'rns2FATOTP'
  DESC 'Time-based one-time passwords with backup recovery codes'
  SUP top AUXILIARY
  MAY ( rns2FATOTPSecret $ rns2FATOTPRecoveryCode ) )
```

It will be anhanced over time to support webauthn as well.

---

## Lua backend
_Default: nil_

The Lua backend is described in detail [here](/docs/configuration/lua-support.md).

### lua::features

Features are scripts that are run before the actual authentication process is taken. A Lua feature has a name and a script 
path.

Scripts are run in order and the first script that triggers, aborts the execution for all remaining scripts.

### Definition of a "feature" list

| Key          | Required | Description                         | Example |
|--------------|:--------:|-------------------------------------|---------|
| name         |   yes    | A unique name for the Lua feature   | demo    |
| script\_path |   yes    | Full path to the Lua feature script | -       |

### lua::filters

Filters run after all backends have completed their work. A filter can override the existing result of an authentication request.
The idea is to have some post checks (maybe remote REST calls, database queries...) that will lead to a different final result.

It is important that script honor the backend result, if they do not wish to change it! In that case they **must** pass
the same result back to Nauthilus.

### Definition of a "filter" list

| Key          | Required | Description                         | Example       |
|--------------|:--------:|-------------------------------------|---------------|
| name         |   yes    | A unique name for the Lua feature   | geoip-policyd |
| script\_path |   yes    | Full path to the Lua feature script | -             |

### lua::actions

Actions have a type and script path element for each Lua script. An incoming request is waiting for all actions to be 
completed except of **post** actions. The latter run afterward, when the client already may have been disconnected.

### Definition of an "actions" list

| Key          | Required | Description                                     | Example     |
|--------------|:--------:|-------------------------------------------------|-------------|
| type         |   yes    | The type of action. Can be repeated many times. | brute_force |
| name         |   yes    | A unique name for the Lua action                | logging     |
| script\_path |   yes    | Full path to the Lua action script              | -           |

The following **type**s are known:

| Type            | Description                                                                    |
|-----------------|--------------------------------------------------------------------------------|
| brute\_force    | Run after a brute force attack has been detected                               |
| rbl             | Runs after a requesting client IP was found on a real time blackhole list.     |
| tls\_encryption | Runs, if a client connection was not encrypted.                                |
| relay\_domains  | Runs, if the login name equals an e-mail address and the domain is not served. |
| lua             | Runs, if any of the Lua features triggered.                                    |
| post            | Run always in background after the request already finished.                   |

### lua::config

| Key                    | Required | Description                                  | Example                                       |
|------------------------|:--------:|----------------------------------------------|-----------------------------------------------|
| backend\_script\_path  |   yes    | Full path to the Lua backend script          | ./server/lua-plugins.d/backend/backend.lua    |
| callback\_script\_path |    no    | Full path to the Lua callback script         | ./server/lua-plugins.d/callback/callback.lua  |
| package_path           |    no    | Set a Lua module path for custom Lua modules | /usr/local/etc/nauthilus/lualib/?.lua         |

:::note
The **callback** script can be used to provide additional information. If you use Dovecot, you might use this script to
track a users' session and cleanup things on Redis. Look at the callback.lua script that is bundled with Nauthilus.
:::

### lua::search

This section defines blocks that combine protocols and Redis cache namespaces. Here is a table of keys that are known:

### Definition of a "search" list

| Key         | Required | Description                                           | Example |
|-------------|:--------:|-------------------------------------------------------|---------|
| protocol    |   yes    | A protocol name or a list of protocols in YAML format | imap    |
| cache\_name |    no    | A namespace for the Redis cache                       | dovecot |

```yaml
lua:
  features:
    - name: demo
      script_path: ./server/lua-plugins.d/features/demo.lua
    - name: comm
      script_path: ./server/lua-plugins.d/features/comm.lua

  filters:
    - name: geoip-policyd
      script_path: /some/path/to/lua/script.lua
      
  actions:
    - type: brute_force
      name: brute_force
      script_path: ./server/lua-plugins.d/actions/bruteforce.lua
    - type: post
      name: demoe
      script_path: ./server/lua-plugins.d/actions/demo.lua
    - type: post
      name: haveibeenpwnd
      script_path: ./server/lua-plugins.d/actions/haveibeenpwnd.lua
    - type: post
      name: telegram
      script_path: ./server/lua-plugins.d/actions/telegram.lua

  config:
    script_path: ./server/lua-plugins.d/backend/backend.lua

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

---

## Full example (standalone)

```yaml
server:
  address: "[::]:9443"
  http3: true
  haproxy_v2: false

  tls:
    enabled: true
    cert: /usr/local/etc/nauthilus/localhost.localdomain.pem
    key: /usr/local/etc/nauthilus/localhost.localdomain.key.pem
    http_client_skip_verify: true

  basic_auth:
    enabled: true
    username: nauthilus
    password: nauthilus

  instance_name: nauthilus_demo

  log:
    json: false
    level: debug
    debug_modules:
      - auth
      - lua
      - feature

  backends:
    - cache
    - lua
    - ldap

  features:
    - lua
    - relay_domains
    - backend_server_monitoring

  brute_force_protocols:
    - imap
    - imaps
    - submission
    - smtp
    - smtps
    - ory-hydra
    - http

  ory_hydra_admin_url: https://hydra.example.com:4445

  dns:
    resolver: 192.168.1.1
    timeout: 3
    resolve_client_ip: false

  insights:
    enable_pprof: true
    enable_block_profile: true

  redis:
    database_number: 2
    prefix: nt_
    pool_size: 10

    positive_cache_ttl: 3600s
    negative_cache_ttl: 7200s

    master:
      address: 127.0.0.1:6379

  master_user:
    enabled: true
    delimiter: "*"
  
  frontend:
    enabled: true
    csrf_secret: 32-byte-long-random-secret
    cookie_store_auth_key: 32-byte-long-random-secret
    cookie_store_encryption_key: 16-24-or-32-byte-long-random-secret

realtime_blackhole_lists:

  threshold: 10

  lists:
    - name: SpamRats AuthBL
      rbl: auth.spamrats.com
      ipv4: true
      ipv6: true
      return_code: 127.0.0.43
      weight: 10

    - name: AbusiX AuthBL
      rbl: YOUR-API-KEY.authbl.mail.abusix.zone
      ipv4: true
      ipv6: true
      return_code: 127.0.0.4
      weight: 10

  ip_whitelist:
    - 127.0.0.0/8
    - ::1
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
    - fd00::/8
    - 169.254.0.0/16
    - fe80::/10

cleartext_networks:
  - 127.0.0.0/8
  - ::1
  - 192.168.0.200
  - 172.16.0.0/12

relay_domains:
  static:
    - domain1.tld
    - domain2.tld
    - domain3.tld

brute_force:
  ip_whitelist:
    - 127.0.0.0/8
    - ::1
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
    - fd00::/8
    - 169.254.0.0/16
    - fe80::/10

  user_account:
    - name: ua_1d_ipv4
      period: 86400
      ipv4: true
      failed_requests: 10

    - name: ua_1d_ipv6
      period: 86400
      ipv6: true
      failed_requests: 10

  buckets:
    - name: b_1min_ipv4_32
      period: 60
      cidr: 32
      ipv4: true
      failed_requests: 10

    - name: b_1min_ipv6_128
      period: 60
      cidr: 128
      ipv6: true
      failed_requests: 10

    - name: b_1h_ipv4_24
      period: 3600
      cidr: 24
      ipv4: true
      failed_requests: 15

    - name: b_1h_ipv6_64
      period: 3600
      cidr: 64
      ipv6: true
      failed_requests: 15

    - name: b_1d_ipv4_24
      period: 86400
      cidr: 24
      ipv4: true
      failed_requests: 25

    - name: b_1d_ipv6_64
      period: 86400
      cidr: 64
      ipv6: true
      failed_requests: 25

    - name: b_1w_ipv4_24
      period: 604800
      cidr: 24
      ipv4: true
      failed_requests: 40

    - name: b_1w_ipv6_64
      period: 604800
      cidr: 64
      ipv6: true
      failed_requests: 40

oauth2:
  custom_scopes:
    - name: dovecot
      description: Some description that will be seen on the consent page
      claims:
        - name: dovecot_user
          type: string

        - name: dovecot_mailbox_home
          type: string

        - name: dovecot_mailbox_path
          type: string

        - name: dovecot_acl_groups
          type: string

  clients:
    - name: Testing
      client_id: SOME-CLIENT-ID
      subject: entryUUID
      claims:
        name: cn
        given_name: givenName
        family_name: sn
        nickname: uniqueIdentifier
        preferred_username: uniqueIdentifier
        email: mail
        groups: organizationalStatus
        dovecot_user: rnsMSDovecotUser
        dovecot_mailbox_home: rnsMSMailboxHome
        dovecot_mailbox_path: rnsMSMailPath
        dovecot_acl_groups: rnsMSACLGroups


# OpenLDAP
ldap:
  config:
    pool_size: 8
    idle_pool_size: 2

    server_uri: ldap://some.server:389/
    starttls: true
    tls_skip_verify: true
    sasl_external: true
    tls_ca_cert: /path/to/cacert.pem
    tls_client_cert: /path/to/client/cert.pem
    tls_client_key: /path/to/client/key.pem

  search:
    - protocol: http
      cache_name: http
      base_dn: ou=people,ou=it,dc=example,dc=com
      filter:
        user: |
          (|
            (uniqueIdentifier=%L{user})
            (rnsMSRecipientAddress=%L{user})
          )
      mapping:
        account_field: rnsMSDovecotUser
        attribute: rnsMSDovecotUser

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
      filter:
        user: |
            (&
              (objectClass=rnsMSDovecotAccount)
              (|
                (uniqueIdentifier=%L{user})
                (rnsMSRecipientAddress=%L{user})
              )
            )
        list_accounts: |
            (&
              (objectClass=rnsMSDovecotAccount)
              (rnsMSEnableDovecot=TRUE)
              (!
                (rnsMSDovecotMaster=TRUE)
              )
            )
      mapping:
        account_field: rnsMSDovecotUser
      attribute:
        - uid
        - rnsMSQuota
        - rnsMSOverQuota
        - rnsMSMailboxHome
        - rnsMSMailPath
        - rnsMSDovecotFTS
        - rnsMSDovecotFTSSolrUrl
        - rnsMSACLGroups
        - rnsMSDovecotUser

    - protocol:
        - smtp
        - submission
      cache_name: submission
      base_dn: ou=people,ou=it,dc=example,dc=com
      filter:
        user: |
            (&
              (objectClass=rnsMSPostfixAccount)
              (|
                (uniqueIdentifier=%L{user})
                (rnsMSRecipientAddress=%L{user})
              )
            )
      mapping:
        account_field: rnsMSDovecotUser
      attribute:
        - uid
        - rnsMSQuota
        - rnsMSOverQuota
        - rnsMSMailboxHome
        - rnsMSMailPath
        - rnsMSDovecotFTS
        - rnsMSDovecotFTSSolrUrl
        - rnsMSACLGroups
        - rnsMSDovecotUser

    - protocol:
        - ory-hydra
      cache_name: oauth
      base_dn: ou=people,ou=it,dc=example,dc=com
      filter:
        user: |
            (&
              (objectClass=inetOrgPerson)
              (|
                (entryUUID=%{user})
                (uid=%{user})
                (uniqueIdentifier=%L{user})
                (rnsMSRecipientAddress=%L{user})
              )
            )
      mapping:
        account_field: uid
        totp_secret_field: rns2FATOTPSecret
      attribute:
        - entryUUID
        - uid
        - cn;x-hidden
        - mail;x-hidden
        - givenName;x-hidden
        - sn;x-hidden
        - uniqueIdentifier
        - rnsMSDovecotUser
        - rnsMSMailboxHome
        - rnsMSMailPath
        - rnsMSACLGroups
        - rnsMSEnableDovecot
        - organizationalStatus
        - labeledURI;x-hidden
```
