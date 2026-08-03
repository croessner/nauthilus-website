---
title: Auth Policy I18N Guide
description: Complete examples for localized auth policy response messages, response language selection, Lua migration, and catalog overlays
keywords: [Guide, Policy, I18N, Localization, Lua, gRPC, HTTP]
sidebar_position: 8
---

# Auth Policy I18N Guide

This guide shows the complete localization path for policy-selected authentication response messages.

Use this when a custom `auth.policy` rule should select a stable translation key, keep deterministic fallback text, and let HTTP, gRPC, or IdP response rendering choose the final language.

## Mental Model

Policy evaluation stays locale-neutral:

1. Lua, built-in checks, backends, request headers, or gRPC metadata emit policy facts.
2. `auth.policy.policies` selects the decision, response marker, optional `response_language`, and `response_message`.
3. The response boundary resolves `i18n_key` into rendered text.
4. Missing translations return the configured fallback text.

Language preference never changes the selected policy decision.

## Minimal Localized Response

```yaml
auth:
  policy:
    attribute_exports:
      - name: account_status
        attribute: accountStatus
        type: string
        sensitivity: internal

    policies:
      - name: deny_company_locked_account
        stage: auth_decision
        operations: [authenticate]
        if:
          attribute: auth.subject.attribute.account_status
          detail: value
          eq: locked
        then:
          decision: deny
          reason: company_account_locked
          response_marker: auth.response.fail
          response_message:
            from: i18n
            i18n_key: auth.policy.company.account_locked
            fallback: "Login failed because the account is locked."
```

Rules:

- `from: i18n` requires `i18n_key` and fallback text.
- `i18n_key` is stable machine-readable policy metadata.
- `fallback` is the response text when no translation exists.
- Do not use `text`, `attribute`, or `detail` together with `from: i18n`.
- Existing `from: default`, `from: literal`, and `from: attribute_detail` behavior is unchanged.

## Literal Response Language

Use `response_language.from: literal` when the rule itself knows the response language:

```yaml
then:
  decision: deny
  reason: company_account_locked
  response_marker: auth.response.fail
  response_language:
    from: literal
    language: de
  response_message:
    from: i18n
    i18n_key: auth.policy.company.account_locked
    fallback: "Login failed because the account is locked."
```

The value must be a BCP 47 language tag. Policy-selected language takes precedence over HTTP `Accept-Language` and gRPC `accept-language`, but IdP URL or cookie language selection remains more explicit than policy language.

## Header-Selected Language

Use `auth.policy.request_headers` to expose only a trusted, bounded header:

```yaml
auth:
  policy:
    attribute_exports:
      - name: account_status
        attribute: accountStatus
        type: string
        sensitivity: internal

    request_headers:
      - header: X-Company-Language
        attribute: request.header.company_language
        visibility: public
        normalize:
          trim: true
          case: lower
          max_length: 16

    policies:
      - name: deny_locked_account_with_header_language
        stage: auth_decision
        operations: [authenticate]
        if:
          attribute: auth.subject.attribute.account_status
          detail: value
          eq: locked
        then:
          decision: deny
          reason: company_account_locked
          response_marker: auth.response.fail
          response_language:
            from: attribute
            attribute: request.header.company_language
            fallback: en
          response_message:
            from: i18n
            i18n_key: auth.policy.company.account_locked
            fallback: "Login failed because the account is locked."
```

HTTP response behavior:

- Incoming `Accept-Language` is used when no policy language exists.
- Policy-selected `response_language` overrides `Accept-Language`.
- The existing status-message field or status header contains rendered text.
- `Content-Language` is emitted when localization selected a language.

## gRPC Metadata-Selected Language

Use `auth.policy.request_metadata` for gRPC metadata facts:

```yaml
auth:
  policy:
    attribute_exports:
      - name: account_status
        attribute: accountStatus
        type: string
        sensitivity: internal

    request_metadata:
      - key: x-company-language
        attribute: request.metadata.company_language
        visibility: public
        normalize:
          trim: true
          case: lower
          max_length: 16

    policies:
      - name: deny_locked_account_with_metadata_language
        stage: auth_decision
        operations: [authenticate]
        if:
          attribute: auth.subject.attribute.account_status
          detail: value
          eq: locked
        then:
          decision: deny
          reason: company_account_locked
          response_marker: auth.response.fail
          response_language:
            from: attribute
            attribute: request.metadata.company_language
            fallback: en
          response_message:
            from: i18n
            i18n_key: auth.policy.company.account_locked
            fallback: "Login failed because the account is locked."
```

gRPC response behavior:

- Incoming metadata `accept-language` is used when no policy language exists.
- Policy-selected `response_language` overrides incoming `accept-language`.
- The existing `status_message` protobuf field contains rendered text.
- Response metadata includes `content-language` when localization selected a language.
- The protobuf response does not expose `i18n_key`.

## Lua Migration Pattern

Keep Lua-owned text as fallback, and emit stable facts for policy:

```lua
local policy = require("nauthilus_policy")

if account_status == "locked" then
  nauthilus_builtin.status_message_set("Login failed because the account is locked.")
  policy.emit_attribute({
    id = "lua.company.account_status",
    value = "locked",
  })
end
```

Register the attribute during policy snapshot build:

```lua title="/etc/nauthilus/policy/attributes.lua"
nauthilus_policy.register_attribute({
  id = "lua.company.account_status",
  stage = "subject_analysis",
  operations = { "authenticate" },
  category = "subject",
  type = "string",
  description = "Company account status selected by Lua",
})
```

Then map the stable fact to an i18n key in YAML:

```yaml
auth:
  policy:
    registry_scripts:
      - /etc/nauthilus/policy/attributes.lua

    policies:
      - name: deny_lua_company_locked_account
        stage: auth_decision
        operations: [authenticate]
        require_checks: [lua_subject_company_account]
        if:
          attribute: lua.company.account_status
          eq: locked
        then:
          decision: deny
          reason: company_account_locked
          response_marker: auth.response.fail
          response_message:
            from: i18n
            i18n_key: auth.policy.company.account_locked
            fallback: "Login failed because the account is locked."
```

Do not make free-text Lua status messages the source of i18n keys. Lua emits facts; policy chooses keys.

## Lua-Selected Response Language

Lua can emit a language candidate as another registered policy attribute:

```lua
local policy = require("nauthilus_policy")

if preferred_language ~= "" then
  policy.emit_attribute({
    id = "lua.company.preferred_language",
    value = preferred_language,
  })
end
```

Registry entry:

```lua
nauthilus_policy.register_attribute({
  id = "lua.company.preferred_language",
  stage = "subject_analysis",
  operations = { "authenticate" },
  category = "subject",
  type = "string",
  description = "Preferred response language selected by Lua",
})
```

Policy rule:

```yaml
then:
  decision: deny
  response_marker: auth.response.fail
  response_language:
    from: attribute
    attribute: lua.company.preferred_language
    fallback: en
  response_message:
    from: i18n
    i18n_key: auth.policy.company.account_locked
    fallback: "Login failed because the account is locked."
```

Invalid runtime language tags are ignored and fall through to the next language preference source.

## Deployment Catalog Overlay

Deployment-owned translations belong outside Nauthilus system resource files. Register them during startup Lua:

```yaml title="nauthilus.yml"
auth:
  backends:
    lua:
      backend:
        default:
          init_script_paths:
            - /etc/nauthilus/policy/i18n.lua
```

```lua title="/etc/nauthilus/policy/i18n.lua"
local i18n = require("nauthilus_i18n")

i18n.register_catalog({
  language = "en",
  namespace = "company",
  entries = {
    ["auth.policy.company.account_locked"] = "Login failed because the account is locked.",
    ["auth.policy.company.account_unpaid"] = "Login failed because open payments exist and the account is locked.",
  },
})
```

Equivalent deployment-owned JSON material can look like this:

```json title="policy-en.json"
{
  "auth.policy.company.account_locked": "Login failed because the account is locked.",
  "auth.policy.company.account_unpaid": "Login failed because open payments exist and the account is locked."
}
```

Catalog semantics:

- System catalog entries are loaded first.
- Deployment overlays are merged after the system catalog in deterministic order.
- Deployment overlays may override system keys.
- Overrides are logged with language, key, namespace, and previous namespace.
- The effective catalog is frozen before request-time processing.
- Reload builds the next effective catalog first and activates it atomically only after success.
- Failed reload keeps the previous effective catalog active.

## Request-Time Lua Localization

Use `nauthilus_i18n.get_localized({ ... })` only for Lua-owned logs, notices, or fallback strings:

```lua
local i18n = require("nauthilus_i18n")

local localized = i18n.get_localized({
  i18n_key = "auth.policy.company.account_locked",
  fallback = "Login failed because the account is locked.",
  language = "en",
})

nauthilus_builtin.custom_log_add("company_message", localized.message)
nauthilus_builtin.custom_log_add("company_message_localized", localized.localized)
```

`get_localized` accepts exactly one table and returns exactly one table with `message`, `language`, `localized`, `i18n_key`, and `fallback_used`. It is read-only and cannot mutate catalogs.

## Fallback Behavior

Fallback text is used when:

- `response_message` has no `i18n_key`;
- the resolver is unavailable for a response surface;
- the requested key is missing in the selected catalog;
- the selected language is unsupported and no later preference can resolve it;
- a request-time Lua `get_localized` call cannot resolve the key.

Fallback does not change the selected decision, response marker, FSM marker, or obligations. It only determines the rendered message text.

## Mocking Checklist

Use mocks and fakes for focused tests:

| Topic | Test seam |
|---|---|
| Policy config | Table-driven compiler tests for valid and invalid `response_message`, `response_language`, `request_headers`, and `request_metadata`. |
| Resolver | Fake catalog or fake resolver for selected language, missing key, fallback, and max-length behavior. |
| HTTP | `httptest` requests with explicit `Accept-Language`, allowlisted headers, and a fake resolver. |
| gRPC | Handler or in-memory gRPC tests with incoming metadata and a fake auth outcome. |
| IdP | Mock auth outcomes carrying fallback text, optional `i18n_key`, and optional policy language. |
| Lua policy | `--test-lua` fixtures or hermetic Lua states that assert `nauthilus_policy.emit_attribute(...)`. |
| Lua i18n | Fake resolver and fake startup catalog collector for `get_localized` and `register_catalog`. |
| Reload | Fake catalog sessions that prove atomic activation and failed-reload rollback. |

Do not add documentation-only example keys to `server/resources/*.json`. Tests can use fake catalogs or deployment-style fixtures for `auth.policy.company.*` keys.

## Related Reference

- [Auth Policy Reference](../configuration/auth-policy.md)
- [Auth Policy Configuration Guide](auth-policy-configuration.md)
- [Lua Policy API](../lua-api/policy.md)
- [Lua I18N API](../lua-api/i18n.md)
- [REST API](../rest-api.md)
- [gRPC Auth API](../grpc-api.md)
