---
title: LDAP Backend
description: LDAP backend configuration in Nauthilus
keywords: [Configuration, LDAP, Backend]
sidebar_position: 6
---

# LDAP Backend

The LDAP backend allows Nauthilus to authenticate users against LDAP directories such as OpenLDAP, Active Directory, or other LDAP-compatible servers.

## Structure

The LDAP section has two keywords **config** and **search**. The first is used for the backend configuration, the latter
for certain protocols.

## Configuration Options

### ldap::config

The config section defines the main pool settings and one or more LDAP servers. The principal of work is that Nauthilus
tries to connect to the first available server. If a server connection fails, Nauthilus tries to reconnect to an LDAP
server in the order that was defined.

The following table lists keys and examples to configure LDAP:

| Key                      | Required | Description                                                                                                                                                     | Example                               |
|--------------------------|:--------:|-----------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------|
| number\_of\_workers      |    no    | Number of LDAP workers to use. If not specified, defaults to 10.                                                                                                | 10                                    |
| lookup\_pool\_size       |    no    | Maximum number of connection that can be opened                                                                                                                 | 8                                     |
| lookup\_idle\_pool\_size |    no    | Minimum number of connections that must be kept open                                                                                                            | 2                                     |
| auth\_pool\_size         |    no    | Maximum number of connection that can be opened                                                                                                                 | 8                                     |
| auth\_idle\_pool\_size   |    no    | Minimum number of connections that must be kept open                                                                                                            | 2                                     |
| server\_uri              |   yes    | A string containing a LDAP URI or a list of URIs                                                                                                                | ldap://localhost:389/                 |
| bind\_dn                 |    no    | The distinguished name (DN) to use for binding to the LDAP server when using simple bind authentication                                                         | cn=admin,dc=example,dc=com            |
| bind\_pw                 |    no    | The password to use for binding to the LDAP server when using simple bind authentication                                                                        | secret                                |
| starttls                 |    no    | Is STARTTLS used with the LDAP connection                                                                                                                       | true / false                          |
| tls\_skip\_verify        |    no    | If you use self signed certificates, you may to skip TLS verification                                                                                           | true / false                          |
| sasl\_external           |    no    | Use simple bind or SASL/EXTERNAL                                                                                                                                | true / false                          |
| pool\_only               |    no    | Use Lua to communicate with LDAP                                                                                                                                | true / false                          |
| connect\_abort\_timeout  |    no    | _New in version 1.4.12_:<br/>If a pool is exhausted and a new connection can not be established within **connect\_abort\_timeout**, the request will temp-fail. | 10s (default). Maximum 10m is allowed |

### ldap::optional_ldap_pools

_New in version 1.5.0_

This section allows you to define additional LDAP pools with different configurations. This is useful when you need to connect to multiple LDAP servers with different settings.

```yaml
ldap:
  optional_ldap_pools:
    pool1:
      lookup_pool_size: 5
      lookup_idle_pool_size: 1
      auth_pool_size: 5
      auth_idle_pool_size: 1
      server_uri: ldap://ldap1.example.com:389/
      starttls: true
      tls_skip_verify: false
    pool2:
      lookup_pool_size: 3
      lookup_idle_pool_size: 1
      auth_pool_size: 3
      auth_idle_pool_size: 1
      server_uri: ldap://ldap2.example.com:389/
      starttls: true
      tls_skip_verify: false
```

You can then reference these pools in your search configurations using the `pool_name` parameter:

```yaml
ldap:
  search:
    - protocol: imap
      cache_name: dovecot
      pool_name: pool1
      base_dn: ou=people,ou=it,dc=example,dc=com
      # ...
```

## SASL/EXTERNAL Configuration

If using SASL/EXTERNAL:

| Key               |           Required           | Description                           | Example                      |
|-------------------|:----------------------------:|---------------------------------------|------------------------------|
| tls\_ca\_cert     | (yes) if starttls is enabled | CA bundle or CA file in PEM format    | /path/to/company/ca-file.pem |
| tls\_client\_cert |            (yes)             | X509 client certificate in PEM format | /path/to/client/cert.pem     |
| tls\_client\_key  |            (yes)             | X509 client key in PEM format         | /path/to/client/key.pem      |

> Note:
>
> Make sure to remove a key passphrase from the key.

## Pooling

Nauthilus will open as many connections, as the **\*\_idle\_pool\_size** value defines. All other connections are done on demand. A background thread (30
seconds delay) will observe a pool and will close unused connections.

If a new connection is required, Nauthilus first checks, if there is some free connection available and picks it up. If none
is free, a new connection is opened. If the pool is exhausted, requests are enqueued until a new connection is free
again.

## Bind Method

Nauthilus can either do a so-called simple bind, using a bind DN and a bind password, or it can do SASL/EXTERNAL using
a X509 client certificate and key. Please check your LDAP configuration to find out, which mode is available for you.

## Search Configuration

### ldap::search

This section defines blocks that combine protocols and LDAP filters. Here is a table of keys that are known:

### Definition of a search list

| Key         | Required | Description                                                                                                                                                                                                                                    | Example |
|-------------|:--------:|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| protocol    |   yes    | A protocol name or a list of protocols in YAML format                                                                                                                                                                                          | imap    |
| cache\_name |    no    | A namespace for the Redis cache                                                                                                                                                                                                                | dovecot |
| pool\_name  |    no    | The name of the LDAP pool to use for this search. If not specified, the default pool is used.                                                                                                                                                  | pool1   |
| base\_dn    |   yes    | The LDAP base DN for the queries                                                                                                                                                                                                               |         |
| filter      |   yes    | Section of LDAP filters                                                                                                                                                                                                                        | -       |
| mapping     |   yes    | Query result attribute/logic mapping                                                                                                                                                                                                           | -       |
| attribute   |   yes    | One string representing an attribute from the user object or a YAML-list of attributes from an user object. The results are used either in HTTP-response-headers with a **X-Nauthilus-Attributename** or used to assemble Open ID token claims | uid     |

### Filter Configuration

| Key                   | Required | Description                                                                                                                                                                                                                                    | Example           |
|-----------------------|:--------:|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------|
| user                  |   yes    | LDAP filter to retrieve a user DN for a re-bind operation                                                                                                                                                                                      | Example see below |
| list\_accounts        |    no    | Nauthilus may return a list of known account names in an HTTP response, if the GET query string contains mode=list-accounts                                                                                                                    | Example see below |
| webauthn\_credentials |    no    | LDAP filter to retrieve WebAuthn credentials for a user                                                                                                                                                                                        | Example see below |

### Mapping Configuration

| Key                     | Required | Description                                                        | Example                 |
|-------------------------|:--------:|--------------------------------------------------------------------|-------------------------|
| account\_field          |   yes    | This result of this attribute is returned as the user account      | uid                     |
| totp\_secret\_field     |    no    | Tell Nauthilus which field is used for the TOTP secret key         | rns2FATOTPSecret        |
| totp\_recovery\_field   |    no    | Tell Nauthilus which field is used for the TOTP recovery codes     | rns2FATOTPRecoveryCode  |
| display\_name\_field    |    no    | Tell Nauthilus which field is used for the display name            | cn                      |
| credential\_object      |    no    | Tell Nauthilus which object class is used for WebAuthn credentials | rns2FAWebAuthn          |
| credential\_id\_field   |    no    | Tell Nauthilus which field is used for the WebAuthn credential ID  | rns2FAWebAuthnCredID    |
| public\_key\_field      |    no    | Tell Nauthilus which field is used for the WebAuthn public key     | rns2FAWebAuthnPubKey    |
| unique\_user\_id\_field |    no    | Tell Nauthilus which field is used for the WebAuthn unique user ID | entryUUID               |
| aaguid\_field           |    no    | Tell Nauthilus which field is used for the WebAuthn AAGUID         | rns2FAWebAuthnAAGUID    |
| sign\_count\_field      |    no    | Tell Nauthilus which field is used for the WebAuthn sign count     | rns2FAWebAuthnSignCount |

## Example Configuration

```yaml
ldap:
  config:
    number_of_workers: 10
    lookup_pool_size: 8
    lookup_idle_pool_size: 2
    auth_pool_size: 8
    auth_idle_pool_size: 2

    server_uri: ldap://some.server:389/
    bind_dn: cn=admin,dc=example,dc=com
    bind_pw: secret
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
```

## TOTP Schema Example

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

It will be enhanced over time to support webauthn as well.
