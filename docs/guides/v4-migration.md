---
title: Migrating to Nauthilus v4
description: Landing page for the v4 module, browser session, identity, Policy, plugin, and public API migration
keywords: [Nauthilus, v4, migration, Policy, sessions, MFA, Go modules, plugins]
sidebar_position: 1
---

# Migrating to Nauthilus v4

Nauthilus `v4.0.0-alpha.1` is published as the first v4 prerelease. It establishes deliberate compatibility boundaries
for the Go module and native plugin ABI, Policy configuration and APIs, public Go protobuf imports, and browser session
state. It is an alpha release and still requires non-production validation before rollout.

## Migration Checklist

1. Replace only the exact module prefix `github.com/croessner/nauthilus/v3` with
   `github.com/croessner/nauthilus/v4`.
2. Use Go 1.27 with `GOEXPERIMENT=runtimesecret`. Rebuild every native `.so` against the exact host commit, toolchain,
   module graph, build tags, CGO mode, OS, and architecture.
3. Manually migrate the removed v3 `auth.policy` subtree to top-level `policy`. There is no converter, dual root, or
   compatibility window.
4. Replace unqualified `standard_auth`, rule/check `stage`, and check `config_ref` with exact qualified identities and
   checkpoint ownership.
5. Configure Generic Policy callers separately from management and backchannel callers. Preserve exact audience,
   scope, target, schema, fact, diagnostics, rate, concurrency, and optional mTLS admission.
6. Replace the complete browser-serving pool uniformly. Do not mix v3.1 and v4 session readers or try to migrate
   in-flight browser state. Old records remain inert and can expire.
7. Validate the direct MFA self-service entry and each TOTP, WebAuthn, recovery-code, enrollment, and step-up flow.
8. Regenerate Go clients that consume v4 `go_package` metadata. Independently generated protobuf clients remain wire
   compatible where their package, service, method, field, and HTTP identifiers are unchanged.
9. If evaluating the DKIM2/Rspamd preview, keep enforcement disabled until its documented adapter blocker is fixed and
   a real `dkim2d` end-to-end run passes.
10. Validate the entire candidate in a non-production environment before any production rollout.

## Detailed Contracts

- [Policy configuration hard cut and manual migration](policy-configuration-migration.md)
- [Policy configuration overview](../configuration/auth-policy.md)
- [Generic Policy REST and gRPC API](generic-policy-api.md)
- [Canonical browser session migration](browser-session-migration.md)
- [MFA self-service portal](mfa-self-service.md)
- [OIDC Dynamic Client Registration](oidc-dynamic-client-registration.md)
- [Native Go plugin guide](../developer/go-plugins/index.md)
- [Public protobuf APIs](../developer/protobuf-apis.md)
- [DKIM2/Rspamd Policy preview and blocker](dkim2-rspamd-policy.md)
- [Generated protected HTTP API reference](../api-reference/index.md)

Third-party module paths that independently contain a `/v3` suffix are unrelated and must not be rewritten. The retired
browser `/api/v1/mfa/*` routes must not be confused with the separate cookie-free `/api/v1/mfa-backchannel/*` family.
