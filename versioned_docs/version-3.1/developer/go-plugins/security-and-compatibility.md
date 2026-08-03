---
title: Security and Compatibility
description: Threat boundary, secrets, artifact provenance, ABI compatibility, and current implementation limitations
keywords: [Go plugin security, ABI, signature, secrets, compatibility]
sidebar_position: 7
---

# Security and Compatibility

Native plugins are privileged server code. The public API narrows normal integration patterns and enables validation at call boundaries, but it cannot sandbox arbitrary Go running in the same process.

## Trust model

A loaded plugin can, in principle, use the Go standard library to access process memory, files, networks, and environment data available to Nauthilus. Host facades are the supported and observable path; they are not a security boundary against a malicious artifact.

Use layered controls:

- review source and dependencies;
- build in a controlled pipeline;
- verify a checksum or trusted signature before `plugin.Open`;
- load only from root/operator-owned directories;
- run Nauthilus with least operating-system privilege;
- restrict filesystem mounts and network egress around the process;
- keep plugin configuration and logs secret-safe;
- rebuild for each exact host release.

## Artifact provenance

Use `signature_required` for distributed or multi-architecture release artifacts and `checksum_required` for a pinned local artifact. Verification happens before Go maps the plugin into the process.

Resolve the entire operational path:

1. the configured artifact and detached signature paths are absolute;
2. the loader resolves symlinks;
3. the resolved artifact remains below a resolved allowed directory;
4. checksum/signature verification succeeds;
5. the signer reference and format match the trust store;
6. only then may `plugin.Open` run.

Do not make allowlisted directories writable by the runtime account. A valid signature is stronger than path ownership alone, but neither protects against a compromised private signing key or a malicious trusted build.

## Secret access

Request passwords are intentionally absent from snapshots. A cooperating plugin declares and requests `CapabilityCredentials`, the operator allows it, and request-time code uses `CredentialProvider` plus closure-scoped `Secret` access.

Capability metadata is an auditable contract, not sandboxing. Because code is in-process, a malicious plugin is outside the threat model of facade-level permission checks. Current mail facade construction also does not independently reject a plugin that skipped `RequireCapability(CapabilityMail)`. Always use the cooperative contract, but enforce trust with artifact and process controls.

Never expose secrets through:

- `StatusMessage` fields;
- errors returned to the host;
- `LogField` or `TraceAttribute` values;
- metric labels;
- policy facts or fact details;
- runtime values;
- discovery metadata;
- response headers or hook bodies.

Treat `PostActionRequest.PasswordHash` as sensitive password-derived material. It is the host-owned lowercase 64-character SHA-256 digest of the prepared nonce-plus-password bytes, remains hashed in development mode, and is passed independently of the credentials capability. A post-action credential provider also relies on plugin discipline for request scoping; never retain either value for later use.

`Host.Config()` is the complete process-start configuration view and can contain inline configured secrets. Prefer the module subtree and least data access; do not assume the host-wide view is redacted or refreshed by SIGHUP.

## Immutable request boundary

Snapshots and public entry/result types prevent accidental access to internal mutable state. They also support host filtering of:

- authorization, proxy authorization, cookies, and configured password headers;
- raw request/response writer objects;
- server-owned connections and policy structures;
- pointer-shaped runtime values;
- unsafe response headers.

This is a correctness and data-minimization boundary. It does not stop plugin code from bypassing the API with direct process/network/file operations, which is why plugin trust remains mandatory.

## Network safety

Host HTTP, mail, Redis, and LDAP facades provide useful instrumentation and some bounds, but the plugin still controls inputs derived from its config.

- Validate endpoint schemes and allowed hosts to avoid turning module config into SSRF.
- Set explicit timeouts and response-size limits.
- Do not log URLs with queries, request/response bodies, raw transport errors, or credentials.
- Treat named external Redis pools, SQL drivers, raw sockets, and custom mail stacks as fully plugin-owned resources.
- Close plugin-owned clients in `Stop` and swap them atomically on reload.
- Use `ConnectionTargets` only for observability; it does not secure or create a connection.

## Policy and result safety

Every fact should match a registered `AttributeDefinition`. Environment, subject, and obligation results are checked against the active registry/stage/type. Backend and account-list facts currently have a weaker adapter path and are not checked there with the same rigor, so plugins must not treat that gap as permission to emit undeclared data. Select the least sensitive category/type and mark details accurately. Facts are internal decision evidence, not a substitute for redacted audit logs.

Keep runtime keys deterministic and value-only. A later plugin should be able to consume them without importing the producer package. Use the standard `exchange` helpers for bundled cross-plugin keys.

Response mutations are header-only and filtered. Full custom content belongs in
a hook, where response headers are filtered by the host. The current hook
adapter writes the response body without a host-side size limit, so the plugin
must enforce a strict bound before returning it.

## Hook authorization limitation

The current 3.1 development implementation does not make `HookScopeAdmin` elevate a hook declared with `HookAuthSession`; that path uses the basic-auth/session adapter semantics. Therefore:

- use `HookAuthAdmin` for administrative hooks;
- do not rely on scope alone as authentication;
- put sensitive hooks behind explicit external routing/auth controls as defense in depth;
- keep bodies and outputs free of privileged configuration or secret material.

This is a current implementation limitation, not the intended meaning of an administrative scope.

## Scheduler limitations

The public `SourceDescriptor` contains more expressiveness than the current native scheduler applies:

- `Priority` is recorded but ignored;
- `AbortPolicy` is validated but not applied;
- `Requires` and `After` both behave as hard dependencies.

Do not use these fields as authorization or fail-closed guarantees. Make denial/tempfail behavior explicit in policy and component results.

## Go shared-library compatibility

Go plugin compatibility is stricter than source compatibility. The host and artifact must align on:

- operating system and architecture;
- Go toolchain/package export data;
- `GOEXPERIMENT`;
- build tags;
- trimpath/build settings that affect package identity;
- exact Nauthilus module source;
- shared transitive dependency versions.

The semantic API version remains `nauthilus.plugin.v1`, but a plugin compiled against another Nauthilus tag with the same constant may still fail Go's package-hash checks. Build, test, and distribute artifacts per host release/architecture.

## Reload safety

`Reconfigure` is a config callback, not a code reload or a host-provided rollback transaction:

- decode and validate the complete next config;
- prepare clients, templates, or database snapshots before swapping;
- keep old state if this plugin's preparation fails;
- close old resources only after successful publication;
- consider in-flight callbacks when reclaiming old state;
- never change the `.so` underneath a running process and expect SIGHUP to load it.

The host delays its own config-view commit until all invoked reloadable plugins succeed, but it cannot undo an earlier plugin's internal state swap when a later module rejects the same SIGHUP. A non-reloadable plugin's changed config is currently skipped rather than rejected. Design reloads to be conservative and independently safe.

Fields that affect artifact identity, capabilities, trust, module identity, or shutdown require restart.

## Resource safety checklist

- Every request call obeys its context.
- Every outbound operation has a finite timeout and bounded response.
- Long-lived work uses `Host.Go` and exits on cancellation.
- Queues have explicit capacity, overflow, flush, retry, and shutdown semantics.
- Caches are treated as non-durable.
- Metrics/traces/logs use bounded dimensions.
- Errors are redacted before crossing the plugin boundary.
- `Stop` is idempotent and respects its context.
- Multiple module instances do not share mutable global state accidentally.

## Compatibility checklist

- Pin the exact Nauthilus host tag or commit.
- Match Go version, `GOEXPERIMENT=runtimesecret`, tags, and module graph.
- Export the exact `NauthilusPlugin` factory signature.
- Set metadata API version to `pluginapi.APIVersion`.
- Test direct behavior and a helper-process `.so` load.
- Verify the real deployment artifact hash/signature.
- Restart for code or loader-contract changes.

See [Configure native Go plugins](../../configuration/native-go-plugins.md) for operator controls and [Build, test, and debug](./build-test-debug.md) for the verification workflow.
