---
title: Policy Configuration Guide
description: Practical entry point for the v4 top-level Policy configuration model
keywords: [Configuration, Policy, Auth, Decision, Migration, Nauthilus v4]
sidebar_position: 3
---

# Policy Configuration Guide

Nauthilus v4 replaces the v3 authentication-only policy layout with one namespace-owned, top-level `policy` model. Use this guide to orient a new configuration; use the [manual migration contract](policy-configuration-migration.md) for the exact field-by-field hard cut.

## Author the namespace first

Each namespace owns its schemas, facts, providers, effects, condition sets, domain plans, localization, and policy sets. Authentication uses the reserved `authn` namespace.

```yaml
policy:
  namespaces:
    authn:
      schema_contributions:
        lua:
          registry_scripts:
            - /etc/nauthilus/lua-plugins.d/policy/registry.lua
      providers:
        lua_subject_geoip:
          kind: lua_subject
          script_path: /etc/nauthilus/lua-plugins.d/subject/geoip.lua
          targets: [{action: authenticate}]
          executions: [host_sync]
      domain_plans:
        password:
          checkpoints:
            subject_analysis:
              providers:
                - name: geoip
                  use: authn/lua_subject_geoip
                  actions: [authenticate]
                  run_if:
                    auth_state: any
      policy_sets:
        configured:
          visibility: private
          rules:
            - name: deny_unexpected_country
              checkpoint: subject_analysis
              actions: [authenticate]
              require_providers: [geoip]
              if:
                attribute: lua.plugin.geoip.rejected
                is: true
              then:
                decision: deny
                response_marker: auth.response.fail
```

Provider definitions do not schedule themselves. The domain plan and checkpoint own execution placement and ordering. Use `after` and `skip_if` only with valid plan-local names.

## Activate an exact target

```yaml
policy:
  targets:
    - namespace: authn
      action: authenticate
      schema: authn/authenticate/v1
      mode: enforce
      default_policy: authn/standard_auth
      domain_plan: authn/password
      plans:
        subject_analysis:
          policy_sets: [authn/configured]
```

Every identity is qualified. Do not use unqualified `standard_auth`, v3 `stage`, or v3 `config_ref`.

## Export only intended facts

Request headers, gRPC metadata, and backend attributes are allowlisted under `policy.namespaces.authn.fact_sources`. Do not expose arbitrary backend data or request metadata to Policy.

```yaml
policy:
  namespaces:
    authn:
      fact_sources:
        backend_attributes:
          - name: department
            attribute: subject.department
            type: string
            sensitivity: internal
```

## Validate the complete generation

Before deployment, validate provider and effect resolution, target/action/schema compatibility, policy-set imports, caller profiles, route enablement, and secret-safe canonical output. A reload is atomic: invalid candidates never partially replace the active generation.

For the complete ownership table, exact v3-to-v4 provider mappings, localization behavior, credential separation, and paired old/new examples, use the [Policy configuration migration contract](policy-configuration-migration.md).
