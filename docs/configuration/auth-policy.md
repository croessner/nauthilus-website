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

## Rule decisions

`then.decision` is namespace-owned:

| Namespace | Accepted values |
| --- | --- |
| generic namespaces | `permit`, `deny` |
| `authn` | `permit`, `deny`, `tempfail`, `neutral` |

In `authn` rules, `tempfail` and `neutral` keep their authentication meaning. Internally they map to the Policy runtime
effects `indeterminate` and `not_applicable`, but those internal effect names are rejected as configured rule decisions
in every namespace. A generic namespace that configures `tempfail` or `neutral` fails validation with
`must be permit or deny`.

```yaml
policy:
  namespaces:
    authn:
      policy_sets:
        configured:
          visibility: private
          rules:
            - name: tempfail_on_backend_error
              checkpoint: auth_decision
              actions: [authenticate]
              if:
                attribute: nauthilus.auth.backend.tempfail
                is: true
              then:
                decision: tempfail
```

`nauthilus.auth.backend.tempfail` is also true when the backend verified the password as wrong but the brute-force
store could not record the repeating-wrong-password verdict. Such requests are answered as temporary failures and are
not counted toward brute-force buckets.

### Authn rule decisions per checkpoint

An authn target evaluates its checkpoints in the order `pre_auth`, `auth_backend`, `subject_analysis`,
`account_provider`, `auth_decision`. The final checkpoint is the last one of the target plan: `auth_decision` for
targets without a domain plan, otherwise the last checkpoint the selected domain plan declares. A rule selected at the
final checkpoint must decide the request; a rule selected earlier can only end it early or let it continue.

| Checkpoint position | Allowed decisions |
| --- | --- |
| final checkpoint | `permit`, `deny`, `tempfail` |
| any earlier checkpoint | `deny`, `tempfail`, `neutral` |

Configuration loading and `--config-check` reject any other combination at `then.decision` and name the rule, the
target, the checkpoint, the final checkpoint, and the allowed decisions.

### Auth FSM event markers

Every rule that an `authn` target binds selects an auth FSM event when it is selected. An omitted `fsm_event_marker`
is derived from the checkpoint and the decision. An explicit marker must be one the auth FSM can apply for that
decision at that checkpoint:

| Checkpoint | Decision | Derived `fsm_event_marker` | Other allowed explicit markers |
| --- | --- | --- | --- |
| `pre_auth` | `deny` | `auth.fsm.event.pre_auth_deny` | none |
| `pre_auth` | `tempfail` | `auth.fsm.event.pre_auth_tempfail` | none |
| `pre_auth` | `neutral` | `auth.fsm.event.pre_auth_ok` | none |
| any later checkpoint | `permit` (final checkpoint only) | `auth.fsm.event.auth_permit` | none |
| any later checkpoint | `deny` | `auth.fsm.event.auth_deny` | `auth.fsm.event.auth_empty_pass` for `authenticate` and `lookup_identity` |
| any later checkpoint | `tempfail` | `auth.fsm.event.auth_tempfail` | `auth.fsm.event.auth_empty_user` for `authenticate` and `lookup_identity` |
| any later checkpoint | `neutral` (earlier checkpoints only) | none | none |

Later checkpoints are `auth_backend`, `subject_analysis`, `account_provider`, and `auth_decision`. A rule without
`actions` is checked for every authn target that binds it, so an explicit `auth_empty_user` or `auth_empty_pass` is
rejected when the rule is also bound to `list_accounts`. A `permit` in a plan whose only checkpoint is `pre_auth` has
no marker and is rejected. Configuration loading and `--config-check` reject an explicit marker that contradicts the
decision or the checkpoint, naming the rule path, the target, the checkpoint, and the allowed markers. Rules in generic
namespaces do not drive the auth FSM, are not restricted by checkpoint position, and need no marker.

```yaml
then:
  decision: deny
  reason: rbl
  fsm_event_marker: auth.fsm.event.pre_auth_deny
```

### Host evidence guard

The auth FSM is a hard guard: Policy can tighten an authn result but never loosen it. Nauthilus drives the FSM from
evidence the host collects itself, not from the selected rule:

| Operation | Host evidence a permit requires |
| --- | --- |
| `authenticate` | the configured backends verified the credential, including a positive in-memory or Redis cache hit and master-user verification |
| `lookup_identity` | a backend found the identity |
| `list_accounts` | every account database answered without error |

The host freezes this verdict when backend verification or the account provider completes, before subject providers,
Lua or native plugins, cached projections, or Policy facts see it. A subject provider may reject a verified credential
or a found identity, but it cannot turn a failed or missing verification into a success: a backend result patch or
subject result that raises the authenticated or user-found flag is reset to the host verdict, logged at warn level,
and never stored in the positive password cache.

- A selected `deny` or `tempfail` always applies. The FSM records the host event when it ends in the same terminal
  state, for example `auth_empty_user` for an empty username even when the rule names `auth_tempfail`.
- A selected `permit` applies only when the frozen host evidence supports it. Otherwise the request is answered as a
  temporary failure, the FSM records `auth_tempfail`, the event is logged at error level as
  `Policy permit rejected by the auth FSM guard`, and `authn_fsm_guard_violations_total{operation,checkpoint}` is
  incremented. The same applies when a plan ends without a selected rule and the host result would answer ok without
  that evidence.
- The check runs before any effect is dispatched. A permit without host evidence runs none of its obligations,
  post-actions, or advice, so no login log or learning plugin records the request as a success. Effects of a selected
  `deny` or `tempfail` run unchanged.
- A `list_accounts` permit needs every account database to answer. A policy that permits although
  `nauthilus.auth.account_provider.tempfail` is true, for example to return a partial listing, is answered with a
  temporary failure.

The guard counter should stay at zero. An increase points to a rule that permits without testing
`backend.authenticated`, `backend.identity_found`, or `backend.account_provider_completed`, or to a plan without a
backend or account provider.

## Numeric operands

Authored numbers keep their kind across YAML, JSON, and TOML loading: an integer literal such as `50` is an integer, and
a literal written with a decimal point, such as `50.0`, is a double. Earlier v4 prereleases folded
whole-number doubles into integers.

Integer and double values are compatible numeric kinds. Rules, imported policy-set contracts, and host scheduler guards
may compare an integer fact with a double operand and the reverse. Equality and ordered comparisons use the exact
numeric value, so `gte: 0.5` against an integer fact and `eq: 1.0` against integer `1` behave as expected.

## Record predicates

A `records` fact is an ordered list of schema-bound records. A record predicate evaluates one `where` expression
against each record and then applies the quantifier:

```yaml
if:
  records:
    attribute: resource.approvals
    quantifier: any
    where:
      all:
        - {field: department, eq: engineering}
        - {field: approved, eq: true}
```

| Key | Rule |
| --- | --- |
| `records.attribute` | One exact `records` fact of the target schema. |
| `records.quantifier` | `any`, `all`, or `none`. |
| `records.where` | Either one leaf `{field: <name>, <operator>: <operand>}` or one logical form `all`, `any`, or `not` whose children are again record-local expressions. |

Every leaf inside one `where` tree refers to the same record, so the example matches only a record that is both from
engineering and approved. Leaves use the normal typed operators and compatible condition-set references. `field` must
name a static, schema-visible field (`expression_visible: true`) and is allowed only inside `records.where`. Nested
`records`, external `attribute` or `detail` references, `always`, empty logical groups, mixing a field operator with a
logical form, hidden fields, and more than 16 nesting levels or 64 children in one group fail compilation. The overall
expression limits of 16 levels, 256 nodes, and 64 children per group still apply.

Record predicates are supported in Policy rules. Host scheduler guards (`run_if`/`skip_if`) reject them because their
tri-state missing-fact semantics do not support record evaluation.

A missing records fact makes every quantifier false. A present empty collection makes `any` false and `all`/`none` true.
Declare `min_records: 1` in the fact's `record_schema` for permit-sensitive collections, and make providers supply
complete schema-valid evidence to prevent a vacuous permit.

:::warning Breaking change

The outer `records.field` key of earlier v4 prereleases is removed and rejected. Move the field into the leaf:

```yaml
# before
records: {attribute: plugin.example.chain, quantifier: any, field: acceptable, where: {eq: false}}
# after
records: {attribute: plugin.example.chain, quantifier: any, where: {field: acceptable, eq: false}}
```

:::

## Host-owned authentication facts

In addition to the caller-supplied `input.auth.*` facts, all `authn` targets expose these Nauthilus-owned environment
facts. They can be used in rules and, for the `nauthilus.request.client.ip*` facts, in host scheduler guards:

| Fact | Type | Meaning |
| --- | --- | --- |
| `nauthilus.request.client.ip` | string | Host-normalized end-client address. |
| `nauthilus.request.client.ip.present` | boolean | Whether a normalized end-client address exists. |
| `nauthilus.request.client.ip.trusted` | boolean | Whether the normalized end-client path is trusted. |
| `nauthilus.request.caller.ip` | string | Directly observed caller address. |
| `nauthilus.request.caller.ip.present` | boolean | Whether a direct caller address exists. |
| `nauthilus.request.local.ip` | string | Host-normalized local endpoint address. |
| `nauthilus.request.local.ip.present` | boolean | Whether a normalized local endpoint address exists. |

The `authenticate` action additionally exposes the boolean facts `nauthilus.auth.master_user.active` (subject),
`nauthilus.auth.brute_force.toleration.custom`, and `nauthilus.auth.brute_force.toleration.suppressed_block`.

## Provider identities and native components

Provider map keys under `policy` are preserved exactly, including dots, for example
`plugin.customer_risk.environment`.

A generic native provider (`kind: native`) derives its canonical identity `<namespace>/plugin.<module>.<component>`
from the map key unless `component` selects the registered native component explicitly. This lets two authored names
select components of different modules in one namespace:

```yaml
policy:
  namespaces:
    dkim2:
      providers:
        reputation_assessment:
          kind: native
          module: reputation
          component: assessment
          targets: [{action: accept-message-instance}]
          failure: indeterminate
          timeout: 400ms
          # produced_facts and requires omitted
        intelligence_assessment:
          kind: native
          module: dkim2_intelligence
          component: assessment
          targets: [{action: accept-message-instance}]
          failure: indeterminate
          timeout: 400ms
          # produced_facts and requires omitted
```

The canonical IDs are `dkim2/plugin.reputation.assessment` and `dkim2/plugin.dkim2_intelligence.assessment`; plan `use`
entries and exact dependencies use those IDs. `component` is accepted only for generic native providers, and two
entries that resolve to the same canonical identity fail validation with `duplicates an exact provider identity`.

### Built-in authentication providers

Plan `use` entries reference built-in authentication providers by their exact identity:

| Instance name | Exact identity |
| --- | --- |
| `brute_force` | `authn/builtin/brute_force` |
| `tls_encryption` | `authn/builtin/tls_encryption` |
| `relay_domains` | `authn/builtin/relay_domains` |
| `rbl` | `authn/builtin/rbl` |
| `backend_order` | `authn/auth_backend` |
| `ldap_backend` | `authn/builtin/ldap_backend` |
| `lua_backend` | `authn/builtin/lua_backend` |
| `plugin_backend_order` | `authn/builtin/plugin_backend_order` |
| `account_provider` | `authn/builtin/account_provider` |

`authn/auth_backend` is the aggregate backend provider: it runs the cache and the backends of `auth.backends.order` in
order. The bare instance names are accepted only in `require_providers` of a rule that has no domain plan. A built-in
provider is only accepted at a checkpoint whose immutable schedule contains it.

## Runtime capacity

`policy.runtime` sizes the host-owned parts of a Policy generation:

```yaml
policy:
  runtime:
    post_actions:
      workers: 8              # default 8, 1..1024, must not exceed queue_capacity
      queue_capacity: 256     # default 256, 1..65536
    authn:
      max_concurrency: 0      # default 0 = unbounded, 0..1000000
      requests_per_second: 0  # default 0 = unbounded, 0..10000000
```

### Post-action supervisor

Every Policy generation owns one post-action supervisor with a fixed worker set and a bounded queue. A post-action is
accepted synchronously before the response is finalized. When the queue is full the acceptance fails with the error
class `saturated`, and the authentication request ends as a temporary failure. Size `workers` as roughly the peak
accepted post-actions per second times the average post-action duration in seconds, with headroom. The counters
`post_action_effect_states_total{state,phase,boundary}` and `post_action_acceptance_failures_total{error_class}`
expose the supervisor; any `saturated` increase means requests failed temporarily.

### Internal authentication admission

Every authentication request (HTTP backchannel, nginx, gRPC authority, and the identity provider) opens one Decision
Session under a host-owned internal caller profile. These profiles do not inherit
`policy.api.limits.per_client_concurrency` or `policy.api.limits.per_client_requests_per_second`, which govern external
Policy API clients only; request-size and fact-count limits are still inherited from `policy.api.limits`.

By default internal authentication has no separate admission bound, because `auth.pipeline.max_concurrent_requests`
already bounds it. `policy.runtime.authn` adds an explicit bound per internal caller profile, that is per entry point
and operation. An exhausted bound ends the request as a regular temporary failure: the HTTP endpoints answer with their
temporary-failure representation including `Auth-Status`, and the gRPC authority returns `AUTH_DECISION_TEMPFAIL`.
Other admission rejections, such as a missing grant, stay fail-closed. `policy_authn_admission_rejections_total{reason}`
counts rejections with the reason `concurrency` or `rate`, and each one is logged at warn level.

A reload that changes `policy.runtime` builds the next generation with a new supervisor and new internal profiles.

### Unexpected application errors

An admitted authentication session can still end without a decision, for example when a `host_sync` provider fails or
the Decision Service generation is unavailable. Such unexpected errors end as a regular temporary failure and never
authenticate the request. The HTTP auth endpoints answer with `Auth-Status: Temporary server problem, try again later`
(nginx with HTTP 200 and `Auth-Error-Code` for SMTP, the other surfaces with HTTP 500), and the gRPC authority returns
`AUTH_DECISION_TEMPFAIL` (`ListAccounts` returns an empty listing). Typed rejections keep their mapping: invalid input
stays HTTP 400 or `InvalidArgument`, and permission denials stay HTTP 403 or `PermissionDenied`. Each error is logged as
`Authentication application failed` with the cause and counted by `auth_application_errors_total{transport}`.

## Generation behavior

Startup and reload use the same prepare, validate, and commit boundary. A failed candidate leaves the previous complete generation active, and an in-flight request keeps the generation on which it started.

Policy and backchannel credentials are separate resource families:

- Policy Bearer tokens use the exact audience `nauthilus:policy`.
- Backchannel tokens use the exact audience `nauthilus:backchannel`.
- Policy-Basic is Policy-only and does not reuse management Basic credentials.

See the [field-complete manual migration contract](../guides/policy-configuration-migration.md) and the [v4 migration landing](../guides/v4-migration.md).
