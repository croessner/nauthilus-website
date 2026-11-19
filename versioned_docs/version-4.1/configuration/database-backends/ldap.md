---
title: LDAP Backend
description: LDAP backend configuration in config v2
keywords: [Configuration, LDAP, Backend]
sidebar_position: 6
---

# LDAP Backend

The LDAP backend now lives under `auth.backends.ldap`.

## Main Structure

```yaml
auth:
  backends:
    ldap:
      default: {}
      pools: {}
      search: []
```

- `default`: the main LDAP pool
- `pools`: named additional pools
- `search`: protocol-specific search definitions

## Default Pool Example

```yaml
auth:
  backends:
    ldap:
      default:
        number_of_workers: 10
        lookup_pool_size: 8
        lookup_idle_pool_size: 2
        auth_pool_size: 8
        auth_idle_pool_size: 2
        server_uri:
          - "ldap://ldap1.example.com:389"
          - "ldap://ldap2.example.com:389"
        bind_dn: "cn=admin,dc=example,dc=com"
        bind_pw: "secret"
        starttls: true
        tls_skip_verify: false
```

## Named Pools

```yaml
auth:
  backends:
    ldap:
      pools:
        pool1:
          lookup_pool_size: 5
          auth_pool_size: 5
          server_uri:
            - "ldap://pool1.example.com:389"
        pool2:
          lookup_pool_size: 3
          auth_pool_size: 3
          server_uri:
            - "ldap://pool2.example.com:389"
```

Reference them from backend order or from search entries.

## Search Example

```yaml
auth:
  backends:
    ldap:
      search:
        - protocol:
            - imap
            - smtp
            - default
          cache_name: "mail"
          pool_name: "pool1"
          base_dn: "ou=people,dc=example,dc=com"
          filter:
            user: "(&(objectClass=inetOrgPerson)(uid=%L{user}))"
          mapping:
            account_field: "uid"
            display_name_field: "cn"
          attribute:
            - "uid"
            - "cn"
            - "mail"
            - "userPassword"
```

## Groups Resolution

Group resolution remains part of search entries and is especially useful for `oidc` and `saml` protocols.

```yaml
auth:
  backends:
    ldap:
      search:
        - protocol:
            - oidc
            - saml
          groups:
            strategy: "search"
            base_dn: "ou=groups,dc=example,dc=com"
            scope: "sub"
            filter: "(&(objectClass=groupOfNames)(member=%{user_dn}))"
            name_attribute: "cn"
            recursive: false
            max_depth: 1
```

## Identity Lookup Cache

Passwordless identity lookups (`mode=no-auth` and the gRPC `LookupIdentity` call) can be served from an opt-in Redis
cache of successful LDAP results:

```yaml
storage:
  redis:
    identity_cache:
      enabled: true
      ttl: 60s
```

The identity cache (UCI) is independent of the positive password cache (UCP): it never carries password evidence and
does not need a `cache` entry in `auth.backends.order`. Identity lookups that are eligible for it bypass the
process-local group membership cache, so a cache miss always resolves current groups from LDAP. Password and IdP
requests keep the existing behavior. A user flush makes all identity entries under the Redis prefix cold. See
[Identity Lookup Cache](../server-configuration.md#identity-lookup-cache) for invalidation and security details.

## Notes

- use `starttls`, not `tls` for LDAP STARTTLS
- `lookup_pool_only` is the current pool-only-style switch on the default/named pool object
- old top-level `ldap.*` paths are no longer the documented surface

## Connection Pool Behavior

- When a request borrows a connection, busy pool slots are skipped instead of waited on, so one slow connection does not stall the pool.
- A request that the pool queue drops receives a temporary failure (`tempfail`) instead of hanging or being treated as a wrong password.
- Pools of the same type are accounted separately; failure logs and backend-fault accounting name the pool that failed.
- Only the LDAP result `invalidCredentials` counts as a wrong password. Other bind or search errors are technical backend faults: they return `tempfail` and are never counted toward brute-force buckets.
- Every pool connection uses the settings of its own pool section: `search_timeout`, `bind_timeout`, `modify_timeout`, `search_size_limit`, `search_time_limit`, `retry_*`, `cb_*`, `health_check_*`, the cache settings, `include_raw_result`, and `auth_rate_limit_*` apply to the LDAP operations themselves. A `search_size_limit` on the default section therefore limits every search of that section, while a named pool keeps its own values.
- Every pool connection has a default operation timeout: the configured `search_timeout`, or 30 seconds when none is set. Connection setup dials with a 5 second timeout and TCP keepalive, and one 30 second deadline bounds the whole connect loop including its backoff. A connection whose server vanished without a reset therefore does not hang until TCP gives up.
- Connections that fail a bind with a timeout or fail to connect are retired. Pool maintenance runs in the background: workers do not connect idle slots before each request, and maintenance skips slots that are in use.
- An auth request rejected by `auth_rate_limit_per_second` returns a temporary failure.
- Concurrent identical searches share one in-flight LDAP request only when base DN, filter, scope, and attribute list are equal, and every caller receives its own copy of the result.
- The `/healthz` readiness check `ldap_queue` marks an instance unready when an LDAP pool holds queued requests that no worker takes. See [Health Endpoints](../server-configuration.md#health-endpoints).

## WebAuthn Credential Updates

When a WebAuthn credential is updated (for example after a sign-in updates its counter), Nauthilus deletes the exact old attribute value and adds the new value in one LDAP modify operation. The bind identity used for MFA writes therefore needs permission to delete values of the configured WebAuthn credential attribute, not only to add them.
