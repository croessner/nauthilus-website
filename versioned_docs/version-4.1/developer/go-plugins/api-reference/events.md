---
title: Host Event Sinks
description: AuthEvent and BruteForceEvent sinks, their optional registrars, delivery lanes, and event fields
keywords: [AuthEvent, AuthEventSink, BruteForceEvent, BruteForceEventSink, Go plugin API]
sidebar_position: 5.5
---

# Host Event Sinks

Since Nauthilus 4.1.0 a native plugin can observe bounded, secret-free events that the host records at its own decision
points: second-factor verifications and OIDC authorization-code steps (`AuthEvent`), and brute-force counting and ban
lifecycle transitions (`BruteForceEvent`). Sinks are diagnostic consumers. They never influence a request, a decision,
or a ban, and the host never lets a sink delay an authentication request.

Both registrars are optional, additive interfaces of the `Registrar` passed to `Register`. Assert them the same way as
`DecisionRegistrar` and keep working when the host does not implement them:

```go
func (p *Plugin) Register(registrar pluginapi.Registrar) error {
    if events, ok := registrar.(pluginapi.BruteForceEventRegistrar); ok {
        if err := events.RegisterBruteForceEventSink(p.bruteForceSink); err != nil {
            return err
        }
    }

    if events, ok := registrar.(pluginapi.AuthEventRegistrar); ok {
        return events.RegisterAuthEventSink(p.authEventSink)
    }

    return nil
}
```

`Name` follows component-name validation. A nil sink, an invalid name, and a duplicate qualified name are rejected like
every other component. No capability is required.

## Delivery

The host enqueues every event on a bounded per-process lane and delivers it to every registered sink of that kind from
one lane goroutine, never on a request goroutine. Emitting never blocks: a full or stopped lane drops the event.

| Lane | Events | Capacity |
| --- | --- | --- |
| `mfa` | `AuthEvent` of type `mfa.verification` | 1024 |
| `oidc_completion` | `AuthEvent` of the OIDC code types | 1024 |
| `bruteforce_lifecycle` | `ban_activated`, `ban_activation_unconfirmed`, `ban_released`, `counters_reset` | 1024 |
| `bruteforce_counted` | `counted`, `threshold_tolerated` | 8192 |
| `bruteforce_hits` | `ban_hit` | 4096 |

The separate lanes keep frequent events from evicting rare ones: silent SSO renewals cannot push out second-factor
evidence, and a flood of ban hits during an attack cannot push out ban activations. Each call gets a context with a
2-second deadline and runs behind the host panic boundary; a returned error or recovered panic counts as a failed
delivery and is not retried. On shutdown the host stops intake and drains queued events before sinks stop.

`plugin_auth_events_total{outcome,lane}` counts `queued`, `dropped`, `delivered`, and `failed` per lane. A lane exists
only while at least one sink of its kind is registered; without such a sink nothing is queued or counted, and the
brute-force decision points build no events at all.

## `AuthEvent`

```go
type AuthEventSink interface {
    Name() string
    ObserveAuthEvent(context.Context, AuthEvent) error
}

type AuthEventRegistrar interface {
    RegisterAuthEventSink(AuthEventSink) error
}

type AuthEvent struct {
    ObservedAt   time.Time
    EventID      string
    RequestID    string
    FlowRef      string
    Protocol     string
    ClientID     string
    SAMLEntityID string
    Account      string
    ClientIP     string
    FactorRole   string
    Method       string
    Reason       string
    Type         AuthEventType
    Result       AuthEventResult
    FlowEffect   AuthEventFlowEffect
    Version      uint16
    FailLatched  bool
}
```

`ObserveAuthEvent` must only enqueue and return quickly. Events never contain passwords, hashes, OTP values, recovery
codes, authorization codes, PKCE verifiers, tokens, cookies, authorizing handles, or WebAuthn payloads.

| Field | Meaning |
| --- | --- |
| `ObservedAt` | UTC time the host observed the step. |
| `EventID` | Random 32-hex-character event identity. |
| `RequestID` | Request correlation ID of the HTTP request that observed the step. |
| `FlowRef` | Non-authorizing digest of the IdP browser flow. It joins events of one flow with the password request (`IDPInfo.FlowRef`) and never equals a flow handle. |
| `Protocol` | Protocol of the parent flow, for example `oidc` or `saml`; `account` for step-ups that protect self-service; `oidc` for code events. |
| `ClientID`, `SAMLEntityID` | Client of the parent OIDC or SAML flow, when known. |
| `Account` | Account the step belongs to. |
| `ClientIP` | Requester address. Empty on code redemptions, which the client's back end performs. |
| `FactorRole` | `second_factor` (`AuthEventFactorRoleSecond`) on MFA events. |
| `Method` | MFA method: `totp`, `webauthn`, or `recovery_codes`. |
| `Reason` | Stable reason code, see below. |
| `Version` | Contract version of the event type: `AuthEventVersion` (`1`) for `mfa.verification`, `AuthEventOIDCCodeVersion` (`1`) for both code types. |
| `FailLatched` | The flow's primary step had already failed; a verified factor cannot turn it into a success. |

### Types and results

| `AuthEventType` | Value | Emitted |
| --- | --- | --- |
| `AuthEventMFAVerification` | `mfa.verification` | For every observed second-factor verification attempt. |
| `AuthEventOIDCCodeIssuance` | `oidc.code_issuance` | After an authorization code was handed to the browser for the client's redirect URI. |
| `AuthEventOIDCCodeRedemption` | `oidc.code_redemption` | After a code was consumed at the token endpoint, successful or not. Token requests that cannot be attributed to an issued code emit nothing. |

`AuthEventType.Completion()` reports whether a type belongs to the OIDC code completion evidence. Version 1 of the
code types defines that an issued code cannot be redeemed later than ten minutes after its issuance event.

| `AuthEventResult` | Value | Meaning |
| --- | --- | --- |
| `AuthEventSuccess` | `success` | Factor verified, code issued, or tokens issued. |
| `AuthEventInvalid` | `invalid` | The submitted factor did not verify. |
| `AuthEventError` | `error` | A technical failure prevented verification or token issuance. |
| `AuthEventRateLimited` | `rate_limited` | The attempt budget rejected the attempt. |
| `AuthEventRejected` | `rejected` | The factor verified but the flow could not complete, or the redemption was refused. |

| `AuthEventFlowEffect` | Value | Meaning |
| --- | --- | --- |
| `AuthEventFlowNone` | `none` | The event changed nothing in the flow. |
| `AuthEventFlowStepUpCompleted` | `step_up_completed` | A step-up completed. |
| `AuthEventFlowPrimaryFailureKept` | `primary_failure_kept` | A factor verified on a flow whose primary step had already failed. |
| `AuthEventFlowCodeIssued` | `code_issued` | A code was handed to the browser. |
| `AuthEventFlowTokensIssued` | `tokens_issued` | A redeemed code's token response was handed to the transport. |
| `AuthEventFlowCodeConsumed` | `code_consumed` | A rejected or failed redemption consumed the code; the flow cannot complete. |

The current `Reason` values are `verified`, `invalid_code`, `assertion_rejected`, `ceremony_unavailable`,
`attempt_limit`, `attempt_store_error`, `verifier_error`, `state_error`, `step_up_conflict`, `step_up_expired`, and
`resume_conflict` for MFA events; `authenticated_in_flow`, `existing_session`, or `not_recorded` (a flow written by a
release that did not record the source) for code issuance; and `tokens_issued`, `client_mismatch`,
`redirect_uri_mismatch`, `pkce_mismatch`, `invalid_target`, `token_issue_error`, and `client_state_error` for code
redemption. Treat unknown values as opaque.

## `BruteForceEvent`

```go
type BruteForceEventSink interface {
    Name() string
    ObserveBruteForceEvent(context.Context, BruteForceEvent) error
}

type BruteForceEventRegistrar interface {
    RegisterBruteForceEventSink(BruteForceEventSink) error
}
```

`ObserveBruteForceEvent` runs on a host lane goroutine and must return within the deadline of the passed context. A
sink may flush a full batch inline as long as it honours that deadline. `BruteForceEventVersion` is `1`.

Events never contain passwords, password hashes, or repeating-wrong-password state. Pointer fields are `nil` when the
value was not known at the decision point.

### Kinds

| `BruteForceEventKind` | Value | Emitted when |
| --- | --- | --- |
| `BruteForceCounted` | `counted` | A bucket counter increment was really applied. |
| `BruteForceThresholdTolerated` | `threshold_tolerated` | A bucket was over its limit, but toleration suppressed the ban. |
| `BruteForceBanHit` | `ban_hit` | An existing ban rejected a request. |
| `BruteForceBanActivated` | `ban_activated` | This host wrote a new ban. |
| `BruteForceBanActivationUnconfirmed` | `ban_activation_unconfirmed` | A ban exists although this host could not confirm writing it. |
| `BruteForceBanReleased` | `ban_released` | An administrative flush removed a ban. |
| `BruteForceCountersReset` | `counters_reset` | An administrative flush removed bucket counters. |

`BruteForceEventKind.Lifecycle()` is true for the four rare ban lifecycle kinds, which never compete with the volume
kinds for queue space. Bans created before a sink was registered have no activation event.

### Fields

| Field | Meaning |
| --- | --- |
| `ObservedAt`, `EventID`, `Version`, `Kind` | UTC observation time (the activation time for activations), random 32-hex-character identity, contract version, and kind. |
| `RequestID` | Request correlation ID; for administrative kinds the ID of the flush request. |
| `ClientIP`, `Protocol`, `OIDCClientID` | Request values on request-driven kinds. |
| `Rule`, `RuleFingerprint` | Bucket rule name and a 32-hex-character digest of its definition (name, period, CIDR, limit, address families, protocol and OIDC client filters, ban time), so a changed rule with the same name is recognizable. |
| `PeriodSeconds`, `BanTimeSeconds`, `FailedRequests`, `CIDR` | Rule parameters. |
| `Network`, `IPFamily` | Banned or counted network and its family (`4` or `6`). |
| `BucketID`, `BucketProtocol`, `BucketOIDCClient` | 32-hex-character digest of the bucket key and the bucket's protocol and OIDC client scope. |
| `WindowIndex`, `Weight`, `Current`, `Previous`, `Total`, `Limit` | Sliding-window state that fed the decision: window index, weight of the previous window, current and previous window counts, weighted total, and the applied limit. |
| `Crossed` | On `counted`: this increment moved the total over the limit. |
| `BanActive` | The request hit an existing ban; always true on `ban_hit`. |
| `ClaimedUsername` | Login name as entered, on volume kinds only. It is a claim, not an identity. |
| `Account`, `AccountKnown` | Resolved account on volume kinds, when known. |
| `CountSource` | Decision point that applied an increment: `backend_failure`, `pre_auth_reject`, `protected_endpoint`, or `policy_update` (optionally `policy_update:<feature>` for a Policy `authn/brute_force_update` effect). |
| `HitSource` | On `ban_hit`: `redis` (`BruteForceHitRedis`), `l1` (`BruteForceHitL1`, the short-lived in-process decision cache), or `activation_race` (`BruteForceHitActivationRace`, the request lost the ban-creation race). |
| `StoredRule` | Rule name stored in the ban key. |
| `ExpiresAt` | On `ban_activated`: activation time plus the rule's ban time. |
| `ReleaseSource` | On administrative kinds: `admin_flush` (`BruteForceReleaseAdminFlush`, the IP/rule flush) or `user_flush` (`BruteForceReleaseUserFlush`, the user cache flush that removes the bans of the user's IP history). |
| `OperatorClientID`, `OperatorAuthMethod` | Caller of the flush, when known. |
| `KeysRemoved` | On `counters_reset`: removed counter keys of the bucket. A flush that fails after deleting some keys still reports the keys it removed. |

The bundled ClickHouse plugin is a reference implementation of both sinks; see
[ClickHouse](../reference-plugins/clickhouse.md).
