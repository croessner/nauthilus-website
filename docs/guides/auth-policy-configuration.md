---
title: Auth Policy Configuration Guide
description: Practical guide for writing auth.policy by hand, including operation scope, auth-state guards, and check ordering
keywords: [Guide, Policy, Auth, Lua, Scheduling, Checks]
sidebar_position: 7
---

# Auth Policy Configuration Guide

This guide explains how to write Nauthilus auth policies by hand. It starts with the mental model, then shows how to define operation scope, auth-state guards, check start order, and final decisions with explicit policy checks and rules.

Use this guide when you want to make your authentication flow explicit in `auth.policy`.

For the complete field reference, see [Auth Policy Reference](../configuration/auth-policy.md).

## The Short Version

A policy-controlled Lua setup has two parts. First, define the script entries:

```yaml
auth:
  controls:
    lua:
      controls:
        - name: geoip
          script_path: /etc/nauthilus/lua/controls/geoip.lua
        - name: policy_gate
          script_path: /etc/nauthilus/lua/controls/policy_gate.lua
```

Then define when and in which order the scripts run:

```yaml
auth:
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

Decisions live in `auth.policy.policies`:

```yaml
auth:
  policy:
    policies:
      - name: deny_policy_gate
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        require_checks: [lua_control_policy_gate]
        if:
          attribute: auth.lua.control.policy_gate.triggered
          is: true
        then:
          decision: deny
          reason: policy_gate_triggered
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: auth.lua.control.policy_gate.triggered
            detail: status_message
            fallback: "Invalid login or password"
```

## Mental Model

Think in three layers.

Mechanism configuration defines what exists:

```yaml
auth.controls.lua.controls
auth.controls.lua.filters
auth.controls.brute_force
auth.controls.rbl
auth.backends.ldap
auth.backends.lua.backend
```

Policy checks define which facts are produced for which operation and stage:

```yaml
auth.policy.checks
```

Policy rules define how those facts become `permit`, `deny`, `tempfail`, or `neutral`:

```yaml
auth.policy.policies
```

Lua can still contain complex logic, Redis lookups, HTTP calls, LDAP lookups through existing Lua APIs, or deployment-specific checks. The YAML policy should not do that work. Lua emits typed facts, and YAML decides what those facts mean.

The model is inspired by OASIS XACML 3.0: Nauthilus keeps fact collection, policy decision, and enforcement separate. It is not XACML-compatible syntax; it uses Nauthilus YAML, fixed auth stages, response markers, FSM markers, obligations, and advice.

FSM means finite-state machine. For an administrator, it is the request-state path that Nauthilus records from parse through pre-auth, backend or account-provider evaluation, and the final decision. Policy rules select FSM markers so reports, logs, metrics, and responses agree on which terminal path was reached.

## Policy-Owned Scheduling

Lua mechanism entries define scripts. They do not define scheduling. Keep execution selection in `auth.policy.checks` so the policy snapshot has one authoritative operation plan.

The three scheduling controls are:

- `operations`: selects `authenticate`, `lookup_identity`, or `list_accounts`.
- `run_if.auth_state`: narrows execution by authenticated, unauthenticated, or any state.
- `after`: defines start order inside the compiled check plan.

## Start With the Default

If you do not need custom policy behavior, you can omit `auth.policy` entirely or keep the default shape:

```yaml
auth:
  policy:
    mode: enforce
    default_policy: standard_auth
```

`standard_auth` preserves default Nauthilus behavior as the built-in default policy set.

If you only want to control which checks run, where Lua scripts run, and how checks are ordered, configure `checks` only. `standard_auth` remains the decision authority and consumes the emitted facts.

Add `policies` only when you want to write custom decision rules.

## Configure Scheduling Without Custom Decisions

This shape controls Lua execution while leaving decisions to `standard_auth`:

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

      - name: lua_filter_context_seed
        type: lua.filter
        stage: auth_filters
        run_if:
          auth_state: authenticated
        config_ref: auth.controls.lua.filters.context_seed

      - name: lua_filter_billing_lock
        type: lua.filter
        stage: auth_filters
        after: [lua_filter_context_seed]
        run_if:
          auth_state: authenticated
        config_ref: auth.controls.lua.filters.billing_lock
```

The check plan is authoritative for the configured Lua script family in the active operation and stage. A script without a matching check does not run in that request plan. If you configure no checks for a Lua script family, Nauthilus uses the built-in default scheduling for that family.

For Lua controls and filters, `standard_auth` maps the generated Lua facts to the built-in result:

- `auth.lua.control.<name>.error` selects a temporary failure.
- `auth.lua.control.<name>.triggered` selects a deny.
- `auth.lua.control.<name>.abort` skips the remaining pre-auth checks for that stage.
- `auth.lua.filter.<name>.error` selects a temporary failure.
- `auth.lua.filter.<name>.rejected` selects a deny.

## Policy Scheduling Goals

| Goal | Policy expression |
|---|---|
| Run for normal password auth | omit `operations` or set `operations: [authenticate]` |
| Run for HTTP no-auth or gRPC lookup | include `lookup_identity` in `operations` |
| Run only after backend auth succeeded | `run_if.auth_state: authenticated` |
| Run only after backend auth failed or is unauthenticated | `run_if.auth_state: unauthenticated` |
| Run in both authenticated and unauthenticated states | omit `run_if` or use `run_if.auth_state: any` |
| Run script B after script A | put `after: [check_for_script_a]` on script B's check |
| Depend on a script's fact in a rule | put that check in `require_checks` |
| Send Lua status message to the client | select the generated `status_message` attribute detail in `response_message` |

`after` and `require_checks` are different:

- `after` is check execution order.
- `require_checks` is policy applicability and validation.

Do not use `require_checks` as a scheduler. It never causes a check to run.

## Step 1: Define Lua Mechanism Blocks

Keep only the script identity and script path on controls and filters.

```yaml
auth:
  controls:
    enabled:
      - lua

    lua:
      controls:
        - name: geoip
          script_path: /etc/nauthilus/lua/controls/geoip.lua
        - name: policy_gate
          script_path: /etc/nauthilus/lua/controls/policy_gate.lua

      filters:
        - name: context_seed
          script_path: /etc/nauthilus/lua/filters/context_seed.lua
        - name: billing_lock
          script_path: /etc/nauthilus/lua/filters/billing_lock.lua
```

These entries do not decide when they run. The policy check plan does.

## Step 2: Add the Policy Header

```yaml
auth:
  policy:
    mode: enforce
    default_policy: standard_auth
    registry_scripts: []

    report:
      enabled: false
      include_fsm: true
      include_checks: true
      include_attributes: false
```

Use `mode: observe` first if you want to compare custom policy output against `standard_auth` without changing production decisions.

## Step 3: Define Checks

Create one check per built-in mechanism or named Lua script that your policies need.

```yaml
auth:
  policy:
    checks:
      - name: brute_force
        type: builtin.brute_force
        stage: pre_auth
        config_ref: auth.controls.brute_force
        output: checks.brute_force

      - name: tls_encryption
        type: builtin.tls_encryption
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        config_ref: auth.controls.tls_encryption
        output: checks.tls_encryption

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

The check name can be your own stable name. The converter uses names such as `lua_control_<script>` and `lua_filter_<script>` because they are predictable.

## Step 4: Select Operations

Use `operations` to define which request operation may execute a check.

Run a check for normal password authentication and identity lookup:

```yaml
operations: [authenticate, lookup_identity]
```

Run a check only for normal password authentication:

```yaml
operations: [authenticate]
```

Because `authenticate` is the default, you may omit `operations` for auth-only checks.

## Step 5: Select Auth-State Scheduling

Use `run_if.auth_state` only for structural check scheduling.

Run only after a successful backend result:

```yaml
run_if:
  auth_state: authenticated
```

Run only when the request is unauthenticated:

```yaml
run_if:
  auth_state: unauthenticated
```

Run in either state:

```yaml
run_if:
  auth_state: any
```

Or omit `run_if`, because `any` is the default.

Do not put business facts into `run_if`. For account lock state, country, risk level, group membership, RBL result, or billing state, emit or use attributes and write an `if` condition.

## Step 6: Define Start Order with `after`

Use `after` when one check needs request-local state or emitted facts from another check before it can run.

First define the scripts:

```yaml
auth:
  controls:
    lua:
      filters:
        - name: context_seed
          script_path: /etc/nauthilus/lua/filters/context_seed.lua
        - name: billing_lock
          script_path: /etc/nauthilus/lua/filters/billing_lock.lua
```

Then define the check order:

```yaml
auth:
  policy:
    checks:
      - name: lua_filter_context_seed
        type: lua.filter
        stage: auth_filters
        run_if:
          auth_state: authenticated
        config_ref: auth.controls.lua.filters.context_seed
        output: checks.lua_filter_context_seed

      - name: lua_filter_billing_lock
        type: lua.filter
        stage: auth_filters
        after: [lua_filter_context_seed]
        run_if:
          auth_state: authenticated
        config_ref: auth.controls.lua.filters.billing_lock
        output: checks.lua_filter_billing_lock
```

`after` references check names, not script names. Dependencies must be scheduler-compatible: the dependency must be in the same stage and must cover the dependent check's operations and auth-state guard.

## Step 7: Write Policies for Pre-Auth Controls

A Lua control can emit generated attributes:

- `auth.lua.control.<name>.triggered`
- `auth.lua.control.<name>.abort`
- `auth.lua.control.<name>.error`

Use those attributes in policies.

```yaml
auth:
  policy:
    policies:
      - name: geoip_control_error
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        require_checks: [lua_control_geoip]
        if:
          attribute: auth.lua.control.geoip.error
          is: true
        then:
          decision: tempfail
          reason: geoip_error
          response_marker: auth.response.tempfail

      - name: geoip_control_deny
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        require_checks: [lua_control_geoip]
        if:
          attribute: auth.lua.control.geoip.triggered
          is: true
        then:
          decision: deny
          reason: geoip_blocked
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: auth.lua.control.geoip.triggered
            detail: status_message
            fallback: "Invalid login or password"
```

For a Lua control that aborts later pre-auth checks but does not deny:

```yaml
- name: geoip_control_abort
  stage: pre_auth
  operations: [authenticate, lookup_identity]
  require_checks: [lua_control_geoip]
  if:
    attribute: auth.lua.control.geoip.abort
    is: true
  then:
    decision: neutral
    reason: geoip_aborted_pre_auth
    control:
      skip_remaining_stage_checks: true
```

Do not use `permit` in `pre_auth`. Pre-auth controls can deny, tempfail, or let the request continue.

## Step 8: Write Policies for Backend and Lua Filters

Backends produce final auth facts:

- `auth.authenticated`
- `auth.identity.found`
- `auth.backend.tempfail`
- `auth.backend.empty_username`
- `auth.backend.empty_password`

Lua filters produce generated attributes:

- `auth.lua.filter.<name>.rejected`
- `auth.lua.filter.<name>.error`

Example:

```yaml
auth:
  policy:
    policies:
      - name: billing_filter_error
        stage: auth_decision
        require_checks: [lua_filter_billing_lock]
        if:
          attribute: auth.lua.filter.billing_lock.error
          is: true
        then:
          decision: tempfail
          reason: billing_filter_error
          response_marker: auth.response.tempfail

      - name: billing_filter_reject
        stage: auth_decision
        require_checks: [lua_filter_billing_lock]
        if:
          attribute: auth.lua.filter.billing_lock.rejected
          is: true
        then:
          decision: deny
          reason: billing_locked
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: auth.lua.filter.billing_lock.rejected
            detail: status_message
            fallback: "Invalid login or password"

      - name: backend_tempfail
        stage: auth_decision
        operations: [authenticate, lookup_identity]
        if:
          attribute: auth.backend.tempfail
          is: true
        then:
          decision: tempfail
          reason: backend_tempfail
          response_marker: auth.response.tempfail

      - name: auth_success
        stage: auth_decision
        operations: [authenticate]
        if:
          attribute: auth.authenticated
          is: true
        then:
          decision: permit
          reason: auth_success
          response_marker: auth.response.ok

      - name: auth_failure
        stage: auth_decision
        operations: [authenticate]
        if:
          attribute: auth.authenticated
          is: false
        then:
          decision: deny
          reason: auth_failure
          response_marker: auth.response.fail

      - name: default_deny
        stage: auth_decision
        operations: [authenticate, lookup_identity, list_accounts]
        if:
          always: true
        then:
          decision: deny
          reason: default_deny
          response_marker: auth.response.fail
```

Keep a default-deny rule last in custom final-auth policy sets.

## Step 9: Add Lookup and Account Listing

For no-auth identity lookup:

```yaml
- name: lookup_identity_success
  stage: auth_decision
  operations: [lookup_identity]
  if:
    attribute: auth.identity.found
    is: true
  then:
    decision: permit
    reason: lookup_identity_success
    response_marker: auth.response.ok

- name: lookup_identity_failure
  stage: auth_decision
  operations: [lookup_identity]
  if:
    attribute: auth.identity.found
    is: false
  then:
    decision: deny
    reason: lookup_identity_failure
    response_marker: auth.response.fail
```

For account listing, define the account-provider check:

```yaml
- name: account_provider
  type: backend.account_provider
  stage: account_provider
  operations: [list_accounts]
  config_ref: auth.backends
  output: checks.account_provider
```

Then add final decisions:

```yaml
- name: list_accounts_success
  stage: auth_decision
  operations: [list_accounts]
  require_checks: [account_provider]
  if:
    attribute: auth.account_provider.completed
    is: true
  then:
    decision: permit
    reason: list_accounts_success
    response_marker: auth.response.list_accounts.ok

- name: list_accounts_tempfail
  stage: auth_decision
  operations: [list_accounts]
  require_checks: [account_provider]
  if:
    attribute: auth.account_provider.tempfail
    is: true
  then:
    decision: tempfail
    reason: list_accounts_tempfail
    response_marker: auth.response.tempfail
```

The account list itself is response data. It is not exposed as a policy attribute.

## Complete Example

This example expresses a common setup explicitly:

- brute force blocks normal password auth
- TLS is required for password auth and identity lookup
- two Lua controls run before backend auth, with one ordered after the other
- LDAP backend facts decide final auth and lookup behavior
- two Lua filters run after successful backend auth, ordered through `after`
- account listing is permitted only when the account provider completes

```yaml
auth:
  controls:
    enabled:
      - brute_force
      - tls_encryption
      - lua

    brute_force:
      protocols: [imap, smtp, submission]

    tls_encryption:
      allow_cleartext_networks:
        - 127.0.0.0/8

    lua:
      controls:
        - name: geoip
          script_path: /etc/nauthilus/lua/controls/geoip.lua
        - name: policy_gate
          script_path: /etc/nauthilus/lua/controls/policy_gate.lua

      filters:
        - name: context_seed
          script_path: /etc/nauthilus/lua/filters/context_seed.lua
        - name: billing_lock
          script_path: /etc/nauthilus/lua/filters/billing_lock.lua

  backends:
    order: [cache, ldap]
    ldap:
      default:
        server_uri:
          - ldapi:///
      search: []

  policy:
    mode: enforce
    default_policy: standard_auth
    registry_scripts: []

    report:
      enabled: false
      include_fsm: true
      include_checks: true
      include_attributes: false

    checks:
      - name: brute_force
        type: builtin.brute_force
        stage: pre_auth
        config_ref: auth.controls.brute_force
        output: checks.brute_force

      - name: tls_encryption
        type: builtin.tls_encryption
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        config_ref: auth.controls.tls_encryption
        output: checks.tls_encryption

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

      - name: ldap_backend
        type: backend.ldap
        stage: auth_backend
        operations: [authenticate, lookup_identity]
        config_ref: auth.backends.ldap
        output: checks.ldap_backend

      - name: lua_filter_context_seed
        type: lua.filter
        stage: auth_filters
        run_if:
          auth_state: authenticated
        config_ref: auth.controls.lua.filters.context_seed
        output: checks.lua_filter_context_seed

      - name: lua_filter_billing_lock
        type: lua.filter
        stage: auth_filters
        after: [lua_filter_context_seed]
        run_if:
          auth_state: authenticated
        config_ref: auth.controls.lua.filters.billing_lock
        output: checks.lua_filter_billing_lock

      - name: account_provider
        type: backend.account_provider
        stage: account_provider
        operations: [list_accounts]
        config_ref: auth.backends
        output: checks.account_provider

    policies:
      - name: brute_force_deny
        stage: pre_auth
        require_checks: [brute_force]
        if:
          attribute: auth.brute_force.triggered
          is: true
        then:
          decision: deny
          reason: brute_force
          response_marker: auth.response.fail
          obligations:
            - id: auth.obligation.brute_force.update

      - name: tls_required
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

      - name: policy_gate_deny
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        require_checks: [lua_control_policy_gate]
        if:
          attribute: auth.lua.control.policy_gate.triggered
          is: true
        then:
          decision: deny
          reason: policy_gate
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: auth.lua.control.policy_gate.triggered
            detail: status_message
            fallback: "Invalid login or password"

      - name: backend_tempfail
        stage: auth_decision
        operations: [authenticate, lookup_identity]
        if:
          attribute: auth.backend.tempfail
          is: true
        then:
          decision: tempfail
          reason: backend_tempfail
          response_marker: auth.response.tempfail

      - name: billing_lock_deny
        stage: auth_decision
        require_checks: [lua_filter_billing_lock]
        if:
          attribute: auth.lua.filter.billing_lock.rejected
          is: true
        then:
          decision: deny
          reason: billing_locked
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: auth.lua.filter.billing_lock.rejected
            detail: status_message
            fallback: "Invalid login or password"

      - name: auth_success
        stage: auth_decision
        operations: [authenticate]
        if:
          attribute: auth.authenticated
          is: true
        then:
          decision: permit
          reason: auth_success
          response_marker: auth.response.ok

      - name: auth_failure
        stage: auth_decision
        operations: [authenticate]
        if:
          attribute: auth.authenticated
          is: false
        then:
          decision: deny
          reason: auth_failure
          response_marker: auth.response.fail

      - name: lookup_success
        stage: auth_decision
        operations: [lookup_identity]
        if:
          attribute: auth.identity.found
          is: true
        then:
          decision: permit
          reason: lookup_success
          response_marker: auth.response.ok

      - name: lookup_failure
        stage: auth_decision
        operations: [lookup_identity]
        if:
          attribute: auth.identity.found
          is: false
        then:
          decision: deny
          reason: lookup_failure
          response_marker: auth.response.fail

      - name: list_accounts_tempfail
        stage: auth_decision
        operations: [list_accounts]
        require_checks: [account_provider]
        if:
          attribute: auth.account_provider.tempfail
          is: true
        then:
          decision: tempfail
          reason: list_accounts_tempfail
          response_marker: auth.response.tempfail

      - name: list_accounts_success
        stage: auth_decision
        operations: [list_accounts]
        require_checks: [account_provider]
        if:
          attribute: auth.account_provider.completed
          is: true
        then:
          decision: permit
          reason: list_accounts_success
          response_marker: auth.response.list_accounts.ok

      - name: default_deny
        stage: auth_decision
        operations: [authenticate, lookup_identity, list_accounts]
        if:
          always: true
        then:
          decision: deny
          reason: default_deny
          response_marker: auth.response.fail
```

This is a template. Keep only the checks and rules that match the mechanisms in your deployment.

## Custom Lua Attributes

Generated Lua control and filter attributes are enough for trigger, abort, reject, error, and status-message behavior. Use a registry script when Lua needs to expose custom facts.

Policy registry script:

```lua
nauthilus_policy.register_attribute({
  id = "lua.risk.high",
  stage = "pre_auth",
  operations = { "authenticate", "lookup_identity" },
  category = "environment",
  type = "bool",
  description = "The request has high local risk",
  details = {
    source = "string",
    status_message = {
      type = "string",
      sensitivity = "public",
      purpose = "response_message",
      max_length = 256,
    },
  },
})
```

Config:

```yaml
auth:
  policy:
    registry_scripts:
      - /etc/nauthilus/policy/attributes.lua
```

Policy:

```yaml
- name: deny_high_risk
  stage: pre_auth
  operations: [authenticate, lookup_identity]
  require_checks: [lua_control_geoip]
  if:
    attribute: lua.risk.high
    is: true
  then:
    decision: deny
    reason: high_risk
    response_marker: auth.response.fail
    response_message:
      from: attribute_detail
      attribute: lua.risk.high
      detail: status_message
      fallback: "Invalid login or password"
```

Runtime Lua must emit only attributes already registered in the active snapshot.

## Testing a Policy Change

1. Start with `mode: observe` for non-trivial custom policies.
2. Enable reports only where you need diagnostics.
3. Validate the config.
4. Inspect `-n` output for the effective policy.
5. Switch to `mode: enforce` when the observed decisions match your intent.

Commands:

```bash
nauthilus --config /etc/nauthilus/nauthilus.yml --config-check
```

```bash
nauthilus -n --config /etc/nauthilus/nauthilus.yml
```

```bash
nauthilus -d
```

## Troubleshooting

Unknown keys on Lua control or filter entries:

- Keep Lua script entries to their supported fields such as `name` and `script_path`.
- Express operation scope, auth-state scheduling, and start order in `auth.policy.checks`.

`require_checks` references an unknown check:

- Check the exact `name` in `auth.policy.checks`.
- `require_checks` uses check names, not attribute IDs and not script paths.

Same-stage attribute validation fails:

- Add the producing check to `require_checks`.
- Same-stage facts require explicit producer declaration so the scheduler and rule dependency are obvious.

`after` is not scheduler-compatible:

- Keep dependencies in the same stage.
- Make sure the dependency covers all operations and auth-state guards of the dependent check.

Response-message selection fails:

- Use `from: literal` for static messages.
- Use `from: attribute_detail` only for registered public response-message string details such as generated Lua `status_message`.

A final policy set denies unexpectedly:

- Remember that `auth_decision` is deny-biased.
- Add a final success rule before the final default-deny rule.
- Keep `default_deny` last.

## Related Reference

- [Auth Policy Reference](../configuration/auth-policy.md)
- [Lua Backend](../configuration/database-backends/lua.md)
- [Config v2 Migration](config-v2-migration.md)
