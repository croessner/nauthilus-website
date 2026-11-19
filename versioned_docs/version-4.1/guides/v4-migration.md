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
in a non-production environment before rollout. Operators who already run 4.0.x follow
[Upgrading from 4.0.x to 4.1](#upgrading-from-40x-to-41).

## Migration Checklist

1. Replace only the exact module prefix `github.com/croessner/nauthilus/v3` with
   `github.com/croessner/nauthilus/v4`.
2. Use Go 1.27.4 (the toolchain since v4.0.8) with `GOEXPERIMENT=runtimesecret`. Rebuild every native `.so` against the exact host commit, toolchain,
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
    `dkim2-intelligence` (an external plugin since v4.0.2), convert static data with `scripts/convert-static-reputation.py`, and keep enforcement off
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

## Upgrading from 4.0.x to 4.1

Nauthilus 4.1 keeps the v4 module path, `pluginapi.APIVersion`, and the configuration roots. Review these points
before the upgrade:

1. **Behavior change, brute-force toleration:** toleration works again. On 4.0.x no request recorded toleration
   observations, so `tolerate_percent`, `custom_tolerations`, `adaptive_toleration`, and the reputation-scaled bucket
   limits had no effect. Negatives now count every failed attempt behind an address, positives count distinct accounts
   with a successful login, both within `tolerate_ttl`. Networks with recent successful logins get higher effective
   limits again, and shared addresses with many failures reach the end of their toleration sooner. Review
   `tolerate_ttl`, `tolerate_percent`, `min_tolerate_percent`, `max_tolerate_percent`, `scale_factor`,
   `adaptive_toleration`, and `custom_tolerations`; see [Toleration](../configuration/brute-force.md#toleration).
   Old `bf:tr:{<scoped ip>}` counter hashes are no longer read and expire on their own.
2. **Behavior change, affected accounts:** entries of the brute-force listing now age out per account after
   `auth.controls.brute_force.affected_accounts.retention` (default `24h`, raised to the longest brute-force state
   lifetime). Existing entries stay listed for at least that retention after the upgrade. Set
   `affected_accounts.cleanup_enabled: false` to keep entries until an explicit flush. The lifecycle needs Redis 6.2 or
   newer; see [Affected Accounts](../configuration/brute-force.md#affected-accounts).
3. Clients of `/api/v1/cache/flush` must expect HTTP `503` `Account mapping lookup failed` (or a failed async job)
   when the stored account mappings cannot be read, and retry. Earlier releases flushed only the literal name.
4. Update dashboards: `redis_write_total` counts each command of the affected-account write and flush, and the new
   `bruteforce_affected_accounts_*`, `policy_terminal_post_actions_total`, and `plugin_auth_events_total` series
   appear. Watch `post_action_acceptance_failures_total{error_class="best_effort_saturated"}`.
5. Optional: declare login-log post-actions such as `authn/plugin.clickhouse.post_action` as
   [`terminal_post_actions`](../configuration/auth-policy.md#terminal-post-actions) of the authn target, so requests
   answered by built-in rules, such as brute-force rejects after a ban hit, are recorded once as well. Rule obligations
   that name the same effect are folded into the completion and need no removal, but must use the same parameters.
6. **Security fix, secret redaction:** with debug logging, earlier v4 releases printed secret values such as OIDC
   client secrets in plain text in the configuration sections they log at startup. 4.1 renders every secret value as
   `<hidden>` in formatted and logged output. Restrict or purge debug logs written by earlier releases, and rotate the
   OIDC client secrets they contain.
7. SAML: service providers that require signed logout responses now accept the Redirect-bound answer to an
   SP-initiated logout, and LogoutRequests with several `SessionIndex` elements match any listed index. Service
   providers that were configured to accept unsigned logout responses as a workaround can require signatures again; see
   [SAML](../configuration/idp/saml2.md#outbound-slo-signatures).
8. Rebuild every native plugin against the exact 4.1 host commit as before. Plugins that share Kafka dependencies with
   the host must use the host's pinned module versions, currently `github.com/twmb/franz-go` v1.22.1,
   `github.com/twmb/franz-go/pkg/kmsg` v1.14.0, and `github.com/pierrec/lz4/v4` v4.1.31: lz4 v4.1.32 and later cannot be
   built with `-buildmode=plugin` on amd64. New optional APIs are the
   [event sinks](../developer/go-plugins/api-reference/events.md) and
   [`PostActionRequest.Outcome`](../developer/go-plugins/api-reference/extensions.md#authoutcome).
   Revisions that ship `server/default.pgo` build the server with profile-guided optimization; compile every plugin
   with the same profile, or Go refuses to load it. See [PGO profile](../developer/go-plugins/build-test-debug.md#pgo-profile).
9. **Action, ClickHouse plugin:** apply `migrations/diagnostic-contract.sql` before deploying the 4.1 plugin, and
   `migrations/bruteforce-evidence.sql` before enabling the brute-force evidence URLs; ClickHouse drops unknown fields
   silently by default. The login export no longer writes the 20 retired columns (the flat `reputation_*`, `gp_*`,
   `prot_*`, and `dyn_*` fields), and tempfails are recorded as `outcome=tempfail` with `http_status=500` instead of a
   credential failure. Update dashboards and queries; the `retire-legacy-columns` block of `schema.sql` is a separate,
   irreversible step. See [ClickHouse](../developer/go-plugins/reference-plugins/clickhouse.md#schema-and-upgrades).
10. **Behavior change, OIDC discovery:** Nauthilus serves RFC 8414 metadata at `/.well-known/oauth-authorization-server`
    (and its path-insertion form) and adds the RFC 9207 `iss` parameter to every redirect-based authorization response.
    Route the new well-known path to Nauthilus if the reverse proxy forwards only `openid-configuration`, and keep
    `identity.oidc.issuer` exactly as clients know it. See
    [OIDC](../configuration/idp/oidc.md#authorization-server-metadata-and-issuer-identification).
11. **Security fix, consent challenges:** the token endpoint refuses values outside the issued authorization-code shape
    with `invalid_grant`. Consent pages that a user opened on a 4.0.x instance during a rolling update must be restarted;
    nothing needs to be migrated.
12. Admin client: repeated `--resolve` flags now replace `NAUTHILUS_RESOLVE` instead of adding to it, and
    `bruteforce list` requests a page of 100 entries by default; page further with `--offset`. See
    [Admin Client](admin-client.md).
13. **Behavior change, backchannel scopes:** every `/api/v1` route family asks only for its own scopes, and
    `nauthilus:authenticate` is no longer a base scope of all routes. Existing tokens keep working. Single-purpose
    clients can drop scopes they no longer need, for example a brute-force dashboard to `nauthilus:security_read`
    alone; `nauthilus:security_write` covers flushes and OIDC session deletion. See
    [OIDC Bearer Access](../rest-api.md#oidc-bearer-access-for-apiv1).
14. **Action, backchannel Basic authentication:** `auth.backchannel.basic_auth` is validated more strictly.
    `enabled: true` requires the `username` and `password` pair or at least one entry under `users`, `username` and
    `password` must be set together, and usernames must not contain a colon or a space. A configured `username` and
    `password` pair is the unrestricted credential and is announced with a warning at startup; scoped credentials under
    `users` hold only the scopes listed for them. A custom hook that declares scopes now refuses the unrestricted
    credential with `403` instead of `401`. See
    [Backchannel Basic Credentials](../rest-api.md#backchannel-basic-credentials).
15. **Upgrade effect, browser sessions:** session payloads in Redis are sealed with `storage.redis.encryption_secret`
    and plaintext records are discarded. Every live browser session ends once and stored OIDC consents are requested
    once more. Each edge replica also fetches its authority token once more, because the cached token is now stored
    encrypted.
16. **Behavior change, OIDC signing keys:** generated signing keys follow `identity.oidc.key_max_age` (default 7 days)
    instead of a 365-day fallback, and inactive keys older than that age are removed. Set `key_max_age` explicitly if
    relying parties cache keys for longer, and keep `key_rotation_interval` shorter than `key_max_age`.
17. **Action, bundled Lua plugins on Redis Cluster:** delete the untagged and `{lua-nauthilus}`-renamed
    `multilayer:global:current_metrics` hashes once. The plugins now keep the keys of one Redis script on one hash
    tag; all other old keys expire.

The support history, MCP support access, and operational diagnostics are new and disabled by default; see
[Support Authentication History](support-authentication-history.md) and
[Read-only Support Access over MCP](support-mcp-access.md). The [4.1.0 release notes](../release-notes/4.1.0.md) list
every change.

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
