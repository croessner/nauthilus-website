---
title: Policy Configuration
description: Top-level v4 Policy configuration ownership, targets, namespaces, and runtime authority
keywords: [Configuration, Policy, Auth, Decision, Nauthilus v4]
sidebar_position: 8
---

# Policy Configuration

Nauthilus v4 uses top-level `policy` as the sole production configuration and runtime authority for authentication, IdP, backchannel, Policy HTTP, and Policy gRPC decisions.

:::danger Breaking change

The v3 `auth.policy` root is removed. Old-root and mixed-root input is rejected before candidate preparation. There is no runtime compatibility path or supported converter.

:::

## Ownership model

A complete Policy generation owns all of these resources together:

- `policy.api`: Policy HTTP and gRPC transport settings, limits, and caller profiles
- `policy.namespaces.<namespace>`: schemas, providers, effects, localization, condition sets, domain plans, and policy sets
- `policy.targets[]`: the exact namespace, action, schema, mode, default policy, domain plan, checkpoint plans, and report settings activated at runtime

The built-in authentication fallback has the qualified identity `authn/standard_auth`. The unqualified v3 spelling `standard_auth` is rejected.

## Minimal authn target

```yaml
policy:
  namespaces:
    authn:
      policy_sets:
        configured:
          visibility: private
          rules: []
      domain_plans:
        password:
          checkpoints:
            auth_decision:
              providers: []
  targets:
    - namespace: authn
      action: authenticate
      schema: authn/authenticate/v1
      mode: enforce
      default_policy: authn/standard_auth
      domain_plan: authn/password
```

Provider scheduling belongs to a checkpoint under a domain plan. Rules use `checkpoint`, provider instances use exact qualified `use` identities, and target plans import exact qualified policy-set identities. The removed v3 fields `stage` and `config_ref` are not aliases.

## Generation behavior

Startup and reload use the same prepare, validate, and commit boundary. A failed candidate leaves the previous complete generation active, and an in-flight request keeps the generation on which it started.

Policy and backchannel credentials are separate resource families:

- Policy Bearer tokens use the exact audience `nauthilus:policy`.
- Backchannel tokens use the exact audience `nauthilus:backchannel`.
- Policy-Basic is Policy-only and does not reuse management Basic credentials.

See the [field-complete manual migration contract](../guides/policy-configuration-migration.md) and the [v4 migration landing](../guides/v4-migration.md).
