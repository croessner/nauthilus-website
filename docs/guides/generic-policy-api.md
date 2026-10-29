---
title: Operating the Generic Policy API
description: Configure, call, observe, and troubleshoot the protected unary Policy decision service
keywords: [Policy, REST API, Authorization, Decisions, Obligations, Observability]
sidebar_position: 4
---

# Operating the Generic Policy API

Nauthilus v4 exposes one generic, protected Policy operation:

```text
POST /api/v1/policy/decisions
Content-Type: application/json
Cache-Control: no-store
```

One request evaluates one admitted resource against one qualified target and one schema version. Lists and record lists
are facts inside that request; the endpoint is not a batch API. It has no result cache, retry endpoint, replay control,
idempotency endpoint, or outcome-reporting API.

The authoritative wire contract is the Nauthilus v4 OpenAPI document. The generated website API pages may temporarily
lag that source; use this guide together with the exact OpenAPI artifact shipped by the
Nauthilus build you deploy.

## Enable the protected route

The route, limits, credentials, grants, schemas, providers, policies, and target bindings are committed as one Policy
generation. A failed startup or reload candidate leaves the previous complete generation active.

```yaml
policy:
  api:
    enabled: true
    http:
      enabled: true
    grpc:
      enabled: false
    limits:
      provider_timeout: 500ms
      evaluation_timeout: 2s
      max_request_bytes: 1048576
      max_facts: 512
      max_string_bytes: 4096
      max_list_items: 128
      max_value_bytes: 65536
      per_client_concurrency: 8
      per_client_requests_per_second: 25
      max_obligations: 32
      max_advice: 32
      max_parameter_bytes: 16384
    clients:
      - principal: mail-policy-adapter
        authentication_kinds: [basic]
        authentication:
          basic:
            username: mail-policy-adapter
            password: ${POLICY_BASIC_PASSWORD}
        targets:
          - namespace: mail
            actions: [accept-message]
        allowed_schemas: [mail/accept-message/v1]
        allowed_subject_attributes: []
        allowed_resource_attributes: [message_size, sender_class]
        allowed_environment_attributes: [service.risk]
        allowed_input_attributes: [tenant]
        max_request_bytes: 131072
        max_facts: 64
        max_concurrency: 2
        requests_per_second: 5
        diagnostics: false
        require_mtls: false
```

The client profile is an admission boundary, not merely a credential entry. Its target/action, schema, fact allowlists,
diagnostics permission, request limits, rate, concurrency, and optional mTLS requirement must all admit the request.
Effective per-client limits cannot widen the global limits.

See [Policy Configuration](../configuration/auth-policy.md) for namespace, schema, provider, domain-plan, policy-set, and
target configuration, and the [manual migration contract](policy-configuration-migration.md) for the v3 hard cut.

## Authentication

Policy credentials are a separate resource family from management and backchannel credentials.

### Bearer tokens

A Policy Bearer token must have all of the following:

- exact audience `nauthilus:policy`;
- scope `nauthilus:policy_evaluate`;
- an issuer-owned `client_id` equal to the admitted `policy.api.clients[].principal`;
- scope `nauthilus:policy_diagnostics` as well when diagnostics are requested;
- any mTLS binding required by the client profile and transport.

A token for audience `nauthilus:backchannel`, an ID token, or a management credential is not accepted. Issue, cache,
rotate, and revoke Policy tokens independently.

```bash
curl --fail-with-body \
  --request POST \
  --header "Authorization: Bearer ${POLICY_ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data @policy-request.json \
  https://nauthilus.example/api/v1/policy/decisions
```

### Policy Basic

Policy Basic is enabled only by an admitted Policy client profile. It never falls back to management Basic. Use it only
over the protected HTTPS boundary and keep the password in the caller's secret store. A wrong Policy-Basic password is answered after a fixed
300 ms delay and logged at warning level without credentials. Callers are never locked out, and verification uses only
the active generation's credentials, so it does not depend on Redis.

```bash
curl --fail-with-body \
  --request POST \
  --user "${POLICY_BASIC_USERNAME}:${POLICY_BASIC_PASSWORD}" \
  --header 'Content-Type: application/json' \
  --data @policy-request.json \
  https://nauthilus.example/api/v1/policy/decisions
```

## Request contract

The body is a closed JSON object. Unknown fields and malformed typed values are rejected.

```json
{
  "version": "1",
  "request_id": "019d10c4-3858-7c2a-a5d1-2b3d57e641f2",
  "target": {
    "namespace": "mail",
    "action": "accept-message"
  },
  "resource": {
    "type": "mail-message",
    "id": "opaque-message-reference",
    "attributes": {
      "message_size": {"integer": "48312"},
      "sender_class": {"string": "external"}
    }
  },
  "environment": {
    "service": "mail-filter",
    "instance": "mx01.example.net",
    "protocol": "milter",
    "attributes": {
      "service.risk": {"double": 0.25}
    }
  },
  "attributes": {
    "tenant": {"string": "example"}
  },
  "options": {
    "include_diagnostics": false
  }
}
```

| Member | Contract |
| --- | --- |
| `version` | Required and exactly `"1"`. |
| `request_id` | Optional opaque correlation value, at most 128 bytes. Nauthilus generates one when omitted and returns the effective value. It is not an idempotency key. |
| `target` | Required `namespace` and `action`, each at most 64 bytes. The admitted target selects its schema and Policy generation. |
| `subject` | Optional typed entity with `type`, `id`, and attributes. Send it only when the caller has an independently authenticated subject. |
| `resource` | Optional typed entity representing the object being evaluated. |
| `environment` | Optional service, instance, protocol, and environment attributes. |
| `attributes` | Optional general input attributes admitted by `allowed_input_attributes`. |
| `options.include_diagnostics` | Optional boolean. Release requires both credential scope and profile permission. |

Each value wrapper contains exactly one of `string`, `boolean`, `integer`, `double`, `strings`, `bytes`, `timestamp`, or
`records`. Integers are canonical signed decimal strings. Bytes are Base64, timestamps use RFC 3339, and doubles must
be finite. A record list is ordered and non-recursive:

```json
{
  "records": [
    {
      "fields": [
        {"name": "sequence", "value": {"integer": "1"}},
        {"name": "state", "value": {"string": "trusted"}}
      ]
    }
  ]
}
```

The configured target schema owns type, provenance, sensitivity, required fields, closed vocabularies, and tighter
scalar/list/record bounds. Caller-owned facts cannot impersonate provider-owned facts. Malformed and
schema-incompatible collections are rejected. In record predicates, a missing collection makes every quantifier false
and a present empty collection makes `any` false but `all`/`none` true, so permit-sensitive schemas declare
`min_records: 1`; see [record predicates](../configuration/auth-policy.md#record-predicates).

## Response contract

A completed evaluation returns HTTP `200`, including a safely constructed `indeterminate` result:

```json
{
  "request_id": "019d10c4-3858-7c2a-a5d1-2b3d57e641f2",
  "decision_id": "019d10c4-b216-7bb2-99ee-813ac82bf124",
  "effect": "permit",
  "status": {
    "code": "ok",
    "message": "policy evaluation completed",
    "retryable": false
  },
  "obligations": [],
  "advice": []
}
```

The response object always includes `request_id`, `decision_id`, `effect`, and `status`. `status` always includes
`code`, `message`, and `retryable`, with optional bounded validation `details`. `status.code` is one of `permit`,
`policy_denied`, `not_applicable`, `no_applicable_rule`, `no_match_deny`, `evaluation_failed`, `provider_unavailable`,
`effect_outcome_unknown`, `effect_outcome_unknown_replay_safe`, `effect_replay_unsafe`, or
`effect_acceptance_rejected`. The effect vocabulary is:

| Effect | Caller interpretation |
| --- | --- |
| `permit` | The configured policy permits the requested action. It does not override a stricter authority outside Nauthilus. |
| `deny` | Reject the requested action. Do not retry unchanged input as a technical recovery. |
| `not_applicable` | No applicable policy produced a permit or deny. The caller's explicit local contract must decide whether this is terminal; never treat it as permit implicitly. |
| `indeterminate` | Nauthilus could not produce a permit/deny result. Honor `status.retryable`; never treat it as permit. |

`obligations` and `advice` are arrays of `{id, parameters}`. Parameters use the scalar response wrappers and never
contain record lists. An obligation is mandatory for a caller that claims to support it; reject or fail safely when an
unknown or failed obligation would make the decision incomplete. Advice may be ignored without changing the decision.
Adapters with no negotiated obligation contract should require an empty obligations array rather than accepting
unknown work.

Diagnostics are omitted by default. They appear only when the request opts in, the Bearer token has
`nauthilus:policy_diagnostics`, and the client profile has `diagnostics: true`. Public entries use configured aliases
and bounded reason classes; protected fact values and arbitrary record fields are not released.

## HTTP errors

Non-`200` responses use a closed error object with `code`, `message`, and optional bounded `details`:

| Status | Meaning | Typical operator action |
| ---: | --- | --- |
| `400` | Strict JSON, typed-value, target, or public-field validation failed. | Correct the request; do not retry it unchanged. |
| `401` | Policy credentials are missing, malformed, expired, or rejected. | Repair the Policy-specific credential; do not substitute management credentials. |
| `403` | The authenticated principal is not admitted for the target, schema, facts, diagnostics, or mTLS boundary. | Compare the exact client profile and request. |
| `413` | Body, fact, value, list, record, or aggregate admitted limit was exceeded. | Reduce the bounded request before considering any limit change. |
| `415` | The endpoint did not receive `application/json`. | Send the exact media type. |
| `429` | Per-client concurrency or request-rate limit was exceeded. | Back off with bounded jitter; inspect capacity and caller fan-out. |
| `503` | The service was unavailable before evaluation began. | Check the active generation, dependencies, and shutdown state; retry only under the caller's bounded policy. |

Transport failure, TLS failure, a malformed success body, an unknown effect, or an unsupported obligation is a caller-
side technical failure even if an intermediary returned HTTP `200`.

## Effects and failure semantics

Provider or evaluation failures can produce a retryable or non-retryable `indeterminate`. A synchronous effect failure
prevents a successful decision response. Post-action acceptance failure prevents finalization, while an accepted
post-action that later fails cannot change the already returned decision.

The host attempts each selected effect ordinal at most once. It provides no automatic retry, deduplication, or outcome
query. Retry guidance depends on the replay safety each native effect declares in its descriptor (`unsafe` or
`idempotent` with an exact caller-owned key fact); Lua effects are always `unsafe`:

| `status.code` | `retryable` | Meaning and caller action |
| --- | --- | --- |
| `effect_outcome_unknown` | `false` | An unsafe external dispatch may have happened. Reconcile the destination using the Decision ID and the provider-owned domain identity before another domain action; never assume absence. |
| `effect_outcome_unknown_replay_safe` | `true` | The outcome is unknown, but every attempted effect declared idempotence. Retry the complete identical request with the same payload and the original idempotency key values. |
| `effect_replay_unsafe` | `false` | A non-idempotent effect already completed or was accepted before a later failure. Reconcile the partial execution; do not repeat the request. |
| `effect_acceptance_rejected` | `true` | A mandatory post-action was not accepted before finalization. Repair supervisor capacity or shutdown state. |

An idempotent effect requires its key fact as a required caller-owned string of at most 128 bytes in every selected
target schema. A request without a non-empty key value is rejected before the provider runs.

## gRPC `Evaluate`

The same generation-backed Decision Service is available as one unary protobuf method when `policy.api.grpc.enabled` is
true:

```text
package: nauthilus.policy.v1
service: PolicyDecisionService
method: Evaluate(DecisionRequest) returns (DecisionResponse)
full method: /nauthilus.policy.v1.PolicyDecisionService/Evaluate
```

The public source contract is `api/policy/v1/policy.proto`, with Go package
`github.com/croessner/nauthilus/v4/api/policy/v1`. Field numbers and service/method identities remain wire-stable across
the v3-to-v4 module-path change; generated Go imports must move to `/v4`.

Supply exactly one lowercase `authorization` metadata value using `Bearer <token>` or
`Basic <base64(username:password)>`. The credential, audience, scope, principal, grants, profile limits, and diagnostic
rules are identical to HTTP. gRPC mTLS is corroborating transport identity, never a credential by itself. When
`policy.api.grpc.require_mtls` or the client profile requires it, the verified client identity must match the admitted
principal.

The protobuf value union corresponds to the JSON wrappers. Protobuf integers use `sint64`; `StringList`, `RecordList`,
ordered `Record.fields`, bytes, and timestamps preserve the same semantic types. Record fields are non-recursive, and
unknown protobuf fields anywhere in the request are rejected rather than ignored.

Important gRPC status mappings are:

| gRPC code | Meaning |
| --- | --- |
| `InvalidArgument` | Invalid request or typed value. |
| `Unauthenticated` | Missing or rejected Policy credentials. |
| `PermissionDenied` | Authenticated caller not admitted for the request. |
| `ResourceExhausted` | Wire, fact, rate, concurrency, or admitted limit exceeded. |
| `Unimplemented` | Policy gRPC route disabled. |
| `Unavailable` | Generation or service dependency unavailable. |
| `Canceled` / `DeadlineExceeded` | Caller cancellation or deadline. |

A successful RPC returns the same effect/status/obligation/advice/diagnostic meaning and both correlation IDs as HTTP.
The unary return is the post-action acceptance boundary; a later asynchronous failure cannot alter the returned
message. Use a deadline shorter than the caller's enclosing protocol deadline and never retry an ambiguous external
effect automatically.

## Observability and privacy

Every evaluation reaching the shared service path uses:

- span name `nauthilus.policy.evaluate`;
- correlation fields `nauthilus.policy.request_id` and `nauthilus.policy.decision_id` in bounded logs, controlled audit,
  and traces;
- counter `nauthilus_policy_service_decisions_total` with only `namespace`, `action`, `transport`, `effect`,
  `status_code`, and `result_class` labels.

Request IDs, Decision IDs, principals, IP addresses, domains, generations, dynamic facts, and provider text are not
metric labels. Credentials, raw mail/envelope content, exact recipes, protected records, and dependency responses must
not enter ordinary logs, traces, metrics, diagnostics, reports, or error bodies. Controlled-audit export and retention
remain operator-owned.

## Rollout and verification

1. Prepare and validate the complete top-level `policy` generation offline.
2. Verify exact credentials, audience/scope, principal, target/action/schema, fact allowlists, limits, and mTLS setting.
3. Deploy the candidate and confirm that an invalid reload leaves the previous generation active.
4. Exercise one permit, one deny, one retryable failure, one non-retryable failure, and rate/concurrency rejection.
5. Prove diagnostics denial without authority and bounded release with authority.
6. Correlate the returned Request and Decision IDs through logs, controlled audit, and the Policy span.
7. Test every caller's handling of unknown effects, unsupported obligations, malformed JSON, timeout, and TLS failure.
8. For external side effects, test reconciliation and prove that the caller does not replay automatically.

For the concrete mail-filter consumer, see [DKIM2/Rspamd Generic Policy Integration](dkim2-rspamd-policy.md).
