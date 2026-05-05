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
| `sets.networks` | map | `{}` | Named reusable IP/CIDR sets for policy conditions. |
| `sets.time_windows` | map | `{}` | Named local-time windows for policy conditions. |
| `report.enabled` | bool | `false` | Enables optional decision reports. |
| `report.include_fsm` | bool | `true` | Includes FSM marker and terminal-state material in reports. |
| `report.include_checks` | bool | `true` | Includes check results in reports. |
| `report.include_attributes` | bool | `false` | Includes emitted attributes when enabled. Redaction still applies. |
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

The `then` block always needs `decision`.

```yaml
then:
  decision: deny
  reason: billing_locked
  response_marker: auth.response.fail
```

| Field | Purpose |
|---|---|
| `decision` | `neutral`, `deny`, `permit`, or `tempfail`. `permit` is not allowed in `pre_auth`. |
| `reason` | Internal reason for logs, reports, metrics, and advice. |
| `outcome_marker` | Optional stable outcome marker. |
| `fsm_event_marker` | Optional target FSM event marker. If omitted, Nauthilus derives one when unambiguous. |
| `response_marker` | Optional response class. If omitted, Nauthilus derives one from the decision when possible. |
| `response_message` | Optional final client-visible message selection. |
| `obligations` | Mandatory registered enforcement work. |
| `advice` | Non-binding registered context. |
| `control.skip_remaining_stage_checks` | Stage-local control for neutral decisions that should stop later checks. |

### FSM Event Markers

FSM means finite-state machine. In Nauthilus it is the deterministic request-state tracker that records how an auth request moved through parsing, pre-auth checks, backend or account-provider evaluation, and the final decision; policy rules select FSM markers so logs, reports, metrics, and transport responses describe the same terminal path.

Operator policies may reference policy-visible target markers only:

| Marker | Valid stage | Meaning |
|---|---|---|
| `auth.fsm.event.pre_auth_ok` | `pre_auth` | Continue after pre-auth. |
| `auth.fsm.event.pre_auth_deny` | `pre_auth` | Terminate as denial before backend auth. |
| `auth.fsm.event.pre_auth_tempfail` | `pre_auth` | Terminate as temporary failure before backend auth. |
| `auth.fsm.event.pre_auth_abort` | `pre_auth` | Abort pre-auth processing. |
| `auth.fsm.event.auth_permit` | `auth_decision` | Final permit for the active operation. |
| `auth.fsm.event.auth_deny` | `auth_decision` | Final deny for the active operation. |
| `auth.fsm.event.auth_tempfail` | `auth_decision` | Final temporary failure for the active operation. |
| `auth.fsm.event.auth_empty_user` | `auth_decision` | Empty username behavior. |
| `auth.fsm.event.auth_empty_pass` | `auth_decision` | Empty password behavior. |

Internal parser, stage-orchestration, caller-auth, and abort markers are not policy-visible.

### Response Markers

| Marker | Decision | Purpose |
|---|---|---|
| `auth.response.ok` | `permit` | Successful auth or lookup response. |
| `auth.response.fail` | `deny` | Authentication, lookup, or account-list denial. |
| `auth.response.tempfail` | `tempfail` | Temporary failure. |
| `auth.response.tempfail.no_tls` | `tempfail` | TLS-required temporary failure. |
| `auth.response.list_accounts.ok` | `permit` | Successful `list_accounts` response. |

Policies select response markers, not raw HTTP status codes, headers, gRPC status codes, OIDC protocol fields, or SAML protocol fields.

### Response Messages

If `response_message` is omitted or `from: default`, Nauthilus uses the default message from the response marker.

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

`attribute_detail` is valid only for a registered string detail with `sensitivity: public` and `purpose: response_message`. Generated Lua control and Lua filter decision attributes expose `status_message` this way.

### Obligations and Advice

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
| `auth.brute_force.triggered` | `pre_auth` | `authenticate` | bool | `rule`, `client_net`, `repeating` |
| `auth.brute_force.error` | `pre_auth` | `authenticate` | bool | `reason_code`, `retryable` |
| `auth.tls.secure` | `pre_auth` | `authenticate`, `lookup_identity` | bool | none |
| `auth.relay_domain.present` | `pre_auth` | `authenticate` | bool | `domain` |
| `auth.relay_domain.known` | `pre_auth` | `authenticate` | bool | `domain` |
| `auth.relay_domain.error` | `pre_auth` | `authenticate` | bool | `reason_code`, `retryable` |
| `auth.rbl.threshold_reached` | `pre_auth` | `authenticate`, `lookup_identity` | bool | `lists` |
| `auth.rbl.error` | `pre_auth` | `authenticate`, `lookup_identity` | bool | `reason_code`, `retryable` |
| `auth.authenticated` | `auth_backend` | `authenticate` | bool | `backend` |
| `auth.identity.found` | `auth_backend` | `lookup_identity` | bool | `backend` |
| `auth.backend.tempfail` | `auth_backend` | `authenticate`, `lookup_identity` | bool | `backend`, `reason_code`, `retryable` |
| `auth.backend.empty_username` | `auth_backend` | `authenticate`, `lookup_identity` | bool | none |
| `auth.backend.empty_password` | `auth_backend` | `authenticate` | bool | none |
| `auth.account_provider.completed` | `account_provider` | `list_accounts` | bool | `count` |
| `auth.account_provider.tempfail` | `account_provider` | `list_accounts` | bool | `reason_code`, `retryable` |

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

Policy observability is redaction-aware.

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

Decision reports must not expose passwords, tokens, cookies, LDAP bind secrets, raw runtime errors, stack traces, or non-public attribute details. Public response messages may appear only after policy selection and response sanitization.

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
