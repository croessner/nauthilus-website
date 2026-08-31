---
title: Build, Test, and Debug
description: Reproducible builds, unit tests, shared-object smoke tests, and diagnostics for Nauthilus Go plugins
keywords: [Go plugin build, testing, debug, plugin.Open, runtimesecret]
sidebar_position: 6
---

# Build, Test, and Debug

Test plugin logic directly first, then prove the shared-object boundary with a separate load helper, and finally verify the artifact against the exact server build that will deploy it.

## Reproducible build contract

Current Nauthilus container builds compile the server and bundled plugins from one source tree with:

- Go 1.27 from the repository toolchain declaration;
- `GOEXPERIMENT=runtimesecret`;
- vendored dependencies;
- `netgo` plus any selected release build tags;
- `-trimpath`;
- the same `github.com/croessner/nauthilus/v4` package sources.

A corresponding plugin build is:

```shell
GOEXPERIMENT=runtimesecret \
go build \
  -mod=vendor \
  -tags="netgo ${BUILD_TAGS}" \
  -trimpath \
  -buildmode=plugin \
  -o build/customer.so \
  .
```

An external plugin can use module mode instead of vendoring, but its selected versions still have to match the host. Record the host tag or commit, Go version, build tags, and artifact hash in your release metadata.

## Why API version is not enough

The loader first has to satisfy Go's shared-package compatibility checks. Only then can Nauthilus inspect `Metadata().APIVersion`. These are separate layers:

| Layer | What must match |
| --- | --- |
| Go plugin loader | toolchain/package hashes, experiments, build tags, shared sources, dependency graph |
| Nauthilus contract | factory signature, non-nil plugin, metadata, exact `pluginapi.APIVersion` |
| Operator policy | allowlisted resolved path, checksum/signature/trust policy, capabilities |
| Runtime registration | unique names, descriptors, facts, hooks, and strict plugin config |

`built with a different version of package ...` is an ABI/package-hash failure. Rebuild against the exact host source and dependency graph; changing only `Metadata().APIVersion` cannot fix it.

## Unit tests without `.so` loading

Most behavior should be tested as ordinary Go code:

```go
func TestRiskSource(t *testing.T) {
    source := riskSource{}
    request := pluginapi.EnvironmentRequest{
        Snapshot: pluginapi.RequestSnapshot{
            ClientNet: "203.0.113.0/24",
        },
    }

    result, err := source.Evaluate(context.Background(), request)
    if err != nil {
        t.Fatal(err)
    }
    if !result.Triggered {
        t.Fatal("expected source to trigger")
    }
}
```

Recommended test layers:

1. typed config decode/default/validation tests;
2. table-driven component behavior tests;
3. cancellation, timeout, and error-redaction tests;
4. fake facade tests for HTTP, Redis, LDAP, mail, metrics, and tracing;
5. reload tests that prove failed preparation leaves old state active;
6. concurrency/race tests for shared module state;
7. one artifact build/load smoke test.

External plugins should implement narrow fakes for public interfaces instead of importing `server/pluginruntime` or `server/pluginregistry`. In-tree reference plugins may use internal test helpers because they are built and tested with the host repository.

Run current Nauthilus-compatible tests with:

```shell
GOEXPERIMENT=runtimesecret GOCACHE=/tmp/nauthilus-go-cache go test ./...
GOEXPERIMENT=runtimesecret GOCACHE=/tmp/nauthilus-go-cache go test -race ./...
```

## Compile-time interface assertions

Keep assertions next to implementations:

```go
var (
    _ pluginapi.Plugin             = (*Plugin)(nil)
    _ pluginapi.RuntimePlugin      = (*Plugin)(nil)
    _ pluginapi.ReloadablePlugin   = (*Plugin)(nil)
    _ pluginapi.Backend            = (*Backend)(nil)
    _ pluginapi.WebAuthnBackend    = (*Backend)(nil)
    _ pluginapi.EnvironmentSource  = (*Environment)(nil)
    _ pluginapi.PostActionTarget   = (*PostAction)(nil)
)
```

Optional backend interfaces are independent. Assert only the operations the backend truly owns; the host detects each interface separately.

## Shared-object smoke test

Do not load a freshly built plugin into the same `go test` process that also imports another build of the shared packages. That pattern often creates a misleading package-version mismatch.

Use a small helper program compiled in a separate process:

```go
package main

import (
    "fmt"
    "os"
    "plugin"

    pluginapi "github.com/croessner/nauthilus/v4/pluginapi/v1"
)

func main() {
    artifact, err := plugin.Open(os.Args[1])
    if err != nil {
        panic(err)
    }

    symbol, err := artifact.Lookup("NauthilusPlugin")
    if err != nil {
        panic(err)
    }

    factory, ok := symbol.(func() (pluginapi.Plugin, error))
    if !ok {
        panic("wrong NauthilusPlugin signature")
    }

    instance, err := factory()
    if err != nil {
        panic(err)
    }

    fmt.Println(instance.Metadata().Name)
}
```

Build the artifact, then invoke the helper with `go run ./testdata/loadplugin build/customer.so`. The GeoIP reference plugin uses this subprocess pattern.

Skip the smoke test explicitly on operating systems or architectures where Go plugin build mode is unsupported. Do not silently treat an unsupported platform as a successful load proof.

## Config and registration tests

Strict config decode should be part of the public plugin contract:

- unknown keys fail;
- invalid durations and enum values fail;
- relative or unsafe plugin-owned file paths fail according to plugin policy;
- a reload error preserves the previous state;
- a capability-dependent feature fails registration when the capability was not acquired;
- duplicate component/fact/debug names fail.

Test one minimal config and one full config from the published documentation to keep examples executable.

## Runtime-value tests

Test that outputs contain only safe value graphs. Include negative cases for:

- Go pointers or function/channel values in `RuntimeDelta`;
- unregistered or wrong-type policy facts;
- invalid backend attribute names;
- forbidden response headers;
- credential-bearing logs/status/errors;
- mutation of input maps or slices that must not affect retained state.

For post-actions, test plan ordering and prove that a step's delta is visible to the next step but absent from live request runtime after the detached plan ends.

## Debug selectors

Enable the normal debug level and the narrowest useful selector:

```yaml
observability:
  log:
    level: debug
    debug_modules:
      - plugin.customer_sql.lookup
```

The module automatically has `plugin.<module>`. Extra local selectors appear only after `RegisterDebugModule` succeeds. Keep `Info`, `Warn`, and `Error` useful without debug mode; use debug records for bounded diagnostic detail.

## Host-owned diagnostics

Look for lifecycle events in this order:

1. artifact verification started/completed;
2. factory lookup and metadata validation;
3. registration commit;
4. runtime start and init-task start;
5. request-call result metrics/spans;
6. bounded stop and worker completion.

Automatic call metrics are:

```text
plugin_calls_total{module,component,extension_point,method,result}
plugin_call_duration_seconds{module,component,extension_point,method,result}
```

Use these to distinguish registration/startup failures from request-time plugin failures before enabling plugin-specific debug output.

## Reference test assets

- `pluginapi/v1/testdata/sampleplugin` is the public compile-contract fixture.
- `contrib/plugins/geoip` demonstrates `.so` build/load testing and lifecycle fakes.
- `contrib/plugins/clickhouse` and `contrib/plugins/haveibeenpwnd` demonstrate post-action plan/runtime exchange tests.

See [API validation](./api-reference/validation.md) for exact public name and metadata validators.
