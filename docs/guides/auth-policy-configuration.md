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
  policy:
    attribute_sources:
      lua:
        environment:
          - name: geoip
            script_path: /etc/nauthilus/lua/environment/geoip.lua
          - name: policy_gate
            script_path: /etc/nauthilus/lua/environment/policy_gate.lua
```

Then define when and in which order the scripts run:

```yaml
auth:
  policy:
    checks:
      - name: lua_environment_geoip
        type: lua.environment
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        config_ref: auth.policy.attribute_sources.lua.environment.geoip
        output: checks.lua_environment_geoip

      - name: lua_environment_policy_gate
        type: lua.environment
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        after: [lua_environment_geoip]
        config_ref: auth.policy.attribute_sources.lua.environment.policy_gate
        output: checks.lua_environment_policy_gate
```

Decisions live in `auth.policy.policies`:

```yaml
auth:
  policy:
    policies:
      - name: deny_policy_gate
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        require_checks: [lua_environment_policy_gate]
        if:
          attribute: auth.lua.environment.policy_gate.triggered
          is: true
        then:
          decision: deny
          reason: policy_gate_triggered
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: auth.lua.environment.policy_gate.triggered
            detail: status_message
            fallback: "Invalid login or password"
```

## Mental Model

Think in three layers.

Mechanism configuration defines what exists:

```yaml
auth.policy.attribute_sources.lua.environment
auth.policy.attribute_sources.lua.subject
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

## Understand FSM Markers

FSM means finite-state machine. For an administrator, it is the request-state path that Nauthilus records from parse through pre-auth, backend or account-provider evaluation, and the final decision.

You usually do not need to write FSM markers by hand. Write the policy `decision` and the `response_marker`; Nauthilus derives the normal `fsm_event_marker` from the stage and decision.

| Rule context | Decision | Derived FSM marker | Practical meaning |
|---|---|---|---|
| `pre_auth` | `neutral` | `auth.fsm.event.pre_auth_ok` | Continue to the next auth phase; this is not a login success. |
| `pre_auth` | `deny` | `auth.fsm.event.pre_auth_deny` | Block before backend auth. |
| `pre_auth` | `tempfail` | `auth.fsm.event.pre_auth_tempfail` | Temporary failure before backend auth. |
| `pre_auth` | `permit` | not allowed | Pre-auth cannot grant final success. |
| `auth_decision` | `permit` | `auth.fsm.event.auth_permit` | Final success for the active operation. |
| `auth_decision` | `deny` | `auth.fsm.event.auth_deny` | Final denial for the active operation. |
| `auth_decision` | `tempfail` | `auth.fsm.event.auth_tempfail` | Final temporary failure for the active operation. |
| `auth_decision` | `neutral` | none | Evaluation continues; without a later `permit`, final enforcement denies. |

The important distinction is:

- `decision` is the policy result.
- `response_marker` is the client-visible response class.
- `fsm_event_marker` is the internal request-state event used for enforcement, reports, logs, metrics, and traces.

Normal rule:

```yaml
then:
  decision: deny
  reason: policy_gate_triggered
  response_marker: auth.response.fail
```

If this rule is in `pre_auth`, Nauthilus derives `auth.fsm.event.pre_auth_deny`. If the same decision is in `auth_decision`, it derives `auth.fsm.event.auth_deny`.

Final FSM markers are operation-specific. `auth.fsm.event.auth_permit` means password-auth success for `authenticate`, identity-found success for `lookup_identity`, and account-list success for `list_accounts`.

Set `fsm_event_marker` explicitly only when you need a more specific state path than the default decision mapping, for example empty credentials or an intentional pre-auth abort:

```yaml
auth:
  policy:
    policies:
      - name: deny_empty_password
        stage: auth_decision
        operations: [authenticate]
        if:
          attribute: auth.backend.empty_password
          is: true
        then:
          decision: deny
          reason: empty_password
          fsm_event_marker: auth.fsm.event.auth_empty_pass
          response_marker: auth.response.fail
```

Do not use terminal state names such as `auth_ok`, `auth_fail`, or `auth_tempfail` in policy YAML. Policies reference FSM event markers such as `auth.fsm.event.auth_deny`; Nauthilus applies those events and reaches terminal states internally.

Two common gotchas:

- `neutral` does not mean `permit`. It means "this rule did not deny or tempfail the request".
- `permit` is not allowed in `pre_auth`. Only `auth_decision` can grant final success.

## Fact Categories in Plain Language

Policy attributes are grouped into categories. You do not need to put the category into an `if` condition; it is registry metadata that helps humans, reports, and future tooling understand where a fact belongs.

| Category | Think of it as | Common examples |
|---|---|---|
| `environment` | Things around the request. | client IP, protocol, time, TLS status, RBL score, relay-domain result, brute-force state |
| `subject` | Things about the user or account. | backend authentication result, identity found, exported LDAP/Lua backend attributes, account lock state |
| `resource` | Things about a requested resource or resource-producing operation. | account-provider completion and account-list count |
| `action` | The requested action. | Nauthilus currently uses `request.operation` for this instead of many action attributes. |
| `system` | Internal/system facts reserved for registry and tooling use. | currently not needed in normal hand-written policies |

`environment` does not mean shell environment variables. It means "request surroundings". `subject` means "the identity/account side". A backend field such as `accountStatus` is a subject attribute only after you explicitly export it through `auth.policy.attribute_exports`.

## Use Request Facts

YAML policies do not dereference the Lua `request` object. Use the registered policy attributes instead:

| Policy attribute | Lua-style field this is easy to confuse with | Use for |
|---|---|---|
| `request.client.ip` | `request.client_ip` | CIDR checks, client-IP allow/deny decisions, network sets |
| `request.protocol` | `request.protocol` | Protocol-specific behavior |
| `request.operation` | no direct Lua field | `authenticate`, `lookup_identity`, or `list_accounts` decisions |
| `request.time.now` | no direct Lua field | Time-window checks |

CIDR example:

```yaml
auth:
  policy:
    sets:
      networks:
        trusted_clients:
          - 10.0.0.0/8
          - 192.168.0.0/16
          - 2001:db8::/32

    policies:
      - name: permit_trusted_network
        stage: pre_auth
        if:
          attribute: request.client.ip
          cidr_contains: "@network.trusted_clients"
        then:
          decision: neutral
          reason: trusted_network
```

Protocol example:

```yaml
if:
  attribute: request.protocol
  eq: imap
```

Hostname fields from Lua request tables, such as `request.client_host`, are not built-in policy facts. If a policy needs them, emit a registered Lua policy attribute or export a selected backend result attribute.

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
      - name: lua_environment_geoip
        type: lua.environment
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        config_ref: auth.policy.attribute_sources.lua.environment.geoip

      - name: lua_environment_policy_gate
        type: lua.environment
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        after: [lua_environment_geoip]
        config_ref: auth.policy.attribute_sources.lua.environment.policy_gate

      - name: lua_subject_context_seed
        type: lua.subject
        stage: subject_analysis
        run_if:
          auth_state: authenticated
        config_ref: auth.policy.attribute_sources.lua.subject.context_seed

      - name: lua_subject_billing_lock
        type: lua.subject
        stage: subject_analysis
        after: [lua_subject_context_seed]
        run_if:
          auth_state: authenticated
        config_ref: auth.policy.attribute_sources.lua.subject.billing_lock
```

The check plan is authoritative for the configured Lua script family in the active operation and stage. A script without a matching check does not run in that request plan. If you configure no checks for a Lua script family, Nauthilus uses the built-in default scheduling for that family.

For Lua environment and subject sources, `standard_auth` maps the generated Lua facts to the built-in result:

- `auth.lua.environment.<name>.error` selects a temporary failure.
- `auth.lua.environment.<name>.triggered` selects a deny.
- `auth.lua.environment.<name>.abort` skips the remaining pre-auth checks for that stage.
- `auth.lua.subject.<name>.error` selects a temporary failure.
- `auth.lua.subject.<name>.rejected` selects a deny.

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

## Step 1: Define Lua Attribute Sources

Keep only the script identity and script path on environment and subject sources.

```yaml
auth:
  controls:
    enabled:
      - lua

  policy:
    attribute_sources:
      lua:
        environment:
          - name: geoip
            script_path: /etc/nauthilus/lua/environment/geoip.lua
          - name: policy_gate
            script_path: /etc/nauthilus/lua/environment/policy_gate.lua
        subject:
          - name: context_seed
            script_path: /etc/nauthilus/lua/subject/context_seed.lua
          - name: billing_lock
            script_path: /etc/nauthilus/lua/subject/billing_lock.lua
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

The `report` block is for diagnostics, not enforcement. Nauthilus builds request-local policy report data while evaluating a request; enabling report output lets you inspect the selected checks, attributes, policies, final decision, and observe-mode comparison in a redacted shape. It does not add fields to auth responses and it does not change `permit`, `deny`, `tempfail`, or `neutral`.

Use this while developing or debugging a policy:

```yaml
auth:
  policy:
    mode: observe
    report:
      enabled: true
      include_fsm: true
      include_checks: true
      include_attributes: true
```

Then turn `include_attributes` off again for normal operation unless you actively need emitted facts in report output. Redaction still applies, but attribute-heavy reports are larger and easier to over-collect.

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

      - name: lua_environment_geoip
        type: lua.environment
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        config_ref: auth.policy.attribute_sources.lua.environment.geoip
        output: checks.lua_environment_geoip

      - name: lua_environment_policy_gate
        type: lua.environment
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        after: [lua_environment_geoip]
        config_ref: auth.policy.attribute_sources.lua.environment.policy_gate
        output: checks.lua_environment_policy_gate
```

The check name can be your own stable name. The converter uses names such as `lua_environment_<script>` and `lua_subject_<script>` because they are predictable.

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

## Combine Conditions in `if`

Each policy has one `if` tree and one `then` block. Nesting happens inside `if`; `then` is a single decision output, not another condition branch.

Use `all`, `any`, and `not` to combine facts:

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

This reads as: deny only when either RBL or brute force is active, unless one of the relevant allowlist facts suppresses the decision.

Each condition object must contain exactly one expression node. Do not put `attribute` next to `all`, `any`, `not`, or `always` in the same object.

An attribute comparison is a leaf node and must contain exactly one operator. Do not write one condition with both `eq` and `ne`, or with `gte` and `lte`. Use `all` when a value must satisfy multiple comparisons:

```yaml
if:
  all:
    - attribute: auth.rbl.score
      gte: 5
    - attribute: auth.rbl.score
      lte: 20
```

For different outcomes, write multiple policies in the order they should win.

## Choose the `then` Output

Every policy rule has one `if` tree and one `then` block. The `if` tree answers "does this rule match?" The `then` block answers "what does that match do?"

Most rules only need a decision, a stable internal reason, and sometimes a response marker:

```yaml
then:
  decision: deny
  reason: billing_locked
  response_marker: auth.response.fail
```

Use the `then` keys this way:

| Key | Use it when |
|---|---|
| `decision` | Always. It is the actual policy effect: `neutral`, `deny`, `permit`, or `tempfail`. |
| `reason` | You want a stable internal reason for logs, reports, metrics, traces, or follow-up context. |
| `response_marker` | You need a specific response class, such as `auth.response.tempfail.no_tls`; otherwise the normal marker is derived from `decision`. |
| `response_message` | You need a specific client-visible message inside the selected response class. |
| `fsm_event_marker` | You need a specific FSM path such as `auth.fsm.event.auth_empty_pass`; otherwise the normal marker is derived from stage and decision. |
| `outcome_marker` | You need a stable namespaced outcome label for reports or tooling. |
| `obligations` | The selected decision must run registered enforcement work, such as synchronous Lua action dispatch, brute-force updates, or Lua POST-Action enqueueing. |
| `advice` | You want non-binding context for reporting or follow-up handling. |
| `control.skip_remaining_stage_checks` | A neutral pre-auth decision should stop later pre-auth checks without granting success. |

The common decision rules are:

| Stage | Good decisions | Avoid |
|---|---|---|
| `pre_auth` | `neutral`, `deny`, `tempfail` | `permit`, because pre-auth cannot authenticate a user. |
| `auth_decision` | `permit`, `deny`, `tempfail` | treating `neutral` as success. |

`response_message` has three forms:

```yaml
then:
  decision: deny
  response_marker: auth.response.fail
  response_message:
    from: default
```

```yaml
then:
  decision: deny
  response_marker: auth.response.fail
  response_message:
    from: literal
    text: "Account temporarily locked"
```

```yaml
then:
  decision: deny
  response_marker: auth.response.fail
  response_message:
    from: attribute_detail
    attribute: auth.lua.subject.billing_lock.rejected
    detail: status_message
    fallback: "Invalid login or password"
```

The `attribute_detail` form works only for registered public string details with `purpose: response_message`. Lua may emit such a candidate, but YAML must explicitly select it before it becomes client-visible.

Use obligations sparingly and only with registered IDs:

```yaml
then:
  decision: deny
  reason: brute_force_reject
  obligations:
    - id: auth.obligation.brute_force.update
    - id: auth.obligation.lua_action.dispatch
      args:
        action: brute_force
    - id: auth.obligation.lua_post_action.enqueue
      args:
        action: brute_force
```

Advice is softer than an obligation. It can enrich diagnostics or follow-up context, but it must not be required for correctness:

```yaml
then:
  decision: deny
  reason: blocked_country
  advice:
    - id: auth.advice.audit_reason
      args:
        reason: blocked_country
```

For pre-auth abort-style behavior, use neutral plus stage-local control:

```yaml
then:
  decision: neutral
  reason: control_aborted
  control:
    skip_remaining_stage_checks: true
```

That skips remaining checks in the current pre-auth stage. It does not permit the request and it does not skip final `auth_decision`.

## Understand Actions and POST-Actions

Do not treat every Lua side effect as an implicit mechanism behavior. Synchronous Lua action dispatch and Lua POST-Action enqueueing are policy-owned obligations in policy-authoritative paths.

The script definitions stay under `auth.policy.obligation_targets.lua.actions`. The selected policy decision decides whether an existing action runs:

| Action surface | Config action type | Obligation |
|---|---|---|
| Synchronous Lua action | `brute_force`, `lua`, `tls_encryption`, `relay_domains`, or `rbl` | `auth.obligation.lua_action.dispatch` |
| Lua POST-Action | `post` | `auth.obligation.lua_post_action.enqueue` |

Use `auth.obligation.lua_action.dispatch` with `args.action` set to one of `brute_force`, `lua`, `tls_encryption`, `relay_domains`, or `rbl`. For `action: lua`, also pass `args.feature` when you need feature-specific reports or learning context. The optional `args.wait` defaults to `true`; the current runtime preserves synchronous wait behavior.

For example, a custom RBL rejection that should keep the configured synchronous RBL action must say so:

```yaml
then:
  decision: deny
  reason: rbl_reject
  response_marker: auth.response.fail
  obligations:
    - id: auth.obligation.lua_action.dispatch
      args:
        action: rbl
```

For brute-force denials, add all three side-effect obligations if your custom policy replaces the built-in rule:

```yaml
then:
  decision: deny
  reason: brute_force_reject
  response_marker: auth.response.fail
  obligations:
    - id: auth.obligation.brute_force.update
    - id: auth.obligation.lua_action.dispatch
      args:
        action: brute_force
    - id: auth.obligation.lua_post_action.enqueue
      args:
        action: brute_force
```

This mirrors the built-in `standard_auth` brute-force denial. Without these obligations, a custom policy can still deny or tempfail, but it will not dispatch the synchronous Lua action, update brute-force state, or enqueue the POST-Action.

In `mode: observe`, custom policy obligations are reported but not executed. That keeps observe mode safe: no custom synchronous Lua action dispatch, no custom POST-Action enqueueing, no custom brute-force counter updates, and no custom learning side effects.

## Step 6: Define Start Order with `after`

Use `after` when one check needs request-local state or emitted facts from another check before it can run.

First define the scripts:

```yaml
auth:
  policy:
    attribute_sources:
      lua:
        subject:
          - name: context_seed
            script_path: /etc/nauthilus/lua/subject/context_seed.lua
          - name: billing_lock
            script_path: /etc/nauthilus/lua/subject/billing_lock.lua
```

Then define the check order:

```yaml
auth:
  policy:
    checks:
      - name: lua_subject_context_seed
        type: lua.subject
        stage: subject_analysis
        run_if:
          auth_state: authenticated
        config_ref: auth.policy.attribute_sources.lua.subject.context_seed
        output: checks.lua_subject_context_seed

      - name: lua_subject_billing_lock
        type: lua.subject
        stage: subject_analysis
        after: [lua_subject_context_seed]
        run_if:
          auth_state: authenticated
        config_ref: auth.policy.attribute_sources.lua.subject.billing_lock
        output: checks.lua_subject_billing_lock
```

`after` references check names, not script names. Dependencies must be scheduler-compatible: the dependency must be in the same stage and must cover the dependent check's operations and auth-state guard.

## Step 7: Write Policies for Pre-Auth Environment Sources

A Lua environment source can emit generated attributes:

- `auth.lua.environment.<name>.triggered`
- `auth.lua.environment.<name>.abort`
- `auth.lua.environment.<name>.error`

Use those attributes in policies.

```yaml
auth:
  policy:
    policies:
      - name: geoip_environment_error
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        require_checks: [lua_environment_geoip]
        if:
          attribute: auth.lua.environment.geoip.error
          is: true
        then:
          decision: tempfail
          reason: geoip_error
          response_marker: auth.response.tempfail

      - name: geoip_environment_deny
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        require_checks: [lua_environment_geoip]
        if:
          attribute: auth.lua.environment.geoip.triggered
          is: true
        then:
          decision: deny
          reason: geoip_blocked
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: auth.lua.environment.geoip.triggered
            detail: status_message
            fallback: "Invalid login or password"
```

For a Lua environment source that aborts later pre-auth checks but does not deny:

```yaml
- name: geoip_environment_abort
  stage: pre_auth
  operations: [authenticate, lookup_identity]
  require_checks: [lua_environment_geoip]
  if:
    attribute: auth.lua.environment.geoip.abort
    is: true
  then:
    decision: neutral
    reason: geoip_aborted_pre_auth
    control:
      skip_remaining_stage_checks: true
```

Do not use `permit` in `pre_auth`. Pre-auth controls can deny, tempfail, or let the request continue.

## Step 8: Write Policies for Backend and Lua Subject Sources

Backends produce final auth facts:

- `auth.authenticated`
- `auth.identity.found`
- `auth.backend.tempfail`
- `auth.backend.empty_username`
- `auth.backend.empty_password`

Lua subject sources produce generated attributes:

- `auth.lua.subject.<name>.rejected`
- `auth.lua.subject.<name>.error`

Example:

```yaml
auth:
  policy:
    policies:
      - name: billing_subject_error
        stage: auth_decision
        require_checks: [lua_subject_billing_lock]
        if:
          attribute: auth.lua.subject.billing_lock.error
          is: true
        then:
          decision: tempfail
          reason: billing_subject_error
          response_marker: auth.response.tempfail

      - name: billing_subject_reject
        stage: auth_decision
        require_checks: [lua_subject_billing_lock]
        if:
          attribute: auth.lua.subject.billing_lock.rejected
          is: true
        then:
          decision: deny
          reason: billing_locked
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: auth.lua.subject.billing_lock.rejected
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

## Model Multiple Brute-Force Buckets

Brute-force protection can have more than one configured bucket. Nauthilus exposes both global summary facts and generated per-bucket facts so a policy can combine bucket states explicitly.

Bucket names are normalized into policy identifier segments. For example:

| Bucket name | Policy segment |
|---|---|
| `IMAP Short` | `imap_short` |
| `SMTP/Auth Burst` | `smtp_auth_burst` |
| `24h` | `b_24h` |

If two bucket names normalize to the same segment, the policy snapshot is rejected. This keeps generated policy attributes stable.

```yaml
auth:
  controls:
    brute_force:
      buckets:
        - name: "IMAP Short"
          period: 10m
          ban_time: 1h
          cidr: 32
          ipv4: true
          ipv6: false
          failed_requests: 5
        - name: "IMAP Long"
          period: 24h
          ban_time: 8h
          cidr: 24
          ipv4: true
          ipv6: false
          failed_requests: 25

  policy:
    checks:
      - name: brute_force
        type: builtin.brute_force
        stage: pre_auth
        config_ref: auth.controls.brute_force

    policies:
      - name: imap_bucket_pressure
        stage: pre_auth
        require_checks: [brute_force]
        if:
          all:
            - attribute: auth.brute_force.bucket.imap_short.ratio
              gte: 0.8
            - attribute: auth.brute_force.bucket.imap_long.already_banned
              is: false
            - attribute: auth.brute_force.rwp.active
              is: false
        then:
          decision: deny
          reason: brute_force_bucket_pressure
          response_marker: auth.response.fail

      - name: imap_multi_bucket_repeat
        stage: pre_auth
        require_checks: [brute_force]
        if:
          any:
            - attribute: auth.brute_force.bucket.imap_short.over_limit
              is: true
            - all:
                - attribute: auth.brute_force.bucket.imap_long.ratio
                  gte: 0.7
                - attribute: auth.brute_force.bucket.imap_short.repeating
                  is: true
        then:
          decision: deny
          reason: brute_force_repeating_bucket_state
          response_marker: auth.response.fail
```

The most useful global attributes are:

- `auth.brute_force.triggered`: the final built-in block status.
- `auth.brute_force.repeating`: whether any selected bucket indicates a repeating state.
- `auth.brute_force.rwp.active`: whether the repeating-wrong-password protection tolerated the attempt and prevented bucket increments.
- `auth.brute_force.rwp.enforce_bucket_update`: inverse of `rwp.active`; useful when a policy should only act on attempts that update buckets.
- `auth.brute_force.toleration.active`: whether reputation toleration currently applies.
- `auth.brute_force.toleration.mode`: `static`, `adaptive`, or `disabled`.
- `auth.brute_force.toleration.suppressed_block`: whether toleration prevented a brute-force block after a bucket matched.
- `auth.brute_force.bucket.matched_count`: number of buckets that matched the request context.
- `auth.brute_force.bucket.triggered_count`: number of buckets that are over limit or already banned.
- `auth.brute_force.bucket.max_ratio`: highest bucket fill ratio for the request.

## Model RBL Facts

RBL checks expose aggregate score facts and generated per-list facts. List names are normalized just like brute-force bucket names.

```yaml
auth:
  controls:
    rbl:
      threshold: 5
      lists:
        - name: "Zen Spamhaus"
          rbl: zen.spamhaus.org
          return_codes: [127.0.0.2]
          ipv4: true
          ipv6: false
          weight: 5

  policy:
    checks:
      - name: rbl
        type: builtin.rbl
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        config_ref: auth.controls.rbl

    policies:
      - name: deny_zen_match
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        require_checks: [rbl]
        if:
          any:
            - attribute: auth.rbl.threshold_reached
              is: true
            - all:
                - attribute: auth.rbl.list.zen_spamhaus.listed
                  is: true
                - attribute: auth.rbl.score
                  gte: 5
        then:
          decision: deny
          reason: rbl_match
          response_marker: auth.response.fail
```

Useful RBL attributes:

- `auth.rbl.score`: aggregate score for the request.
- `auth.rbl.threshold`: configured rejection threshold.
- `auth.rbl.matched_count`: number of matched lists.
- `auth.rbl.matched_lists`: string list of matched RBL names.
- `auth.rbl.allow_failure_error_count`: lookup errors ignored because the list allows failure.
- `auth.rbl.effective_error`: lookup error that affects the decision.
- `auth.rbl.soft_allowlisted` and `auth.rbl.ip_allowlisted`: whitelist handling.
- `auth.rbl.list.<list>.listed`, `.weight`, `.error`, `.allow_failure`: per-list facts.

## Model Relay-Domain Facts

Relay-domain checks expose the parsed domain value, the static-domain match state, and soft-allowlist state.

```yaml
auth:
  policy:
    checks:
      - name: relay_domains
        type: builtin.relay_domains
        stage: pre_auth
        config_ref: auth.controls.relay_domains

    policies:
      - name: reject_external_relay_domain
        stage: pre_auth
        require_checks: [relay_domains]
        if:
          all:
            - attribute: auth.relay_domain.present
              is: true
            - attribute: auth.relay_domain.known
              is: false
            - attribute: auth.relay_domain.soft_allowlisted
              is: false
        then:
          decision: deny
          reason: relay_domain_rejected
          response_marker: auth.response.fail
```

Useful relay-domain attributes:

- `auth.relay_domain.value`: parsed domain from the username.
- `auth.relay_domain.present`: username contained a valid domain part.
- `auth.relay_domain.known`: the domain matched the configured static domain list.
- `auth.relay_domain.rejected`: the built-in relay-domain control rejected the request.
- `auth.relay_domain.static_match`: a static domain matched.
- `auth.relay_domain.soft_allowlisted`: soft allowlist suppressed the check.
- `auth.relay_domain.configured_count`: number of configured static domains.

## Export Backend Attributes

Use backend attribute exports when LDAP or Lua backends return account facts that should drive policy decisions.

```yaml
auth:
  policy:
    attribute_exports:
      - name: account_status
        attribute: accountStatus
        type: string

      - name: entitlements
        attribute: entitlements
        type: string_list

    checks:
      - name: ldap_backend
        type: backend.ldap
        stage: auth_backend
        operations: [authenticate, lookup_identity]
        config_ref: auth.backends.ldap

    policies:
      - name: deny_locked_account
        stage: auth_decision
        operations: [authenticate, lookup_identity]
        if:
          attribute: auth.subject.attribute.account_status
          detail: value
          eq: locked
        then:
          decision: deny
          reason: account_locked
          response_marker: auth.response.fail

      - name: permit_imap_entitlement
        stage: auth_decision
        operations: [authenticate]
        if:
          all:
            - attribute: auth.authenticated
              is: true
            - attribute: auth.subject.attribute.entitlements
              detail: values
              contains: imap
        then:
          decision: permit
          reason: imap_entitled
          response_marker: auth.response.ok
```

The generated `auth.subject.attribute.<name>` attribute is a boolean presence fact. Scalar exports put the typed value into the `value` detail. `string_list` exports put the list into the `values` detail. Export only fields you actually want as policy material; backend attributes are otherwise kept out of the policy registry.

## Complete Example

This example expresses a common setup explicitly:

- brute force blocks normal password auth
- TLS is required for password auth and identity lookup
- two Lua environment sources run before backend auth, with one ordered after the other
- LDAP backend facts decide final auth and lookup behavior
- two Lua subject sources run after successful backend auth, ordered through `after`
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
      buckets:
        - name: login_rule
          period: 10m
          ban_time: 4h
          cidr: 24
          ipv4: true
          ipv6: false
          failed_requests: 5

    tls_encryption:
      allow_cleartext_networks:
        - 127.0.0.0/8

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

    attribute_sources:
      lua:
        environment:
          - name: geoip
            script_path: /etc/nauthilus/lua/environment/geoip.lua
          - name: policy_gate
            script_path: /etc/nauthilus/lua/environment/policy_gate.lua
        subject:
          - name: context_seed
            script_path: /etc/nauthilus/lua/subject/context_seed.lua
          - name: billing_lock
            script_path: /etc/nauthilus/lua/subject/billing_lock.lua

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

      - name: lua_environment_geoip
        type: lua.environment
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        config_ref: auth.policy.attribute_sources.lua.environment.geoip
        output: checks.lua_environment_geoip

      - name: lua_environment_policy_gate
        type: lua.environment
        stage: pre_auth
        operations: [authenticate, lookup_identity]
        after: [lua_environment_geoip]
        config_ref: auth.policy.attribute_sources.lua.environment.policy_gate
        output: checks.lua_environment_policy_gate

      - name: ldap_backend
        type: backend.ldap
        stage: auth_backend
        operations: [authenticate, lookup_identity]
        config_ref: auth.backends.ldap
        output: checks.ldap_backend

      - name: lua_subject_context_seed
        type: lua.subject
        stage: subject_analysis
        run_if:
          auth_state: authenticated
        config_ref: auth.policy.attribute_sources.lua.subject.context_seed
        output: checks.lua_subject_context_seed

      - name: lua_subject_billing_lock
        type: lua.subject
        stage: subject_analysis
        after: [lua_subject_context_seed]
        run_if:
          auth_state: authenticated
        config_ref: auth.policy.attribute_sources.lua.subject.billing_lock
        output: checks.lua_subject_billing_lock

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
        require_checks: [lua_environment_policy_gate]
        if:
          attribute: auth.lua.environment.policy_gate.triggered
          is: true
        then:
          decision: deny
          reason: policy_gate
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: auth.lua.environment.policy_gate.triggered
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
        require_checks: [lua_subject_billing_lock]
        if:
          attribute: auth.lua.subject.billing_lock.rejected
          is: true
        then:
          decision: deny
          reason: billing_locked
          response_marker: auth.response.fail
          response_message:
            from: attribute_detail
            attribute: auth.lua.subject.billing_lock.rejected
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

Generated Lua environment and subject source attributes are enough for trigger, abort, reject, error, and status-message behavior. Use a registry script when Lua needs to expose custom facts.

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
  require_checks: [lua_environment_geoip]
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

Unknown keys on Lua environment or subject source entries:

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
