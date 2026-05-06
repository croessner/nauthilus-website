---
title: Auth Policy Reference
description: Complete reference for auth.policy, checks, policies, registries, reports, and validation
keywords: [Configuration, Policy, Auth, Decision, Lua, Observability]
sidebar_position: 8
---

# Auth Policy Reference

`auth.policy` is the declarative decision layer for Nauthilus authentication. It decides from typed facts, not from ad-hoc mechanism flags.

The policy layer is the only target scheduler for auth controls, backend facts, Lua controls, Lua filters, identity lookup, and account listing. Lua and built-in mechanisms still produce facts, but `auth.policy.checks` decides which facts are part of a request plan and `auth.policy.policies` decides how those facts become a final effect.

## Placement and Authority

Policy configuration lives only under:

```yaml
auth:
  policy:
```

There is no separate policy root. The supported configuration surface is `auth.policy`. The built-in default policy set is named `standard_auth`. When no custom policy rules are configured, `standard_auth` preserves the default Nauthilus authentication behavior through the same policy engine.

Lua controls and Lua filters define script entries. Their execution operation, auth-state guard, and start order are defined by `auth.policy.checks`.

`checks` and `policies` have separate authority boundaries. You may configure checks only to control fact collection, Lua script operation scope, auth-state guards, and start order while `standard_auth` remains the decision authority. A stage and operation become custom-authoritative only when matching rules exist in `auth.policy.policies`.

## Root Shape

```yaml
auth:
  policy:
    mode: enforce
    default_policy: standard_auth
    registry_scripts: []
    attribute_exports: []

    sets:
      networks: {}
      time_windows: {}

    report:
      enabled: false
      include_fsm: true
      include_checks: true
      include_attributes: false

    checks: []
    policies: []
```

| Key | Type | Default | Purpose |
|---|---:|---|---|
| `mode` | string | `enforce` | `enforce` applies selected policies; `observe` compares custom policy output against `standard_auth` without changing production output. |
| `default_policy` | string | `standard_auth` | Built-in default policy set. This is currently the only built-in default-policy name. |
| `registry_scripts` | list of paths | `[]` | Lua scripts that register additional policy attributes during snapshot build. |
| `attribute_exports` | list | `[]` | Opt-in backend/AuthState attributes that become policy-visible subject facts. |
| `sets.networks` | map | `{}` | Named reusable IP/CIDR sets for policy conditions. |
| `sets.time_windows` | map | `{}` | Named local-time windows for policy conditions. |
| `report.enabled` | bool | `false` | Enables optional redacted policy decision reports. This does not affect enforcement, logs, metrics, traces, or client responses. |
| `report.include_fsm` | bool | `true` | Includes FSM decision material in report output. Selected FSM markers are still used internally even when reports are disabled. |
| `report.include_checks` | bool | `true` | Includes check results in report output. Check results still drive policy evaluation when reports are disabled. |
| `report.include_attributes` | bool | `false` | Includes emitted attributes in report output when enabled. Redaction still applies. |
| `checks` | list | `[]` | Explicit fact-producing check plan. |
| `policies` | list | `[]` | Ordered first-match decision rules. |

Policy snapshots are built at startup and on reload. A candidate snapshot is activated only after complete validation succeeds. If a reload fails, the previous active snapshot remains in use.

## Modes

| Mode | Behavior |
|---|---|
| `enforce` | Custom configured policies may become authoritative for supported stages and operations. If no custom rules exist, `standard_auth` is authoritative. |
| `observe` | `standard_auth` remains authoritative. Configured policies are evaluated for diagnostics, reports, logs, metrics, and traces only. Custom side effects do not execute. |

Observe mode is for comparing behavior. It does not change config validation.

## Checks-Only Scheduling

You do not need to write a full custom policy rule set just to control Lua execution. This is valid:

```yaml
auth:
  policy:
    mode: enforce
    default_policy: standard_auth
    checks:
      - name: lua_control_geoip
        type: lua.control
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        config_ref: auth.controls.lua.controls.geoip

      - name: lua_control_policy_gate
        type: lua.control
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        after: [lua_control_geoip]
        config_ref: auth.controls.lua.controls.policy_gate
```

In this shape, the check plan decides which Lua controls run and in which order. `standard_auth` still decides the final result from the emitted facts. Add `auth.policy.policies` only when you want custom decision rules.

For a Lua script family, configured checks own that family's schedule for the active operation and stage. Scripts without a matching check do not run in that request plan. If no checks exist for that script family, Nauthilus uses the built-in default scheduling for that family.

## Backend Attribute Exports

Backends can return arbitrary account attributes. Nauthilus does not expose all of them to policy automatically. This is intentional: LDAP and Lua backend attributes often contain internal fields, tokens, mailbox routing hints, or other values that should not become policy/report material by accident.

Use `auth.policy.attribute_exports` to make selected backend/AuthState attributes available as policy subject facts:

```yaml
auth:
  policy:
    attribute_exports:
      - name: account_status
        attribute: accountStatus
        type: string
        sensitivity: internal

      - name: entitlements
        attribute: entitlements
        type: string_list

      - name: risk_score
        attribute: riskScore
        type: number
```

| Field | Required | Purpose |
|---|---:|---|
| `name` | yes | Policy-safe export name. It becomes the final path segment in `auth.subject.attribute.<name>`. |
| `attribute` | yes | Backend/AuthState attribute name to read from the backend result. |
| `type` | yes | Detail type: `bool`, `string`, `string_list`, or `number`. |
| `sensitivity` | no | Report redaction class: `internal` default, `public`, or `secret`. |

The generated policy attribute is a boolean presence fact:

```yaml
if:
  attribute: auth.subject.attribute.account_status
  is: true
```

The configured value is available as a typed detail:

```yaml
if:
  attribute: auth.subject.attribute.account_status
  detail: value
  eq: locked
```

For `string_list` exports, use the `values` detail:

```yaml
if:
  attribute: auth.subject.attribute.entitlements
  detail: values
  contains: imap
```

Generated details are:

| Detail | Type | Meaning |
|---|---|---|
| `attribute` | string | Original backend/AuthState attribute name. |
| `count` | number | Number of values present in the backend attribute. |
| `value` | bool, string, or number | Typed first value for scalar exports. |
| `values` | string_list | Typed string list for `string_list` exports. |

`name` is normalized like generated bucket and RBL list identifiers: letters and digits are kept, separators collapse to `_`, the segment is lower-cased, and leading digits are prefixed with `b_`. If two exports normalize to the same segment, the policy snapshot is rejected.

## Operations

`operations` structurally selects which request operation a check or policy belongs to. If omitted on a check or policy, it defaults to:

```yaml
operations: [authenticate]
```

An explicitly empty list is invalid.

| Operation | Meaning |
|---|---|
| `authenticate` | Normal password authentication. |
| `lookup_identity` | Identity lookup without password verification, used by HTTP no-auth and gRPC `LookupIdentity`. |
| `list_accounts` | Account-provider listing, used by HTTP list-accounts and gRPC `ListAccounts`. |

Caller authentication, backchannel credentials, gRPC scopes, malformed requests, and transport errors are prerequisites. They are not normal policy denials.

## Stages

| Stage | Purpose |
|---|---|
| `pre_auth` | Brute force, Lua controls, TLS enforcement, relay domains, and RBL before backend auth. |
| `auth_backend` | Backend authentication or identity lookup facts. |
| `auth_filters` | Lua filter facts after backend evaluation. |
| `account_provider` | Account-list provider facts for `list_accounts`. |
| `auth_decision` | Final permit, deny, or temporary failure decision. |

There is no `post_decision` policy stage. Lua post-actions are asynchronous enforcement work requested through obligations after a decision is selected.

## Checks

`auth.policy.checks` defines the explicit fact-producing plan.

```yaml
auth:
  policy:
    checks:
      - name: tls_encryption
        type: builtin.tls_encryption
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        config_ref: auth.controls.tls_encryption
        output: checks.tls_encryption
```

| Field | Required | Purpose |
|---|---:|---|
| `name` | yes | Unique check name used by `after` and `require_checks`. |
| `type` | yes | Check type from the registry. |
| `stage` | yes | Stage where the check emits facts. Must match the check type. |
| `operations` | no | Operation scope. Omitted means `[authenticate]`. |
| `run_if.auth_state` | no | Structural scheduler guard: `any`, `authenticated`, or `unauthenticated`. Omitted means `any`. |
| `after` | no | Check-plan ordering dependencies inside the same operation/stage plan. Dependencies must cover the dependent check's operations and auth-state scheduler guard. |
| `config_ref` | no | Canonical mechanism config path used by the check. |
| `output` | no | Unique output name for reports and internal plan identity. |
| `observe_safe` | no | Allows observe execution only for check types that permit operator assertion. |

### Check-Type Registry

| Type | Stage | Default operations | Config reference |
|---|---|---|---|
| `builtin.brute_force` | `pre_auth` | `authenticate` | `auth.controls.brute_force` |
| `builtin.tls_encryption` | `pre_auth` | `authenticate`, `lookup_identity` | `auth.controls.tls_encryption` |
| `builtin.relay_domains` | `pre_auth` | `authenticate` | `auth.controls.relay_domains` |
| `builtin.rbl` | `pre_auth` | `authenticate`, `lookup_identity` | `auth.controls.rbl` |
| `lua.control` | `pre_auth` | `authenticate` | `auth.controls.lua.controls.<name>` |
| `backend.ldap` | `auth_backend` | `authenticate`, `lookup_identity` | `auth.backends.ldap` |
| `backend.lua` | `auth_backend` | `authenticate`, `lookup_identity` | `auth.backends.lua.backend` |
| `lua.filter` | `auth_filters` | `authenticate` | `auth.controls.lua.filters.<name>` |
| `backend.account_provider` | `account_provider` | `list_accounts` | `auth.backends` |

Lua controls and Lua filters are singular check types. Use one check per named script. Aggregate check types such as `lua.controls` or `lua.filters` are invalid.

## Design Lineage

Nauthilus policy design is inspired by OASIS XACML 3.0 concepts, but it is not an XACML implementation and does not expose XACML XML/JSON request or policy syntax.

The borrowed concepts are:

- a policy-decision layer separated from enforcement code
- policy enforcement points that collect facts and apply the selected decision
- typed subject, resource, action, environment, and system attributes
- explicit effects such as permit, deny, neutral, and temporary failure
- obligations and advice attached to selected decisions
- ordered rule evaluation with deterministic first-match behavior

The Nauthilus-specific parts are the YAML configuration surface, fixed auth operations and stages, built-in check registry, Lua attribute registry, FSM markers, response markers, and the built-in `standard_auth` policy set.

For administrators, the practical takeaway is that Nauthilus uses an XACML-like PDP/PEP split: mechanisms and Lua code produce facts, the policy decision point selects an effect, and enforcement bridges apply the response, FSM marker, obligations, and advice.

## Attribute Categories

Every registered policy attribute has a category. The category is metadata for the policy registry, report readers, and future tooling. It does not change how an `if` condition is written: policy conditions still reference the full attribute ID.

Nauthilus currently uses these categories:

| Category | Meaning in Nauthilus policies | Examples |
|---|---|---|
| `environment` | Request context or external environment around the login attempt. This is where pre-auth controls usually emit facts. | `request.client.ip`, `auth.tls.secure`, `auth.brute_force.triggered`, `auth.rbl.score`, `auth.relay_domain.rejected` |
| `subject` | Facts about the authenticating identity or account after backend lookup/authentication. | `auth.authenticated`, `auth.identity.found`, configured `auth.subject.attribute.<name>` exports, Lua billing/account facts |
| `resource` | Facts about a requested resource or a resource-producing operation. | `auth.account_provider.completed` for account-list responses |
| `action` | Facts about the requested action. Nauthilus currently models the main action through `request.operation` instead of many separate action attributes. |
| `system` | Implementation or system-level facts. This is reserved for future registry/tooling use; built-in policy decisions currently do not require user-authored `system` attributes. |

Two names often look abstract at first:

- `subject` means "the user/account side of the request". Backend attributes are not exported automatically because they may contain secrets or directory-internal values. Use `auth.policy.attribute_exports` when a backend field should become policy material.
- `environment` means "facts around the request". This includes network, time, TLS, RBL, relay-domain, brute-force, and Lua risk signals. It does not mean operating-system environment variables.

## Request Attributes

Policies do not read the Lua `request` table or Go request structs directly. They can only use registered policy attributes. Some attributes happen to describe the current request and use the `request.*` prefix, but they are a stable policy surface, not a 1:1 copy of fields available to Lua features, filters, actions, or backends.

Built-in request attributes are:

| Attribute | Type | Operations | Meaning |
|---|---|---|---|
| `request.operation` | string | all | Active operation: `authenticate`, `lookup_identity`, or `list_accounts`. |
| `request.time.now` | datetime | all | Request evaluation timestamp. |
| `request.client.ip` | ip | all | Effective client IP after Nauthilus request-header/proxy handling. |
| `request.protocol` | string | all | Effective authentication protocol, such as `imap`, `smtp`, `submission`, `http`, or IdP-related protocol names. |

Use the policy attribute ID, not Lua field names. For example, Lua commonly uses `request.client_ip`, but YAML policies use `request.client.ip`:

```yaml
if:
  attribute: request.client.ip
  cidr_contains: "@network.trusted_clients"
```

Hostname-style request fields such as the Lua `request.client_host` value are not built-in policy attributes today. If a feature, filter, or backend needs such a value in policy decisions, expose it deliberately: register a Lua-owned policy attribute with `auth.policy.registry_scripts` and emit it with the Lua policy module, or export a selected backend result field with `auth.policy.attribute_exports`.

### Lua Check Scheduling

| Goal | Policy expression |
|---|---|
| Run a check for normal password authentication | Omit `operations` or set `operations: [authenticate]`. |
| Run a check for identity lookup | Add `lookup_identity` to `operations`. |
| Run a check only after backend authentication succeeded | Use `run_if.auth_state: authenticated`. |
| Run a check only before or after failed authentication | Use `run_if.auth_state: unauthenticated`. |
| Run a check regardless of authentication state | Omit `run_if` or set `run_if.auth_state: any`. |
| Start one check after another check | Add `after: [check_name]` on the dependent check. |
| Make a policy rule depend on a check result | Add the check name to `require_checks`. |

Example:

```yaml
auth:
  controls:
    lua:
      controls:
        - name: geoip
          script_path: /etc/nauthilus/lua/controls/geoip.lua
        - name: policy_gate
          script_path: /etc/nauthilus/lua/controls/policy_gate.lua

  policy:
    checks:
      - name: lua_control_geoip
        type: lua.control
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        config_ref: auth.controls.lua.controls.geoip
        output: checks.lua_control_geoip

      - name: lua_control_policy_gate
        type: lua.control
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        after: [lua_control_geoip]
        config_ref: auth.controls.lua.controls.policy_gate
        output: checks.lua_control_policy_gate
```

## Policies

`auth.policy.policies` is an ordered first-match rule list.

```yaml
auth:
  policy:
    policies:
      - name: deny_no_tls
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        require_checks: [tls_encryption]
        if:
          attribute: auth.tls.secure
          is: false
        then:
          decision: tempfail
          reason: no_tls
          response_marker: auth.response.tempfail.no_tls
```

| Field | Required | Purpose |
|---|---:|---|
| `name` | yes | Stable rule name for reports, logs, and metrics. |
| `stage` | yes | Stage where the rule is evaluated. |
| `operations` | no | Operation scope. Omitted means `[authenticate]`. |
| `require_checks` | no | Checks that must have produced `ok` or `error` results for this rule to be applicable. |
| `if` | yes | Structured condition tree. |
| `then` | yes | Decision and optional enforcement outputs. |

Rules are evaluated in YAML order within the active operation/stage plan. A matching terminal decision stops evaluation for that stage.

`neutral` is not `permit`. A neutral pre-auth result allows the request to continue. Final auth decisions are deny-biased: if no `auth_decision` rule permits, the operation is denied.

## Conditions

Conditions are YAML objects. Free-form expression strings are not supported.

### Condition Nodes

| Node | Shape |
|---|---|
| Attribute comparison | `attribute`, optional `detail`, exactly one operator |
| `all` | list of child condition objects; all must match |
| `any` | list of child condition objects; at least one must match |
| `not` | one child condition object |
| `always` | `always: true` |

Condition trees are recursive. A child below `all`, `any`, or `not` may be an attribute comparison, `always`, or another `all`, `any`, or `not` node. Each condition object must still contain exactly one expression node: one of `attribute`, `all`, `any`, `not`, or `always`.

Attribute comparisons are leaf nodes. They must contain exactly one operator such as `is`, `eq`, `ne`, `gte`, `contains`, or `within_time_window`. Operators are not nested, and two operators cannot be placed on the same attribute comparison. To combine multiple comparisons, put them into `all`, `any`, or `not`.

The `then` block is not recursive. A policy rule has one `if` tree and one `then` output block. For else-style behavior or different outcomes, write separate ordered policies.

Examples:

```yaml
if:
  attribute: auth.brute_force.triggered
  is: true
```

```yaml
if:
  all:
    - attribute: auth.relay_domain.present
      is: true
    - attribute: auth.relay_domain.known
      is: false
```

```yaml
if:
  not:
    attribute: request.time.now
    within_time_window: "@time_window.business_hours"
```

```yaml
if:
  all:
    - any:
        - attribute: auth.rbl.threshold_reached
          is: true
        - attribute: auth.brute_force.triggered
          is: true
    - not:
        any:
          - attribute: auth.rbl.soft_allowlisted
            is: true
          - attribute: auth.relay_domain.soft_allowlisted
            is: true
```

### Operators

| Operator | Valid for | Purpose |
|---|---|---|
| `is` | bool and exact scalar checks | Short exact comparison. |
| `eq` | scalar or exact list | Exact equality. |
| `ne` | scalar or exact list | Exact inequality. |
| `in` | scalar attribute | Attribute value is in the configured list. |
| `not_in` | scalar attribute | Attribute value is not in the configured list. |
| `matches` | string | Go RE2 regular expression match. |
| `exists` | any attribute/detail | Presence test with boolean operand. |
| `contains` | string-list attribute | List contains one string. |
| `contains_any` | string-list attribute | List contains at least one configured string. |
| `contains_all` | string-list attribute | List contains all configured strings. |
| `contains_none` | string-list attribute | List contains none of the configured strings. |
| `gt`, `gte`, `lt`, `lte` | number or datetime | Comparable comparisons. |
| `cidr_contains` | IP or CIDR | CIDR/IP containment or network-set match. |
| `within_time_window` | datetime | Time-window-set membership. |

Missing attributes are not equal to `false`, an empty string, zero, or an empty list. Use `exists` when presence is part of the decision.

## Sets

Network and time-window sets are reusable operands for conditions.

```yaml
auth:
  policy:
    sets:
      networks:
        trusted_clients:
          - 10.0.0.0/8
          - 192.168.0.0/16
          - 2001:db8::/32

      time_windows:
        business_hours:
          timezone: Europe/Berlin
          days: [mon, tue, wed, thu, fri]
          intervals:
            - start: "08:00"
              end: "18:00"
```

Use them from conditions:

```yaml
if:
  attribute: request.client.ip
  cidr_contains: "@network.trusted_clients"
```

```yaml
if:
  attribute: request.time.now
  within_time_window: "@time_window.business_hours"
```

Set names must use lowercase letters, digits, and underscores. Time-window intervals use `HH:MM` and must not cross midnight; split cross-midnight windows into two intervals.

## Decision Outputs

The `then` block is the consequence block of a policy rule. The `if` tree decides whether the rule matches; `then` says what Nauthilus should do with that match.

`then` is not another condition tree and it does not contain `else` branches. For different outcomes, write multiple ordered policies. The first matching terminal rule for a stage wins according to the policy combining rules.

The `then` block always needs `decision`.

```yaml
then:
  decision: deny
  reason: billing_locked
  response_marker: auth.response.fail
```

At snapshot-build time, Nauthilus compiles `then` into a typed decision plan:

- `decision` becomes the transport-independent effect.
- `fsm_event_marker` and `response_marker` are derived from stage and `decision` when the normal mapping is unambiguous.
- `response_message`, `obligations`, and `advice` are validated against the registries.
- invalid stage/effect combinations are rejected, for example `decision: permit` in `pre_auth`.

| Field | Purpose |
|---|---|
| `decision` | Required effect: `neutral`, `deny`, `permit`, or `tempfail`. `permit` is not allowed in `pre_auth`. |
| `reason` | Optional internal reason for logs, reports, metrics, obligations, advice, and operator diagnosis. It is not a client-visible message by itself. |
| `outcome_marker` | Optional stable outcome label for reports and tooling. Built-in `standard_auth` uses stable outcome markers; custom policies may set their own. |
| `fsm_event_marker` | Optional target FSM event marker. If omitted, Nauthilus derives the normal marker from stage and decision. |
| `response_marker` | Optional response class. If omitted, Nauthilus derives the normal class from the decision when possible. |
| `response_message` | Optional final client-visible message selection inside the selected response class. |
| `obligations` | Mandatory registered enforcement work to execute with the selected decision. |
| `advice` | Non-binding registered context that may be used for reporting, logging, or follow-up context. |
| `control.skip_remaining_stage_checks` | Stage-local control for neutral `pre_auth` decisions that should stop later checks without denying the request. |

### Decision Effects

`decision` is the central `then` output.

| Decision | `pre_auth` behavior | `auth_decision` behavior |
|---|---|---|
| `neutral` | Continue the request unless `control.skip_remaining_stage_checks` stops later checks in the stage. | Non-terminal. Evaluation continues; final enforcement denies if no later rule permits. |
| `deny` | Stop before backend evaluation and fail the operation. | Fail the active operation. |
| `permit` | Invalid. Pre-auth cannot grant final success. | Permit the active operation. |
| `tempfail` | Stop before backend evaluation with a temporary failure. | Temporary failure for the active operation. |

`neutral` is deliberately not `permit`. It means "this rule did not choose a terminal security result".

### Reason and Outcome Marker

Use `reason` for stable internal diagnosis:

```yaml
then:
  decision: deny
  reason: relay_domain_rejected
```

`reason` can appear in logs, reports, traces, counters, and POST-Action context. It must not contain secrets or user-specific free text. It does not override the client-visible response.

Use `outcome_marker` when you need a stable, namespaced outcome label for tooling or reports:

```yaml
then:
  decision: deny
  reason: brute_force_reject
  outcome_marker: auth.outcome.brute_force_reject
```

If you do not have a reporting/tooling need for a custom marker, leave `outcome_marker` unset.

### Response Marker and Message

`response_marker` selects the transport-independent response class. It is validated against the selected `decision`; for example `auth.response.ok` is compatible with `permit`, not with `deny`.

If omitted, Nauthilus derives the normal response marker:

| Decision | Derived response marker |
|---|---|
| `permit` | `auth.response.ok` |
| `deny` | `auth.response.fail` |
| `tempfail` | `auth.response.tempfail` |
| `neutral` | none |

Use an explicit marker for specialized classes:

```yaml
then:
  decision: tempfail
  reason: no_tls
  response_marker: auth.response.tempfail.no_tls
```

`response_message` can override only the message inside the selected response class. It does not change HTTP status codes, gRPC status codes, redirect behavior, OIDC/SAML semantics, or the FSM state.

Supported message sources:

| Source | Required fields | Meaning |
|---|---|---|
| omitted or `from: default` | none | Use the default message of `response_marker`. |
| `from: literal` | `text` | Use a static policy-configured message. |
| `from: attribute_detail` | `attribute`, `detail`, optional `fallback` | Use a public string detail from a registered policy attribute. |

Literal message:

```yaml
then:
  decision: deny
  response_marker: auth.response.fail
  response_message:
    from: literal
    text: "Account temporarily locked"
```

Lua-provided public detail:

```yaml
then:
  decision: deny
  response_marker: auth.response.fail
  response_message:
    from: attribute_detail
    attribute: auth.lua.filter.billing_lock.rejected
    detail: status_message
    fallback: "Invalid login or password"
```

For `attribute_detail`, the referenced detail must be a registered string detail with `sensitivity: public` and `purpose: response_message`. If the detail is absent or empty at runtime, Nauthilus uses `fallback`; if no fallback is configured, it uses the response-marker default.

### Obligations, Advice, and Control

`obligations` request registered enforcement work. They are mandatory for the selected decision and are not arbitrary Lua extension points.

Registered obligations:

| ID | What it does |
|---|---|
| `auth.obligation.brute_force.update` | Updates brute-force counters, toleration, and learning state. |
| `auth.obligation.lua_post_action.enqueue` | Enqueues an existing Lua POST-Action after the request-time decision is known. |

Example:

```yaml
then:
  decision: deny
  obligations:
    - id: auth.obligation.brute_force.update
    - id: auth.obligation.lua_post_action.enqueue
      args:
        action: brute_force
```

`advice` is non-binding context. It may be used for reports, logging, or follow-up context, but failing or ignoring advice must not change the selected decision or response.

Registered advice:

| ID | What it does |
|---|---|
| `auth.advice.audit_reason` | Carries sanitized audit context. |

Example:

```yaml
then:
  decision: deny
  advice:
    - id: auth.advice.audit_reason
      args:
        reason: blocked_country
```

`control.skip_remaining_stage_checks` is a narrow stage-local control. It is useful for neutral pre-auth rules that should stop later pre-auth checks without granting success:

```yaml
then:
  decision: neutral
  reason: pre_auth_check_aborted
  control:
    skip_remaining_stage_checks: true
```

This control does not skip final `auth_decision`. It only stops remaining checks in the current stage.

### Lua Actions and POST-Actions

Nauthilus has two Lua side-effect surfaces with similar names but different policy semantics.

| Surface | Config action type | Runtime timing | Policy relationship |
|---|---|---|---|
| Synchronous Lua actions | `brute_force`, `lua`, `tls_encryption`, `relay_domains`, `rbl` in `auth.controls.lua.actions` | Dispatched by the mechanism that triggered them and waited for before the request continues. | Current compatibility behavior. They are not policy checks, obligations, or advice in the current implementation. |
| Lua POST-Actions | `post` in `auth.controls.lua.actions` | Enqueued after the request-time decision context is known. | Policy-owned in policy-authoritative paths through `auth.obligation.lua_post_action.enqueue`. |

Synchronous Lua actions are still started automatically by the corresponding mechanism. For example:

- a triggered Lua control can dispatch the `lua` action;
- TLS enforcement can dispatch the `tls_encryption` action;
- relay-domain rejection can dispatch the `relay_domains` action;
- an RBL hit can dispatch the `rbl` action;
- brute-force detection can dispatch the `brute_force` action.

This is compatibility behavior from the first policy-layer rollout, not the clean long-term policy ownership model. A synchronous action can run because a mechanism observed a trigger before the final YAML policy decision has owned the side effect. That preserves existing deployments, but it is less explicit than policy-owned enforcement work.

For new policy-driven side effects, prefer registered obligations. A stricter future model should expose synchronous action dispatch as a registered obligation and attach it to selected policy decisions, so reports, observe mode, and side effects all describe the same decision path. `advice` should not execute actions.

Brute force has both mechanism-owned and policy-owned side effects:

| Side effect | Current owner |
|---|---|
| Synchronous `brute_force` Lua action | Brute-force evaluator. |
| Brute-force counter, toleration, and learning update | `auth.obligation.brute_force.update` when policy enforcement owns the decision; legacy fallback otherwise. |
| Lua POST-Action after a brute-force denial | `auth.obligation.lua_post_action.enqueue` when policy enforcement owns the decision; legacy fallback otherwise. |

The built-in `standard_auth` policy attaches both obligations to the `standard_brute_force_deny` decision:

```yaml
then:
  decision: deny
  reason: brute_force_reject
  response_marker: auth.response.fail
  obligations:
    - id: auth.obligation.brute_force.update
    - id: auth.obligation.lua_post_action.enqueue
      args:
        action: brute_force
```

For custom policies, add these obligations explicitly when you want the same policy-owned side effects. Without them, a custom terminal policy decision can deny or tempfail without scheduling the POST-Action or updating brute-force counters through the policy obligation path.

There is no `post_decision` policy stage. POST-Actions are enforcement follow-up work requested by obligations after a decision has been selected. A POST-Action must not change the already selected `decision`, FSM terminal state, `response_marker`, or `response_message`.

In `mode: observe`, custom obligations are diagnostic only: custom POST-Action enqueueing, brute-force updates, learning updates, and other mutable side effects are not executed.

### FSM Event Markers

FSM means finite-state machine. In Nauthilus it is the deterministic request-state tracker that records how an auth request moved through parsing, pre-auth checks, backend or account-provider evaluation, and the final decision.

In policy terms, three outputs have different jobs:

| Output | Answers | Example |
|---|---|---|
| `decision` | What did this rule decide? | `deny`, `permit`, `tempfail`, `neutral` |
| `fsm_event_marker` | Which auth-FSM event should record and enforce that path? | `auth.fsm.event.pre_auth_deny` |
| `response_marker` | Which transport response profile should be rendered? | `auth.response.fail` |

The FSM is not a second policy language and is not admin-editable. Policies reference registered event markers; Nauthilus applies those events to the internal FSM and reaches terminal states such as `auth_ok`, `auth_fail`, `auth_tempfail`, or `aborted`. Those terminal state names are not valid `fsm_event_marker` values.

Most rules should omit `fsm_event_marker`. The compiler derives the normal marker from the policy stage and decision, then validates any explicit marker against the same registry.

| Stage | Decision | Derived FSM event marker | Resulting meaning |
|---|---|---|---|
| `pre_auth` | `neutral` | `auth.fsm.event.pre_auth_ok` | Continue after pre-auth. This is not a successful login. |
| `pre_auth` | `deny` | `auth.fsm.event.pre_auth_deny` | Stop before backend auth and terminate as `auth_fail`. |
| `pre_auth` | `tempfail` | `auth.fsm.event.pre_auth_tempfail` | Stop before backend auth and terminate as `auth_tempfail`. |
| `pre_auth` | `permit` | not allowed | Pre-auth cannot grant final authentication success. |
| `auth_decision` | `permit` | `auth.fsm.event.auth_permit` | Terminal success for the active operation. |
| `auth_decision` | `deny` | `auth.fsm.event.auth_deny` | Terminal denial for the active operation. |
| `auth_decision` | `tempfail` | `auth.fsm.event.auth_tempfail` | Terminal temporary failure for the active operation. |
| `auth_decision` | `neutral` | none | Evaluation continues; if no later rule permits the request, final enforcement denies. |

Explicit FSM markers are useful when a custom policy needs a more specific built-in terminal path, for example empty-user, empty-password, or a deliberate pre-auth abort. They are also useful when reports, logs, metrics, and enforcement traces must distinguish two rules that share the same high-level decision.

Operator policies may reference policy-visible target markers only:

| Marker | Valid stage | Use for |
|---|---|---|
| `auth.fsm.event.pre_auth_ok` | `pre_auth` | Continue after pre-auth. |
| `auth.fsm.event.pre_auth_deny` | `pre_auth` | Denial before backend auth. |
| `auth.fsm.event.pre_auth_tempfail` | `pre_auth` | Temporary failure before backend auth. |
| `auth.fsm.event.pre_auth_abort` | `pre_auth` | Abort pre-auth processing. |
| `auth.fsm.event.auth_permit` | `auth_decision` | Final permit for the active operation. |
| `auth.fsm.event.auth_deny` | `auth_decision` | Final deny for the active operation. |
| `auth.fsm.event.auth_tempfail` | `auth_decision` | Final temporary failure for the active operation. |
| `auth.fsm.event.auth_empty_user` | `auth_decision` | Empty username behavior; normally paired with `decision: tempfail`. |
| `auth.fsm.event.auth_empty_pass` | `auth_decision` | Empty password behavior; normally paired with `decision: deny`. |

The final `auth_permit`, `auth_deny`, and `auth_tempfail` markers are operation-terminal events. For `authenticate` they describe password authentication. For `lookup_identity` they describe identity lookup. For `list_accounts` they describe account-listing completion or denial.

Internal parser, stage-orchestration, caller-auth, and runtime abort markers are produced by Nauthilus itself and are not policy-visible. Examples include `auth.fsm.event.parse_ok`, `auth.fsm.event.auth_evaluated`, `auth.fsm.event.account_provider_evaluated`, `auth.fsm.event.basic_auth_ok`, and `auth.fsm.event.abort`.

Normal rule with derived FSM marker:

```yaml
then:
  decision: deny
  reason: billing_locked
  response_marker: auth.response.fail
```

In `pre_auth`, this derives `auth.fsm.event.pre_auth_deny`. In `auth_decision`, it derives `auth.fsm.event.auth_deny`.

Advanced rule with an explicit empty-password path:

```yaml
then:
  decision: deny
  reason: empty_password
  fsm_event_marker: auth.fsm.event.auth_empty_pass
  response_marker: auth.response.fail
```

### Response Marker Registry

| Marker | Decision | Purpose |
|---|---|---|
| `auth.response.ok` | `permit` | Successful auth or lookup response. |
| `auth.response.fail` | `deny` | Authentication, lookup, or account-list denial. |
| `auth.response.tempfail` | `tempfail` | Temporary failure. |
| `auth.response.tempfail.no_tls` | `tempfail` | TLS-required temporary failure. |
| `auth.response.list_accounts.ok` | `permit` | Successful `list_accounts` response. |

Policies select response markers, not raw HTTP status codes, headers, gRPC status codes, OIDC protocol fields, or SAML protocol fields.

### Response Message Reminder

If `response_message` is omitted or `from: default`, Nauthilus uses the default message from the response marker. `attribute_detail` is valid only for a registered string detail with `sensitivity: public` and `purpose: response_message`. Generated Lua control and Lua filter decision attributes expose `status_message` this way.

### Obligation and Advice Registry

| ID | Kind | Purpose |
|---|---|---|
| `auth.obligation.brute_force.update` | obligation | Update brute-force counters, toleration, and learning state. |
| `auth.obligation.lua_post_action.enqueue` | obligation | Enqueue an existing Lua post-action after decision selection. |
| `auth.advice.audit_reason` | advice | Add sanitized audit context. |

Policy YAML references registered IDs. It cannot define executable obligation logic.

## Built-In Attributes

The built-in registry includes at least these attributes.

| Attribute | Stage | Operations | Type | Details |
|---|---|---|---|---|
| `request.operation` | `pre_auth` | all | string | none |
| `request.time.now` | `pre_auth` | all | datetime | none |
| `request.client.ip` | `pre_auth` | all | ip | none |
| `request.protocol` | `pre_auth` | all | string | none |
| `auth.brute_force.triggered` | `pre_auth` | `authenticate` | bool | `rule`, `bucket_id`, `client_net`, `repeating`, `rwp_active`, `bucket_count`, `bucket_ratio`, `effective_limit` |
| `auth.brute_force.repeating` | `pre_auth` | `authenticate` | bool | selected bucket summary |
| `auth.brute_force.rwp.active` | `pre_auth` | `authenticate` | bool | selected bucket summary |
| `auth.brute_force.rwp.enforce_bucket_update` | `pre_auth` | `authenticate` | bool | selected bucket summary |
| `auth.brute_force.toleration.active` | `pre_auth` | `authenticate` | bool | toleration summary |
| `auth.brute_force.toleration.mode` | `pre_auth` | `authenticate` | string | `static`, `adaptive`, or `disabled` |
| `auth.brute_force.toleration.custom` | `pre_auth` | `authenticate` | bool | toleration summary |
| `auth.brute_force.toleration.positive` | `pre_auth` | `authenticate` | number | toleration summary |
| `auth.brute_force.toleration.negative` | `pre_auth` | `authenticate` | number | toleration summary |
| `auth.brute_force.toleration.max_negative` | `pre_auth` | `authenticate` | number | toleration summary |
| `auth.brute_force.toleration.percent` | `pre_auth` | `authenticate` | number | toleration summary |
| `auth.brute_force.toleration.ttl_seconds` | `pre_auth` | `authenticate` | number | toleration summary |
| `auth.brute_force.toleration.suppressed_block` | `pre_auth` | `authenticate` | bool | toleration summary |
| `auth.brute_force.bucket.matched_count` | `pre_auth` | `authenticate` | number | selected bucket summary |
| `auth.brute_force.bucket.triggered_count` | `pre_auth` | `authenticate` | number | selected bucket summary |
| `auth.brute_force.bucket.max_count` | `pre_auth` | `authenticate` | number | selected bucket summary |
| `auth.brute_force.bucket.max_ratio` | `pre_auth` | `authenticate` | number | selected bucket summary |
| `auth.brute_force.error` | `pre_auth` | `authenticate` | bool | `reason_code`, `retryable` |
| `auth.tls.secure` | `pre_auth` | `authenticate`, `lookup_identity` | bool | none |
| `auth.relay_domain.present` | `pre_auth` | `authenticate` | bool | relay-domain details |
| `auth.relay_domain.known` | `pre_auth` | `authenticate` | bool | relay-domain details |
| `auth.relay_domain.value` | `pre_auth` | `authenticate` | string | relay-domain details |
| `auth.relay_domain.rejected` | `pre_auth` | `authenticate` | bool | relay-domain details |
| `auth.relay_domain.static_match` | `pre_auth` | `authenticate` | bool | relay-domain details |
| `auth.relay_domain.soft_allowlisted` | `pre_auth` | `authenticate` | bool | relay-domain details |
| `auth.relay_domain.configured_count` | `pre_auth` | `authenticate` | number | relay-domain details |
| `auth.relay_domain.error` | `pre_auth` | `authenticate` | bool | `reason_code`, `retryable` |
| `auth.rbl.threshold_reached` | `pre_auth` | `authenticate`, `lookup_identity` | bool | RBL summary |
| `auth.rbl.score` | `pre_auth` | `authenticate`, `lookup_identity` | number | RBL summary |
| `auth.rbl.threshold` | `pre_auth` | `authenticate`, `lookup_identity` | number | RBL summary |
| `auth.rbl.matched_count` | `pre_auth` | `authenticate`, `lookup_identity` | number | RBL summary |
| `auth.rbl.matched_lists` | `pre_auth` | `authenticate`, `lookup_identity` | string_list | RBL summary |
| `auth.rbl.list_count` | `pre_auth` | `authenticate`, `lookup_identity` | number | RBL summary |
| `auth.rbl.allow_failure_error_count` | `pre_auth` | `authenticate`, `lookup_identity` | number | RBL summary |
| `auth.rbl.effective_error` | `pre_auth` | `authenticate`, `lookup_identity` | bool | RBL summary |
| `auth.rbl.soft_allowlisted` | `pre_auth` | `authenticate`, `lookup_identity` | bool | RBL summary |
| `auth.rbl.ip_allowlisted` | `pre_auth` | `authenticate`, `lookup_identity` | bool | RBL summary |
| `auth.rbl.error` | `pre_auth` | `authenticate`, `lookup_identity` | bool | `reason_code`, `retryable` |
| `auth.authenticated` | `auth_backend` | `authenticate` | bool | `backend` |
| `auth.identity.found` | `auth_backend` | `lookup_identity` | bool | `backend` |
| `auth.backend.tempfail` | `auth_backend` | `authenticate`, `lookup_identity` | bool | `backend`, `reason_code`, `retryable` |
| `auth.backend.empty_username` | `auth_backend` | `authenticate`, `lookup_identity` | bool | none |
| `auth.backend.empty_password` | `auth_backend` | `authenticate` | bool | none |
| `auth.account_provider.completed` | `account_provider` | `list_accounts` | bool | `count` |
| `auth.account_provider.tempfail` | `account_provider` | `list_accounts` | bool | `reason_code`, `retryable` |

For each configured brute-force bucket, Nauthilus also registers per-bucket attributes:

| Pattern | Type | Meaning |
|---|---|---|
| `auth.brute_force.bucket.<bucket>.matched` | bool | The bucket matched the current protocol, OIDC client, IP family, and network context. |
| `auth.brute_force.bucket.<bucket>.count` | number | Current read-only sliding-window counter value. |
| `auth.brute_force.bucket.<bucket>.limit` | number | Configured `failed_requests` value. |
| `auth.brute_force.bucket.<bucket>.effective_limit` | number | Effective Redis-side limit after adaptive toleration. |
| `auth.brute_force.bucket.<bucket>.remaining` | number | Remaining attempts until the effective limit is exceeded. |
| `auth.brute_force.bucket.<bucket>.ratio` | number | `count / effective_limit`; useful with `gt`, `gte`, `lt`, and `lte`. |
| `auth.brute_force.bucket.<bucket>.over_limit` | bool | The bucket is currently over the effective limit. |
| `auth.brute_force.bucket.<bucket>.already_banned` | bool | A ban/repeating state already exists for this bucket. |
| `auth.brute_force.bucket.<bucket>.repeating` | bool | The bucket is either over limit or already banned. |

The `<bucket>` segment is derived from `auth.controls.brute_force.buckets[].name`. It is lower-cased and normalized to an ASCII identifier segment: letters, digits, and `_` are kept, other separators collapse to `_`, and leading digits are prefixed with `b_`. For example, `IMAP Short` becomes `imap_short`, and `24h` becomes `b_24h`. If two configured bucket names normalize to the same identifier, policy snapshot compilation fails.

Per-bucket attributes carry internal details: `rule`, `bucket_id`, `client_net`, `matched`, `over_limit`, `already_banned`, `repeating`, `limit`, `effective_limit`, `remaining`, `ratio`, `period_seconds`, `ban_time_seconds`, and `cidr`.

Brute-force toleration attributes describe the reputation decision that may suppress a block after a bucket is over limit:

| Attribute | Meaning |
|---|---|
| `auth.brute_force.toleration.active` | The current client IP is tolerated by the reputation calculation. |
| `auth.brute_force.toleration.mode` | `static`, `adaptive`, or `disabled`. |
| `auth.brute_force.toleration.custom` | A custom toleration entry matched the client IP. |
| `auth.brute_force.toleration.positive` | Positive reputation counter. |
| `auth.brute_force.toleration.negative` | Negative reputation counter. |
| `auth.brute_force.toleration.max_negative` | Maximum tolerated negative counter. |
| `auth.brute_force.toleration.percent` | Effective tolerated percentage. |
| `auth.brute_force.toleration.ttl_seconds` | Effective reputation TTL in seconds. |
| `auth.brute_force.toleration.suppressed_block` | Toleration suppressed a block that would otherwise have been applied. |

Relay-domain attributes carry internal details: `domain`, `matched_domain`, `configured_count`, `present`, `known`, `rejected`, `static_match`, and `soft_allowlisted`.

RBL summary attributes carry internal details: `lists`, `score`, `threshold`, `matched_count`, `list_count`, `allow_failure_error_count`, `effective_error`, `soft_allowlisted`, and `ip_allowlisted`.

For each configured RBL list, Nauthilus also registers per-list attributes:

| Pattern | Type | Meaning |
|---|---|---|
| `auth.rbl.list.<list>.listed` | bool | The client IP matched this RBL list. |
| `auth.rbl.list.<list>.weight` | number | Configured weight for this RBL list. |
| `auth.rbl.list.<list>.error` | bool | Lookup for this list ended with a technical error. |
| `auth.rbl.list.<list>.allow_failure` | bool | The list is configured with `allow_failure`. |

The `<list>` segment is derived from `auth.controls.rbl.lists[].name` with the same identifier normalization used for brute-force buckets. If two RBL list names normalize to the same identifier, policy snapshot compilation fails.

Per-list RBL attributes carry internal details: `list`, `list_id`, `host`, `query`, `return_code`, `reason_code`, `ip_family`, `listed`, `error`, `allow_failure`, and `weight`.

For each configured Lua control check, Nauthilus also registers:

- `auth.lua.control.<name>.triggered`
- `auth.lua.control.<name>.abort`
- `auth.lua.control.<name>.error`

For each configured Lua filter check, Nauthilus also registers:

- `auth.lua.filter.<name>.rejected`
- `auth.lua.filter.<name>.error`

Lua trigger/reject attributes include an optional public `status_message` detail that policies can select as a response message.

## Lua Attribute Registry Scripts

Use `registry_scripts` when request-time Lua needs to emit custom policy attributes.

```yaml
auth:
  policy:
    registry_scripts:
      - /etc/nauthilus/policy/attributes.lua
```

Example registry script:

```lua
nauthilus_policy.register_attribute({
  id = "lua.billing.account_locked",
  stage = "auth_filters",
  operations = { "authenticate" },
  category = "subject",
  type = "bool",
  description = "The account is locked by the billing system",
  details = {
    reason = {
      type = "string",
      sensitivity = "internal",
    },
    status_message = {
      type = "string",
      sensitivity = "public",
      purpose = "response_message",
      max_length = 256,
    },
  },
})
```

If `operations` is omitted in a Lua registry script, it defaults to `authenticate`. An explicitly empty operation table is invalid.

Request-time Lua can emit only attributes that exist in the active snapshot registry. It cannot register attributes during a request.

## Appendix: Complete `standard_auth` Policy

`standard_auth` is the built-in default policy set. The table below is verified against the current `server/policy/evaluation/standard.go` implementation and the policy constants in `server/policy/types.go`.

Selection is ordered and first-match. Pre-auth rules run first for `authenticate` and `lookup_identity`. If a pre-auth rule selects `deny` or `tempfail`, evaluation stops before final auth-decision rules. `list_accounts` skips pre-auth and starts at the account-provider decision rules.

Rules with `requires` need the named check result to be present with status `ok` or `error`. Dynamic Lua rules are generated per emitted Lua check result.

### Pre-Auth Rules

| Order | Rule name | Operations | Requires | Condition | Effect | FSM marker | Response marker | Extra |
|---:|---|---|---|---|---|---|---|---|
| 10 | `standard_brute_force_error_tempfail` | `authenticate` | `brute_force` | `auth.brute_force.error == true` | `tempfail` | `auth.fsm.event.pre_auth_tempfail` | `auth.response.tempfail` |  |
| 20 | `standard_brute_force_deny` | `authenticate` | `brute_force` | `auth.brute_force.triggered == true` | `deny` | `auth.fsm.event.pre_auth_deny` | `auth.response.fail` | Obligations: `auth.obligation.brute_force.update`, `auth.obligation.lua_post_action.enqueue` with `action: brute_force`. |
| 30 | `standard_tls_enforcement` | `authenticate`, `lookup_identity` | `tls_encryption` | `auth.tls.secure == false` | `tempfail` | `auth.fsm.event.pre_auth_tempfail` | `auth.response.tempfail.no_tls` |  |
| 40 | `standard_relay_domain_error_tempfail` | `authenticate` | `relay_domains` | `auth.relay_domain.error == true` | `tempfail` | `auth.fsm.event.pre_auth_tempfail` | `auth.response.tempfail` |  |
| 50 | `standard_relay_domain_reject` | `authenticate` | `relay_domains` | `auth.relay_domain.present == true` and `auth.relay_domain.known == false` | `deny` | `auth.fsm.event.pre_auth_deny` | `auth.response.fail` |  |
| 60 | `standard_rbl_error_tempfail` | `authenticate`, `lookup_identity` | `rbl` | `auth.rbl.error == true` | `tempfail` | `auth.fsm.event.pre_auth_tempfail` | `auth.response.tempfail` |  |
| 70 | `standard_rbl_reject` | `authenticate`, `lookup_identity` | `rbl` | `auth.rbl.threshold_reached == true` | `deny` | `auth.fsm.event.pre_auth_deny` | `auth.response.fail` |  |
| 80 | `standard_lua_control_<script>_error` | active operation: `authenticate` or `lookup_identity` | emitted Lua control check | `auth.lua.control.<script>.error == true` | `tempfail` | `auth.fsm.event.pre_auth_tempfail` | `auth.response.tempfail` | Generated once per Lua control check result. |
| 90 | `standard_lua_control_<script>_trigger` | active operation: `authenticate` or `lookup_identity` | emitted Lua control check | `auth.lua.control.<script>.triggered == true` | `deny` | `auth.fsm.event.pre_auth_deny` | `auth.response.fail` | Uses public `status_message` detail from `auth.lua.control.<script>.triggered` when selected. |
| 100 | `standard_lua_control_<script>_abort` | active operation: `authenticate` or `lookup_identity` | emitted Lua control check | `auth.lua.control.<script>.abort == true` | `neutral` | `auth.fsm.event.pre_auth_ok` | none | Sets `control.skip_remaining_stage_checks: true`. |
| 110 | `implicit_pre_auth_pass` | `authenticate`, `lookup_identity` | none | no pre-auth terminal or abort rule matched | `neutral` | `auth.fsm.event.pre_auth_ok` | none | Internal pass decision added by `standard_auth`. |

The `<script>` placeholder is derived from emitted Lua attributes such as `auth.lua.control.geoip.triggered`. This keeps hand-written check names valid as long as the check points to the named Lua script through `config_ref`.

### Final Auth-Decision Rules

| Order | Rule name | Operations | Requires | Condition | Effect | FSM marker | Response marker | Extra |
|---:|---|---|---|---|---|---|---|---|
| 200 | `standard_backend_tempfail` | `authenticate`, `lookup_identity` | none | `auth.backend.tempfail == true` | `tempfail` | `auth.fsm.event.auth_tempfail` | `auth.response.tempfail` |  |
| 210 | `standard_empty_username` | `authenticate`, `lookup_identity` | none | `auth.backend.empty_username == true` | `tempfail` | `auth.fsm.event.auth_empty_user` | `auth.response.tempfail` |  |
| 220 | `standard_empty_password` | `authenticate` | none | `auth.backend.empty_password == true` | `deny` | `auth.fsm.event.auth_empty_pass` | `auth.response.fail` |  |
| 230 | `standard_lua_filter_<script>_error` | active operation: `authenticate` or `lookup_identity` | emitted Lua filter check | `auth.lua.filter.<script>.error == true` | `tempfail` | `auth.fsm.event.auth_tempfail` | `auth.response.tempfail` | Generated once per Lua filter check result. |
| 240 | `standard_lua_filter_<script>_reject` | active operation: `authenticate` or `lookup_identity` | emitted Lua filter check | `auth.lua.filter.<script>.rejected == true` | `deny` | `auth.fsm.event.auth_deny` | `auth.response.fail` | Uses public `status_message` detail from `auth.lua.filter.<script>.rejected` when selected. |
| 250 | `standard_auth_success` | `authenticate` | none | `auth.authenticated == true` | `permit` | `auth.fsm.event.auth_permit` | `auth.response.ok` |  |
| 260 | `standard_auth_failure` | `authenticate` | none | `auth.authenticated == false` | `deny` | `auth.fsm.event.auth_deny` | `auth.response.fail` |  |
| 300 | `standard_lookup_identity_success` | `lookup_identity` | none | `auth.identity.found == true` | `permit` | `auth.fsm.event.auth_permit` | `auth.response.ok` |  |
| 310 | `standard_lookup_identity_failure` | `lookup_identity` | none | `auth.identity.found == false` | `deny` | `auth.fsm.event.auth_deny` | `auth.response.fail` |  |
| 400 | `standard_list_accounts_tempfail` | `list_accounts` | `account_provider` | `auth.account_provider.tempfail == true` | `tempfail` | `auth.fsm.event.auth_tempfail` | `auth.response.tempfail` |  |
| 410 | `standard_list_accounts_success` | `list_accounts` | `account_provider` | `auth.account_provider.completed == true` | `permit` | `auth.fsm.event.auth_permit` | `auth.response.list_accounts.ok` |  |
| 420 | `standard_list_accounts_failure` | `list_accounts` | `account_provider` | `auth.account_provider.completed == false` | `deny` | `auth.fsm.event.auth_deny` | `auth.response.fail` |  |
| 900 | `standard_default_deny` | `authenticate`, `lookup_identity`, `list_accounts` | none | no earlier final rule matched | `deny` | `auth.fsm.event.auth_deny` | `auth.response.fail` | Final fallback. |

### Standard FSM Event Sequence

For a terminal pre-auth decision, the target FSM marker sequence is:

```text
auth.fsm.event.parse_ok
<selected pre_auth fsm_event_marker>
```

For an `authenticate` or `lookup_identity` final decision, the sequence is:

```text
auth.fsm.event.parse_ok
<latest selected pre_auth marker or auth.fsm.event.pre_auth_ok>
auth.fsm.event.auth_evaluated
<selected final auth_decision fsm_event_marker>
```

For a `list_accounts` final decision, the sequence is:

```text
auth.fsm.event.parse_ok
auth.fsm.event.pre_auth_ok
auth.fsm.event.account_provider_evaluated
<selected final auth_decision fsm_event_marker>
```

### Standard Response Messages

When a rule does not select a specific public Lua `status_message`, the response marker chooses the default response class:

| Response marker | Default message source |
|---|---|
| `auth.response.fail` | Invalid-login response text. |
| `auth.response.tempfail` | Generic temporary-failure response text. |
| `auth.response.tempfail.no_tls` | TLS-required temporary-failure response text. |
| `auth.response.ok` | No default failure message. |
| `auth.response.list_accounts.ok` | No default failure message. |

Brute force is first-class policy material. The built-in default runs brute-force first and evaluates the brute-force policy checkpoint before later pre-auth checks, preserving the default evaluation order without making brute force a separate policy bypass.

## Observability and Reports

Policy observability is redaction-aware. It has several layers:

| Layer | Purpose | Controlled by `auth.policy.report` |
|---|---|---:|
| Request-local `DecisionReport` | The in-memory policy diagnostic object used while the request is evaluated. | no |
| Normal structured logs | Bounded final facts for operations and alerting. | no |
| Debug logs with module `policy` | Detailed compiler, check, evaluation, FSM, observe, and report diagnosis. | no |
| Prometheus and OpenTelemetry | Metrics and traces for policy orchestration. | no |
| Optional decision report output | Redacted report payload for deeper inspection. | yes |

The request-local report is created for the active auth operation and collects the facts that the policy engine needs:

| Report field | Meaning |
|---|---|
| `session_id` | Request/session correlation ID when available. |
| `operation` | `authenticate`, `lookup_identity`, or `list_accounts`. |
| `stage` | Last evaluated policy stage. |
| `attributes` | Policy attributes emitted by built-ins, Lua, request facts, or backend exports. |
| `checks` | Check results with status, matched flag, decision hint, and emitted attributes. |
| `missing_checks` | Required checks that were not available for a policy rule. |
| `unavailable` | Facts/checks intentionally unavailable, for example custom-only non-observe-safe checks in observe mode. |
| `policies` | Selected policy decisions in evaluation order. |
| `final` | Final selected decision that enforcement applies. |
| `observe` | Default-vs-custom comparison result in `mode: observe`. |

Reports are diagnostic material, not authentication responses. They do not add fields to HTTP, CBOR, Nginx auth-request, gRPC, OIDC, or SAML responses, and enabling reports does not change policy decisions.

### Report Configuration

```yaml
auth:
  policy:
    report:
      enabled: true
      include_fsm: true
      include_checks: true
      include_attributes: false
```

| Key | Default | Effect |
|---|---:|---|
| `enabled` | `false` | Enables optional redacted decision report output. The in-memory report still exists when this is `false`. |
| `include_fsm` | `true` | Keeps FSM decision material in report output. The selected FSM marker is still enforced when reports are disabled. |
| `include_checks` | `true` | Keeps check results in report output. Checks still run and affect policy decisions when reports are disabled. |
| `include_attributes` | `false` | Includes emitted attributes in report output. Leave this off unless you are actively diagnosing a policy, because reports become larger and redaction matters more. |

The implementation defaults `include_fsm` and `include_checks` to `true` when omitted. `include_attributes` defaults to `false` because attributes may contain internal diagnostic details.

### Redaction Rules

Decision reports must not expose passwords, tokens, cookies, LDAP bind secrets, raw runtime errors, stack traces, or non-public attribute details.

Attribute details carry sensitivity metadata:

| Sensitivity | Report behavior |
|---|---|
| `public` | May appear only when the detail is selected for a public purpose, such as the final response message. |
| `internal` | Redacted from normal reports. |
| `secret` | Always redacted. |

The redacted value placeholder is `[redacted]`. A public Lua `status_message` detail appears only after a policy explicitly selects it through `then.response_message`.

### Observe Mode Reports

In `mode: observe`, `standard_auth` remains the production decision. Custom policies run as shadow evaluation and populate `observe` with comparison data:

| Observe field | Meaning |
|---|---|
| `production` | The authoritative `standard_auth` final decision. |
| `shadow` | The custom-policy final decision. |
| `surface` | Response surface used for comparison, such as `http_json`, `grpc_auth_service`, or `http_list_accounts`. |
| `mismatch` and `mismatch_type` | Whether custom and production behavior differ, and why. |
| `production_terminal_state` / `shadow_terminal_state` | FSM terminal-state comparison. |
| `response_message_match` | Whether sanitized rendered response messages match. |
| `obligations_match` | Whether planned obligations match. |

Observe mode deliberately does not execute custom obligations, Lua POST-Action enqueueing, brute-force counter updates, learning updates, or other custom mutable side effects.

### Report Example

```json
{
  "operation": "authenticate",
  "stage": "pre_auth",
  "attributes": {
    "auth.rbl.threshold_reached": {
      "id": "auth.rbl.threshold_reached",
      "stage": "pre_auth",
      "operation": "authenticate",
      "value": true,
      "details": {
        "lists": {
          "value": "[redacted]"
        }
      }
    }
  },
  "checks": {
    "rbl": {
      "name": "rbl",
      "type": "builtin.rbl",
      "stage": "pre_auth",
      "status": "ok",
      "decision_hint": "deny",
      "matched": true,
      "attributes": ["auth.rbl.threshold_reached"]
    }
  },
  "policies": [
    {
      "policy_name": "standard_rbl_reject",
      "stage": "pre_auth",
      "effect": "deny",
      "fsm_event_marker": "auth.fsm.event.pre_auth_deny",
      "response_marker": "auth.response.fail",
      "response_message": {
        "source": "response_marker",
        "message": "Invalid login or password"
      }
    }
  ],
  "final": {
    "policy_name": "standard_rbl_reject",
    "stage": "pre_auth",
    "effect": "deny",
    "fsm_event_marker": "auth.fsm.event.pre_auth_deny",
    "response_marker": "auth.response.fail"
  }
}
```

The exact output surface is diagnostic and not a public authentication API contract. Use stable policy IDs, `reason`, `outcome_marker`, `response_marker`, and `fsm_event_marker` for automation rather than parsing raw transport-specific auth responses.

### Logs, Metrics, and Traces

Normal structured logs include bounded final facts such as:

- `policy_mode`
- `policy_set`
- `policy_name`
- `operation`
- `stage`
- `decision`
- `reason`
- `response_marker`
- `fsm_event_marker`
- `snapshot_generation`
- observe mismatch flags

Debug logs use one debug module named `policy` and a `policy_component` field such as `compiler`, `snapshot`, `checks`, `eval`, `fsm`, `observe`, or `report`.

Prometheus and OpenTelemetry instrumentation covers snapshot build/reload, check execution, policy evaluation, `require_checks`, observe comparison, FSM application, response rendering, obligations, and advice. Labels are bounded. Usernames, client IPs, tokens, raw errors, response text, and attribute-detail values are not used as Prometheus labels.

## Validation and Dumps

Policy errors use canonical config paths such as:

```text
auth.policy.checks[2].type is invalid
auth.policy.policies[1].require_checks[0] references unknown check "foo"
auth.policy.policies[3].if.attribute references unknown attribute
```

Validate a file:

```bash
nauthilus --config /etc/nauthilus/nauthilus.yml --config-check
```

Inspect defaults and non-defaults:

```bash
nauthilus -d
nauthilus -n --config /etc/nauthilus/nauthilus.yml
```

`auth.policy` values appear in the canonical dump output. Sensitive values stay redacted unless `-P` is used.

## Related Guides

- [Auth Policy Configuration Guide](../guides/auth-policy-configuration.md)
- [Config v2 Migration](../guides/config-v2-migration.md)
- [Lua Backend](database-backends/lua.md)
