---
title: Migrating to Nauthilus v4
description: Upgrade guide from Nauthilus 3.1 to 4.0.0 covering the v4 module, browser session, identity, Policy, plugin, and public API migration
keywords: [Nauthilus, v4, migration, Policy, sessions, MFA, Go modules, plugins]
sidebar_position: 1
---

# Migrating to Nauthilus v4

Nauthilus v4 establishes deliberate compatibility boundaries for the Go module and native plugin ABI, Policy
configuration and APIs, public Go protobuf imports, browser session state, and IdP token state. This guide targets the
stable `v4.0.0` release and an upgrade from the 3.1 line. The [4.0.0 release notes](../release-notes/4.0.0.md) summarize
every breaking change, the additional steps for v4 prereleases, and the new features. Validate the complete deployment
in a non-production environment before rollout.

## Migration Checklist

1. Replace only the exact module prefix `github.com/croessner/nauthilus/v3` with
   `github.com/croessner/nauthilus/v4`.
2. Use Go 1.27.1 with `GOEXPERIMENT=runtimesecret`. Rebuild every native `.so` against the exact host commit, toolchain,
   module graph, build tags, CGO mode, OS, and architecture, and embed the host's native artifact identity with
   `-ldflags "$(go run -mod=vendor ./scripts/native_artifact_fingerprint)"`. Unmarked artifacts are rejected.
3. Manually migrate the removed v3 `auth.policy` subtree to top-level `policy`. There is no converter, dual root, or
   compatibility window.
4. Replace unqualified `standard_auth`, rule/check `stage`, and check `config_ref` with exact qualified identities and
   checkpoint ownership. Move record-predicate fields from `records.field` into the `records.where` leaves, and use only
   `permit`/`deny` (plus `tempfail`/`neutral` in `authn`) as rule decisions.
5. Configure Generic Policy callers separately from management and backchannel callers. Preserve exact audience,
   scope, target, schema, fact, diagnostics, rate, concurrency, and optional mTLS admission.
6. Update native plugins: declare `ReplaySafety` on every effect descriptor, grant `allow_capabilities: [password_hash]`
   to modules that read password digests (for example ClickHouse), and make sure admin hooks are only used by
   `nauthilus:admin` callers.
7. Add `decision_bindings` to every GeoIP module. Remove the Lua `geoip_reputation.lua` plugin and its settings, and
   switch to the bundled `reputation` plugin if you need reputation data.
8. Replace the complete browser-serving pool uniformly. Do not mix v3.1 and v4 session readers or try to migrate
   in-flight browser state. Old records remain inert and can expire.
9. Prepare the IdP Redis hard cut: Redis 6.2 or newer with `maxmemory-policy noeviction` and a mandatory
   `storage.redis.encryption_secret`. All tokens, device flows, and unredeemed codes are invalidated; clients must
   reauthenticate. Operators coming from a v4 prerelease with dynamic clients also remove the old
   `oidc:dcr:{dynamic}:*` and `oidc:dcr:{registry}:active` keys and register dynamic clients again. Edge nodes replace
   rejected authority caller tokens on their own, so no manual edge token flush is needed.
10. Validate the direct MFA self-service entry, which now requires MFA for users with an enrolled factor, and each TOTP,
    WebAuthn, recovery-code, enrollment, and step-up flow.
11. Review brute-force bucket limits: every distinct wrong password now counts immediately, while backend faults are no
    longer counted.
12. Check reverse proxies: all `X-Forwarded-For` lines are evaluated. An invalid chain falls back to the direct peer,
    not to `X-Real-IP`; `X-Real-IP` still applies when no `X-Forwarded-For` header is sent.
13. Regenerate Go clients that consume v4 `go_package` metadata. Independently generated protobuf clients remain wire
    compatible where their package, service, method, field, and HTTP identifiers are unchanged.
14. If you used the `dkim2-reputation` module of an early v4 prerelease, replace it with `geoip` + `reputation` +
    `dkim2-intelligence`, convert static data with `scripts/convert-static-reputation.py`, and keep enforcement off
    until a live `dkim2d` end-to-end run passes.
15. Run `nauthilus --config-check` against the final configuration. Authn rules must fit their checkpoint position
    (`permit`, `deny`, or `tempfail` at the final checkpoint; `deny`, `tempfail`, or `neutral` earlier), and an explicit
    `fsm_event_marker` must match decision and checkpoint. Omitted markers are still derived.
16. Make sure every authn `permit` rule tests the host evidence it relies on (for example `backend.authenticated`),
    because a permit without host evidence fails closed as a temporary failure. Alert on
    `authn_fsm_guard_violations_total`.
17. Review the LDAP pool settings of every pool section. Timeouts, size and time limits, retry, circuit-breaker, health,
    cache, and `auth_rate_limit_*` options now apply to every pool connection.
18. Point Kubernetes liveness probes at `/livez` and keep `/healthz` for readiness and startup probes, with a startup
    budget that covers the Redis readiness loop and the reputation start retry.
19. Update dashboards for the pipelined brute-force Redis labels of `bruteforce_redis_roundtrips_total`, the halved
    failed-login share of `redis_write_total`, and the new mail and `jmap` protocol labels of
    `authentication_response_time_seconds`.
20. If the HTTP rate middleware is enabled, remember that the per-IP limit on caller-authenticated `/api/v1` routes is
    a failure budget, and that `auth.pipeline.max_concurrent_requests` now bounds the gRPC authority as well.
21. Optional features: enable the LDAP identity lookup cache (`storage.redis.identity_cache`), Redis password caching
    for native backend modules (`plugins.modules[].positive_password_cache` with plugin support),
    `observability.log.notice_ignore_fields`, and OIDC resource indicators (`token_introspection`) only after testing.
    Resource servers that read `aud` must accept an array once resources are granted.
22. Validate the entire candidate in a non-production environment before any production rollout.

## Detailed Contracts

- [Nauthilus 4.0.0 release notes](../release-notes/4.0.0.md)
- [Policy configuration hard cut and manual migration](policy-configuration-migration.md)
- [Policy configuration overview](../configuration/auth-policy.md)
- [Generic Policy REST and gRPC API](generic-policy-api.md)
- [Canonical browser session migration](browser-session-migration.md)
- [MFA self-service portal](mfa-self-service.md)
- [OIDC Dynamic Client Registration](oidc-dynamic-client-registration.md)
- [Native Go plugin guide](../developer/go-plugins/index.md)
- [Public protobuf APIs](../developer/protobuf-apis.md)
- [DKIM2/Rspamd Policy integration](dkim2-rspamd-policy.md)
- [Reputation operations](reputation-operations.md)
- [Generated protected HTTP API reference](../api-reference/index.md)

Third-party module paths that independently contain a `/v3` suffix are unrelated and must not be rewritten. The retired
browser `/api/v1/mfa/*` routes must not be confused with the separate cookie-free `/api/v1/mfa-backchannel/*` family.
