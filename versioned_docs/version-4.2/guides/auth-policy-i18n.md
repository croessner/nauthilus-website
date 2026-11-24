---
title: Policy Response Localization
description: Localized Policy response messages, language selection, and generation-owned catalogs in Nauthilus v4
keywords: [Policy, I18N, Localization, Response Messages, Nauthilus v4]
sidebar_position: 12
---

# Policy Response Localization

Nauthilus v4 keeps Policy localization inside the owning namespace. A rule selects a stable translation key and deterministic fallback; the HTTP, gRPC, or IdP response boundary resolves the final language.

## Generation-owned catalogs

The effective catalog is the immutable combination of built-in system resources, startup Lua catalogs, and top-level Policy catalogs. Startup and system catalogs are restart-bound. A successful config reload replaces only the top-level Policy layer.

```yaml
policy:
  namespaces:
    authn:
      localization:
        catalogs:
          - namespace: company
            language: en
            entries:
              policy.company.account_locked: Login failed because the account is locked.
```

A request uses the catalog captured by its active Policy generation. Failed reloads do not alter the active resolver.

## Rule-selected response messages

```yaml
policy:
  namespaces:
    authn:
      policy_sets:
        configured:
          visibility: private
          rules:
            - name: deny_locked_account
              checkpoint: auth_decision
              actions: [authenticate]
              if:
                attribute: subject.account_locked
                is: true
              then:
                decision: deny
                response_marker: auth.response.fail
                response_language:
                  from: attribute
                  attribute: request.language
                  fallback: en
                response_message:
                  from: i18n
                  i18n_key: policy.company.account_locked
                  fallback: Login failed because the account is locked.
```

Keep the fallback safe for direct client display. A missing key, missing language, or invalid language candidate uses the fallback instead of exposing an internal lookup error.

## Allowlisted language candidates

Do not expose arbitrary request data to Policy. Allowlist and normalize only the intended header or gRPC metadata key:

```yaml
policy:
  namespaces:
    authn:
      fact_sources:
        http_headers:
          - header: Accept-Language
            attribute: request.language
            visibility: public
            normalize:
              trim: true
              case: lower
              max_length: 32
        grpc_metadata:
          - key: x-response-language
            attribute: request.language
            visibility: public
            normalize:
              trim: true
              case: lower
              max_length: 32
```

The response rule still owns whether an allowlisted candidate becomes rendering metadata.

## Startup Lua catalog overlays

Deployment-owned startup code may register immutable catalog entries:

```lua
nauthilus_i18n.register_catalog({
  namespace = "company",
  language = "en",
  entries = {
    ["policy.company.account_locked"] = "Login failed because the account is locked.",
  },
})
```

Request-time Lua should emit stable facts. Use `nauthilus_i18n.get_localized(...)` only for Lua-owned logs, notices, or fallback strings; final authentication responses should remain rule-selected so reports and all transports share one decision path.

Do not add deployment-only keys to Nauthilus system resource files. Keep them in deployment startup catalogs or top-level `policy.namespaces.<namespace>.localization.catalogs`.

See [I18N Lua API](../lua-api/i18n.md), [Policy Configuration](../configuration/auth-policy.md), and the [manual v4 migration contract](policy-configuration-migration.md).
