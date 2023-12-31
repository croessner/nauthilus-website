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
  * [realtime\_blackhole\_lists](#realtime_blackhole_lists)
    * [Meaning](#meaning)
    * [Level 1: lists:](#level-1-lists)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list)
    * [Level 2: threshold](#level-2-threshold)
    * [Level 2: ip\_whitelist](#level-2-ip_whitelist)
  * [cleartext\_networks](#cleartext_networks)
    * [Meaning](#meaning-1)
    * [Level 1: IPs with an optional CIDR mask](#level-1-ips-with-an-optional-cidr-mask)
  * [relay\_domains](#relay_domains)
    * [Meaning](#meaning-2)
    * [Level 1: static](#level-1-static)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list-1)
  * [brute\_force](#brute_force)
    * [Meaning](#meaning-3)
      * [Recommendation](#recommendation)
    * [Level 1: buckets](#level-1-buckets)
    * [Level 1: ip\_whitelist](#level-1-ip_whitelist)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list-2)
  * [csrf\_secret](#csrf_secret)
  * [cookie\_store\_auth\_key and cookie\_store\_encryption\_key](#cookie_store_auth_key-and-cookie_store_encryption_key)
  * [password\_nonce](#password_nonce)
  * [oauth2](#oauth2)
    * [Meaning](#meaning-4)
      * [Configuration flow](#configuration-flow)
      * [About scopes and claims](#about-scopes-and-claims)
      * [User defined scopes and claims](#user-defined-scopes-and-claims)
    * [Level 1: clients](#level-1-clients)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list-3)
    * [Level 1: custom\_scopes](#level-1-custom_scopes)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list-4)
* [Database backends](#database-backends)
  * [Protocols](#protocols)
    * [Special protocols](#special-protocols)
  * [Macros](#macros)
    * [Macro form](#macro-form)
    * [Modifier](#modifier)
    * [Long variables](#long-variables)
      * [Macro example](#macro-example)
  * [Cache namespaces](#cache-namespaces)
  * [MySQL/MariaDB nad Postgres](#mysqlmariadb-nad-postgres)
    * [Structure](#structure-1)
    * [Encrypted passwords](#encrypted-passwords)
    * [Level 1: config - MySQL/MariaDB](#level-1-config---mysqlmariadb)
    * [Level 1: config - Postgres](#level-1-config---postgres)
    * [Level 1: search](#level-1-search)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list-5)
      * [Query](#query)
      * [Mapping](#mapping)
  * [LDAP](#ldap)
    * [Structure](#structure-2)
    * [Level 1: config](#level-1-config)
      * [If using SASL/EXTERNAL:](#if-using-saslexternal)
      * [Pooling](#pooling)
      * [Bind method](#bind-method)
    * [Level 1: search](#level-1-search-1)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list-6)
      * [Filter](#filter)
      * [Mapping](#mapping-1)
  * [Lua backend](#lua-backend)
    * [Level 1: features](#level-1-features)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list-7)
    * [Level 1: filters](#level-1-filters)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list-8)
    * [Level 1: actions](#level-1-actions)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list-9)
    * [Level 1: config](#level-1-config-1)
    * [Level 1: search](#level-1-search-2)
    * [Level 2: Definition of a list](#level-2-definition-of-a-list-10)
  * [Full example (standalone)](#full-example-standalone)
<!-- TOC -->

## Structure

The configuration file contains several main sections, each responsible for a single category of runtime behavior. A
full example is shown at the end of this document.

### Features

* realtime\_blackhole\_lists
* cleartext\_networks
* relay\_domains
* brute\_force

### General configuration settings

* csrf\_secret
* cookie\_store\_auth\_key
* cookie\_store\_encryption\_key
* oauth2
* sql
* ldap

Each section has individual subsections. See details below. If you do not require some sections, please do not include
it into the configuration file.

## Reloading

You can send a HUP-signal to Nauthilus, which will stop SQL and LDAP connections, reload the configuration file and
restart the database connections. The main web server process it kept alive.

## realtime\_blackhole\_lists

### Meaning

This is the *rbl* feature. It checks a remote client IP address against a list of defined RBL lists. The lists are run
simultaneously. They may contain a weight parameter which is added to a total value. If that value raises a threshold,
the features directly returns with a client reject.

### Level 1: lists:

This section defines one or more RBL lists.

### Level 2: Definition of a list

A RBL list requires the following fields:

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
### Level 2: threshold

The threshold parameter defines an absolute value which tells Nauthilus, when to abort further list lookups. If the sum
of all weights is above the threshold value, the feature triggers an immediate client reject.

### Level 2: ip\_whitelist

You can define IPv4 and IPv6 addresses with a CIDR mask to white list clients from this feature. If a client was found
on this list, the feature is not enabled while processing the authentication request.

## cleartext\_networks

### Meaning

Nauthilus can check, if a remote client connected using TLS. This test will reject clients that do not communicate
secured. The whitelist is for trusted local IPs and networks that are allowed to authenticate unencrypted.

:::note
Connections from "localhost" are allways trusted unencrypted!
:::
> 
### Level 1: IPs with an optional CIDR mask

```yaml
- 127.0.0.0/8
- ::1
```

## relay\_domains

### Meaning

If the username equals to an email address, Nauthilus can split the login into the lcal and domain part. The latter is
compared against a (currently) static list. If the domain is unknown, the client will rejected.

### Level 1: static

This key holds a list of domain names.

### Level 2: Definition of a list

```yaml
- example.com
- foobar.org
```

## brute\_force

### Meaning

This feature allows you to define brute force buckets. A bucket is a container on Redis that will collect failed login
attempts from remote clients. Each time a client fails the authentication process, the buckets are updated. If a bucket
is full, a client is rejected directly without validating the credentials against password database backends.

A bucket has an expiration time stamp. As long as failed logins are stored, a bucket will be refreshed. A bucket will be
removed from Redis, if no requests trigger the bucket and the TTL is expired.

You can define as many buckets as you want. A bucket has a name, a period, an indicator, if the bucket handles IPv4 or
IPv6 IPs and a maximum allowed failed requests counter.

These buckets are independent from a user login name. They will count strictly each failed login request. Features like
the **realtime\_blackhole\_lists** feature (and others) will also update the buckets directly.

If the **brute\_force** feature recognizes a misconfigured MUA, it will not block the client forever!

#### Recommendation

If you define chains of buckets, user lower TTLs for buckets that hold IPs with a smaller IP range. Use higher TTLs for
networks. See the example below.

### Level 1: buckets

This section lists chains of buckets. Here is the definition of a bucket:

| Field name       | Description                                                                                    |
|------------------|------------------------------------------------------------------------------------------------|
| name             | A user friendly name for the bucket                                                            |
| period           | The TTL after which an unused bucket is removed from Redis                                     |
| cidr             | The network mask of an IP address                                                              |
| ipv4             | Boolean that enables the bucket for IPv4 support                                               |
| ipv6             | Boolean that enables the bucket for IPv6 support                                               |
| failed\_requests | Threshold value unitl a client will be blocked directly without asking authentication backends |

### Level 1: ip\_whitelist

You can define a list of IPs and networks that are whitelisted from the **brute\_force** feature.

### Level 2: Definition of a list

```yaml
- 127.0.0.0/8
- ::1
- 192.168.0.0/16
```

## csrf\_secret

This key is required whenever CSRF (cross-site-request-forgery) attacks must be prevented. This is currently used, if
Nauthilus is configured to communicate with Ory Hydra. The login, consent and logout pages are protected with a CSRF
token. This value defines the secret used for that token.

This value **MUST** be 32 bytes long.

## cookie\_store\_auth\_key and cookie\_store\_encryption\_key

These keys are used to encrypt and decrypt session cookies.

Both values **MUST** be 32 bytes long.

## password\_nonce

This is a random string that is used to concatenate it with the password. The result will be hashed and truncated and
is used in Redis.

```mermaid
flowchart LR
  Password --> prep["Nonce\0Password"] --> SHA256 -- truncate --> bytes["Pseudo password"]
```

## oauth2

### Meaning

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
Make sure to pick a subject that is realy unique to identify your user inside your company. Furthermore make sure to
stay with the subject accross all your applications defined in Nauthilus, as it will for sure have unwanted behavior if
mixing it!
:::

Besides the subject, Nauthilus can send arbitrary data to Ory Hydra upon an accepted consent request that will be sent
out to the remote client as claims. You need to define a mapping in Nauthilus that maps the SQL/LDAP attributes to claim
names.

If an user was authenticated on the login page, the server will have SQL or LDAP results that will be taken with this
mapping. Therefor it is important to tell each backend, which data needs to be retrieved. Data will be cached on Redis.
If you modify applications and require more fields/results from the underlying backends, you must clear the Redis
objects or wait for an expiration.

The SQL and LDAP backend sections will tell you more about this later on this page.

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

### Level 1: clients

This section defines your OAuth2 clients, containing a name, the client\_id, the subject and the claim mapping.

### Level 2: Definition of a list

```yaml
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

Your SQL and/or LDAP backend does return results for attributes. The example is a mapping for OpenLDAP. If you have a
SQL select statement, the mapped attributes are the field names.

As you can see in the example, there is no need to deliver all possible claims. Which claims are required is dependent
to your consuming application.

> Note:
>
> Make sure to list claims for which you have defined the matching scopes! If you define an email mapping whithout the
> matching scope, your user seeing the consent page will not be able to accept the scope and therefor the claim will not
> be available!

The **skip\_consent** key was added

> Note:
> 
> If you configure Nauthilus to deal with a service hosted at your companies site, you may want to skip the consent 
> page. Do so by setting **skip\_consent** to **true**.

The **skip\_totp** key was added.

> Note:
> 
> Some applications provide their own second factor implementation. If you want to prevent duplicated second factor
> authentication, you can skip TOTP for a client, by adding **skip\_totp** with a value of **true**.

### Level 1: custom\_scopes

This section allows you define custom scopes and there claim definition as described earlier on this page. It lists
objects like the following:

### Level 2: Definition of a list

```yaml
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

> Note
>
> Claims are not updated after first delivery! So do not send data that may change dynamically!

The **description** field will be used in the consent.html template to give the user more information about this 
scope. You can add descriptions with an underscore followed by a lower case country code, do translate the 
description into other languages. The default is English and taken from the **description** key.

Supported languages:

* en
* de
* fr

# Database backends

Nauthilus needs database backends to validate user credentials. Besides the **cache** and **test** backends, which are
special, Nauthilus can use SQL and LDAP based backends. The current implementation is limited to use one SQL and one LDAP
backend at the same time. Furthermore you can not have MySQL and Postgres at the same time.

If you define a SQL and LDAP backend, both will be queried in the order you have defined in the environment variable *
*AUTHSERV\_PASSDB\_BACKENDS**, i.e. "cache mysql ldap".

## Protocols

Backends carry configuration information about protocols. A protocol is something like **smtp** or **imap** but can be
anything else. As Nauthilus is used over HTTP(S), the protocol is shiiped with the HTTP-request header Auth-Protocol as
described in the [Nginx-protocol](https://nginx.org/en/docs/mail/ngx\_mail\_auth\_http\_module.html#proxy\_protocol).

If Nauthilus has a protocol definition for a protocol, rules applied to that section are taken for password validation.

You may add a **default** protocol to SQL and LDAP, which will be used for protocols without having their own section.
If there is no default keyword, the backend will fail for unknown protocols. In case of using SQL and LDAP at the same
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

## Macros

As SQL and LDAP queries have to deal with user names or other information, it may be required to define several macros
inside the queries, which must be replaces by Nauthilus.

The main implementation is adopted from Dovecot, but only a subset of all possible macros is currently provided.

### Macro form

The general form is as follows:

```
%Modifiers{long variables}
```

### Modifier

Modifiers are optional. Currently the following modifiers are known:

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

Lower case form of a user name (full email, if user string contains a '@' character).

```
%L{user}
```

## Cache namespaces

Each protocol block can define a Redis cache namespace. That is especially useful, if you require different results
for different protocols. By not using a namespace, a default namspace "**\_\_default\_\_**" is used.

You can apply the same namespaces to different protocols as long as the requested results carry the same information. If
you use the Dovecot IMAP/POP3 server i.e. with the submission proxy feature, Dovecot requires the same information for *
*imap** and **submission**, but your protocol sections may serve different queries/filters. But the list of returned
keys (not values) will be the same. See the full example below to get an idea.

## MySQL/MariaDB nad Postgres

The configuration for MySQL/MariaDB and Postgres slightly differ due to the underlying Go-libraries. Both variants will
be described:

### Structure

The SQL section has two keywords **config** and **search**. The first is used for the backend configuration, the latter
for certain protocols.

### Encrypted passwords

Passwords can be stored encrypted inside a SQL backend. Nauthilus needs to know this and can deal with the following
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

### Level 1: config - MySQL/MariaDB

| Key             | Description                                                      | Example                                                   |
|-----------------|------------------------------------------------------------------|-----------------------------------------------------------|
| dsn             | Data source name                                                 | mysql://nauthilus:nauthilus@tcp(127.0.0.1:3306)/nauthilus |
| password\_crypt | Boolean that tells Nauthilus that passwords are stored encrypted | true / false                                              |

For the DSN syntax and their supported options, please have a look at the Go
library. [See here for MySQL](https://github.com/go-sql-driver/mysql)

### Level 1: config - Postgres

| Key             | Description                                                      | Example                                                                 |
|-----------------|------------------------------------------------------------------|-------------------------------------------------------------------------|
| dsn             | Data source name                                                 | postgres://nauthilus:nauthilus@127.0.0.1:5432/nauthilus?sslmode=disable |
| password\_crypt | Boolean that tells Nauthilus that passwords are stored encrypted | true / false                                                            |

For the DSN syntax and their supported options please have a look at the Go
library. [see here for Postgres](https://github.com/lib/pq)

### Level 1: search

This section defines blocks that combine protocols, SQL queries and some field mappings. Here is a table of keys that
are known:

### Level 2: Definition of a list

| Key         | Required | Description                                           | Example |
|-------------|:--------:|-------------------------------------------------------|---------|
| protocol    |   yes    | A protocol name or a list of protocols in YAML format | imap    |
| cache\_name |    no    | A namespace for the Redis cache                       | dovecot |
| query       |   yes    | Section of queries                                    | -       |
| mapping     |   yes    | Query result attribute/logic mapping                  | -       |

#### Query

| Key            | Required | Description                                                                                                                                                                                                                                                                                                                                    | Example                                                                                                         |
|----------------|:--------:|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| user           |   yes    | A SQL query that returns an user account, password and arbitray other fields which are taken as additional information. If Nauthilus is used directly over HTTP, the results are returned as HTTP-response headers prefixed with **X-Nauthilus-Fieldname**. If used with Ory Hydra, results are taken for the claims. See claim-mapping above. | SELECT Account, Password, FieldA, FieldB FROM nauthilus    WHERE username="%L\{user\}" OR account="%L\{user\}"; |
| list\_accounts |    no    | Nauthilus may return a list of known account names in an HTTP response, if the GET query string contains mode=list-accounts                                                                                                                                                                                                                    | SELECT account FROM nauthilus;                                                                                  |

#### Mapping

| Key                 | Required | Description                                                                                                                                                             | Example                                                                            |
|---------------------|:--------:|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| account\_field      |   yes    | Tell Nauthilus which field name is used for the account name                                                                                                            | Account                                                                            |
| password\_field     |   yes    | Tell Nauthilus which field is used for the password                                                                                                                     | Password                                                                           |
| totp\_secret\_field |    no    | Tell Nauthilus which field is used for the TOTP secret key                                                                                                              | TOTP\_Secret                                                                       |                                                                                                            
| totp\_secret        |    no    | This is an SQL update command which is used to set or replace a TOTP secret for a user. It must contain at least the following macros: %\{user\} and %\{totp\_secret\}. | UPDATE nauthilus SET TOTP\_Secret="%\{totp\_secret\}" WHERE username="%L\{user\}"; |

> Note:
>
> SQL queries for MySQL/MariaDB and Postgres are different! Make sure to write the correct syntax!

```yaml
sql:
  config:
    dsn: mysql://nauthilus:nauthilus@tcp(127.0.0.1:3306)/nauthilus
    password_crypt: true

  search:
    - protocol:
        - imap
        - pop3
        - lmtp
        - sieve
        - doveadm
        - indexer-worker
        - quota-status
        - default
        - 
      cache_name: dovecot
      
      query:
          user: |
            SELECT account, password 
              FROM nauthilus 
              WHERE username="%L\{user\}" OR account="%L\{user\}";
          list_accounts: SELECT account FROM nauthilus;
          
      mapping:
          account_field: account
          password_field: password
```

## LDAP

### Structure

The LDAP section has two keywords **config** and **search**. The first is used for the backend configuration, the latter
for certain protocols.

### Level 1: config

The config section defines the main pool settings and one or more LDAP servers. The principal of work is that Nauthilus
tries to connect to the first available server. If a server connection fails, Nauthilus tries to reconnect to a LDAP
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

The **lookup** pool settings define a pooling to find user objects in LDAP. The **auth** pooling is used to authenticate users.

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

By starting Nauthilus, no connection is opened until the first request is processed. Nauthilus will open as many
connections, as the **\*\_idle\_pool\_size** value defines. All other connections are done on demand. A background thread (30
seconds delay) will observe a pool and will close unused connections.

If a new connection is required, Nauthilus first checks, if there is some free connection available and picks it up. If none
is free, a new connection is opened. If the pool is exhausted, requests are enqueued until a new connection is free
again.

#### Bind method

Nauthilus can either do a so-called simple bind, using a bind DN and a bind password, or it can do SASL/EXTERNAL usinga
X509 client certificate and key. Please check your LDAP configuration to find out, which mode is available for you.

### Level 1: search

This section defines blocks that combine protocols and LDAP filters. Here is a table of keys that are known:

### Level 2: Definition of a list

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

## Lua backend

The Lua backend is described in detail [here](/docs/configuration/lua-support).

### Level 1: features

Features are scripts that are run before the actual authentication process is taken. A Lua feature has a name and a script 
path.

Scripts are run in order and the first script that triggers, aborts the execution for all remaining scripts.

### Level 2: Definition of a list

| Key          | Required | Description                         | Example |
|--------------|:--------:|-------------------------------------|---------|
| name         |   yes    | A unique name for the Lua feature   | demo    |
| script\_path |   yes    | Full path to the Lua feature script | -       |

### Level 1: filters

Filters run after all backends have completed their work. A filter can override the existing result of an authentication request.
The idea is to have some post checks (maybe remote REST calls, database queries...) that will lead to a different final result.

It is important that script honor the backend result, if they do not wish to change it! In that case they **must** pass
the same result back to Nauthilus.

### Level 2: Definition of a list

| Key          | Required | Description                         | Example       |
|--------------|:--------:|-------------------------------------|---------------|
| name         |   yes    | A unique name for the Lua feature   | geoip-policyd |
| script\_path |   yes    | Full path to the Lua feature script | -             |

### Level 1: actions

Actions have a type and script path element for each Lua script. An incoming request is waiting for all actions to be 
completed with the exception of **post** actions. The latter run afterward, when the client already may have been disconnected.

### Level 2: Definition of a list

| Key          | Required | Description                                     | Example     |
|--------------|:--------:|-------------------------------------------------|-------------|
| type         |   yes    | The type of action. Can be repeated many times. | brute_force |
| script\_path |   yes    | Full path to the Lua action script              | -           |

The following **type**s are known:

* brute\_force - Run after a brute force attack has been detected
* rbl - Runs after a requesting client IP was found on a real time blackhole list.
* tls\_encryption - Runs, if a client connection was not encrypted.
* relay\_domains - Runs, if the login name equals an e-mail address and the domain is not served.
* lua - Runs, if any of the Lua features triggered.
* post - Run always in background after the request already finished.

### Level 1: config

| Key         | Required | Description                         | Example                                    |
|-------------|:--------:|-------------------------------------|--------------------------------------------|
| script\path |   yes    | Full path to the Lua backend script | ./server/lua-plugins.d/backend/backend.lua |


### Level 1: search

This section defines blocks that combine protocols and Redis cache namespaces. Here is a table of keys that are known:

### Level 2: Definition of a list

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
      script_path: ./server/lua-plugins.d/actions/bruteforce.lua
    - type: post
      script_path: ./server/lua-plugins.d/actions/demo.lua
    - type: post
      script_path: ./server/lua-plugins.d/actions/haveibeenpwnd.lua
    - type: post
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

## Full example (standalone)

```yaml
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

csrf_secret: 32-byte-long-random-secret
cookie_store_auth_key: 32-byte-long-random-secret
cookie_store_encryption_key: 16-24-or-32-byte-long-random-secret

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

# MySQL/MariaDB example
sql:
  config:
    dsn: mysql://nauthilus:nauthilus@tcp(127.0.0.1:3306)/nauthilus
    password_crypt: true

  search:
    - protocol:
        - imap
        - pop3
        - lmtp
        - sieve
        - doveadm
        - indexer-worker
        - quota-status
        - default
      cache_name: dovecot
      query:
        user: |
            SELECT account, password 
              FROM nauthilus 
              WHERE username="%L{user}" OR account="%L{user}";
        list_accounts: SELECT account FROM nauthilus;
      mapping:
        account_field: account
        password_field: password

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
            (&
              (memberOf=cn=BasicAuth,ou=Nauthilus,ou=groups,ou=it,dc=example,dc=com)
              (|
                (uniqueIdentifier=%L{user})
                (rnsMSRecipientAddress=%L{user})
              )
            )
      mapping:
        account_field: rnsMSDovecotUser
        attribute: rnsMSDovecotUser

    - protocol: internal-basic-auth
      cache_name: internal
      base_dn: ou=people,ou=it,dc=example,dc=com
      filter:
        user: |
            (&
              (memberOf=cn=InternalBasicAuth,ou=Nauthilus,ou=groups,ou=it,dc=example,dc=com)
              (cn=%L{user})
            )
      mapping:
        account_field: cn
        attribute: cn

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
              (memberOf=cn=Postfix,ou=Mail,ou=groups,ou=it,dc=example,dc=com)
              (objectClass=rnsMSPostfixAccount)
              (rnsMSEnablePostfix=TRUE)
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
              (memberOf=cn=Users,ou=Oauth,ou=groups,ou=it,dc=example,dc=com)
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
