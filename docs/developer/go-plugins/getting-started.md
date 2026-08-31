---
title: Create Your First Go Plugin
description: Build, configure, and reason about a minimal native Nauthilus Go plugin
keywords: [Go plugin tutorial, NauthilusPlugin, pluginapi, buildmode plugin]
sidebar_position: 2
---

# Create Your First Go Plugin

This tutorial builds a small pre-auth environment source. It demonstrates the minimum public contract without importing any package below `server/`.

## Prerequisites

You need:

- a platform supported by Go's `plugin` build mode;
- the exact Go toolchain and `GOEXPERIMENT` used by the Nauthilus host;
- the exact Nauthilus module version or commit used by that host;
- matching build tags and shared dependency versions;
- an operator-controlled directory from which Nauthilus may load `.so` files.

Native Go plugins are release-specific binaries. A successful compile against `pluginapi/v1` is necessary but does not, by itself, prove that `plugin.Open` can load the artifact into a differently built server.

## Create a module

```shell
mkdir customer-risk-plugin
cd customer-risk-plugin
go mod init example.com/customer-risk-plugin
# Replace <host-tag-or-commit> with the exact Nauthilus source used by the server.
go get github.com/croessner/nauthilus/v4@<host-tag-or-commit>
```

Use only the public packages when writing the plugin:

```text
github.com/croessner/nauthilus/v4/pluginapi/v1
github.com/croessner/nauthilus/v4/pluginapi/v1/exchange
github.com/croessner/nauthilus/v4/pluginapi/v1/helpers
github.com/croessner/nauthilus/v4/pluginapi/v1/password
```

Do not import `github.com/croessner/nauthilus/v4/server/...`. Those packages are host internals and are neither a public source contract nor a safe shared-library boundary.

## Implement the factory and plugin

Create `main.go`:

```go
package main

import (
    "context"
    "fmt"
    "time"

    pluginapi "github.com/croessner/nauthilus/v4/pluginapi/v1"
)

const riskFact = "plugin.environment.customer_risk.suspicious"

var (
    _ pluginapi.Plugin            = (*Plugin)(nil)
    _ pluginapi.EnvironmentSource = riskSource{}
)

// NauthilusPlugin returns one fresh instance for one configured module.
func NauthilusPlugin() (pluginapi.Plugin, error) {
    return &Plugin{}, nil
}

type Plugin struct{}

func (p *Plugin) Metadata() pluginapi.Metadata {
    return pluginapi.Metadata{
        Name:        "customer_risk",
        Version:     "1.0.0",
        APIVersion:  pluginapi.APIVersion,
        Description: "Example pre-auth risk signal.",
        Features:    []pluginapi.Feature{"environment"},
    }
}

func (p *Plugin) Register(registrar pluginapi.Registrar) error {
    if registrar == nil {
        return fmt.Errorf("registrar is nil")
    }

    if err := registrar.RegisterPolicyAttribute(pluginapi.AttributeDefinition{
        ID:          riskFact,
        Description: "Reports whether the example considered the client suspicious.",
        Stage:       pluginapi.PolicyStagePreAuth,
        Operations: []pluginapi.PolicyOperation{
            pluginapi.PolicyOperationAuthenticate,
        },
        ProducerTypes: []string{"plugin.environment"},
        Category:      pluginapi.AttributeCategoryEnvironment,
        Type:          pluginapi.AttributeTypeBool,
    }); err != nil {
        return err
    }

    return registrar.RegisterEnvironmentSource(riskSource{})
}

type riskSource struct{}

func (riskSource) Descriptor() pluginapi.SourceDescriptor {
    return pluginapi.SourceDescriptor{
        Name:        "risk",
        Timeout:     100 * time.Millisecond,
        AbortPolicy: pluginapi.AbortPolicyNone,
    }
}

func (riskSource) Evaluate(
    _ context.Context,
    request pluginapi.EnvironmentRequest,
) (pluginapi.EnvironmentResult, error) {
    suspicious := request.Snapshot.ClientNet == "203.0.113.0/24"

    return pluginapi.EnvironmentResult{
        Triggered: suspicious,
        Facts: []pluginapi.PolicyFact{
            {Attribute: riskFact, Value: suspicious},
        },
        RuntimeDelta: pluginapi.RuntimeDelta{
            Set: map[string]any{
                "plugin.environment.customer_risk": map[string]any{
                    "suspicious": suspicious,
                },
            },
        },
    }, nil
}
```

The compile-time assertions make interface drift visible during a normal build. `NauthilusPlugin` returns a new pointer because Nauthilus calls the factory independently for every configured module instance.

## Understand the returned values

The environment source returns three different concepts:

- `Triggered` is an execution diagnostic indicating that the source matched.
- `Facts` supplies typed evidence to the policy engine. Every fact must have been registered before the active policy snapshot is compiled.
- `RuntimeDelta` publishes request-local data for later extension components. It does not directly decide whether authentication succeeds.

Policy facts and runtime values are deliberately separate. Facts are validated decision evidence; runtime values are safe, JSON-compatible coordination data.

## Build the shared object

Use the same experiment, tags, and path-shaping flags as the host build:

```shell
GOEXPERIMENT=runtimesecret \
go build \
  -tags=netgo \
  -trimpath \
  -buildmode=plugin \
  -o build/customer-risk.so \
  .
```

If the host is built with additional build tags, the plugin build must use the same set. If your release process vendors modules, vendor the plugin's dependency graph and add `-mod=vendor` to match that process.

## Configure the module

Copy the artifact into an operator-owned allowlisted directory, calculate its SHA-256 digest, and configure it:

```yaml
plugins:
  verification_policy: checksum_required
  allowed_dirs:
    - /usr/local/lib/nauthilus/plugins
  modules:
    - name: customer_risk
      type: go
      path: /usr/local/lib/nauthilus/plugins/customer-risk.so
      checksum: sha256:replace-with-the-artifact-digest
      optional: false
```

The configured module name, `customer_risk`, is the runtime namespace. The source's local name, `risk`, becomes the qualified component name `customer_risk.risk`. `Metadata().Name` remains product metadata and does not replace the configured module name.

See [Configure native Go plugins](../../configuration/native-go-plugins.md) for signature verification, optional modules, capabilities, discovery, and restart rules.

## Use the fact in policy

The plugin registers the attribute contract, but an active checkpoint provider instance still determines where the source runs and which policy consumes its output. A representative v4 declaration uses the configured module and an exact qualified provider identity:

```yaml
policy:
  namespaces:
    authn:
      providers:
        plugin.customer_risk.environment:
          kind: plugin
          module: customer_risk
          targets: [{action: authenticate}]
          executions: [host_sync]
      domain_plans:
        password:
          checkpoints:
            pre_auth:
              providers:
                - name: customer_risk_check
                  use: authn/plugin.customer_risk.environment
                  actions: [authenticate]
```

The provider declaration selects the configured module-level environment source;
the checkpoint uses its exact qualified `use` identity. Reference the registered
`plugin.environment.customer_risk.suspicious` attribute from the relevant
policy expression. Keep the instance name and component name conceptually separate:
a scheduled provider instance refers to the compiled plan-local name, while
`customer_risk.risk` identifies the registered source component.

This sample is intended as one configured module instance. Its fixed `riskFact`
ID is global in the policy registry, so a second instance would collide unless
the plugin deliberately gives all global registrations and service names an
instance-safe namespace.

## Next steps

- Read [Lifecycle and registration](./lifecycle-and-registration.md) before allocating resources or starting workers.
- Read [Requests, runtime values, and effects](./runtime-and-effects.md) before adding policy or authentication behavior.
- Use the [API reference](./api-reference/index.md) for exact field and method contracts.
- Study the [GeoIP/ASN reference plugin](./reference-plugins/geoip.md) for a complete lifecycle implementation.

:::tip Compile-contract fixture

The Nauthilus source tree includes `pluginapi/v1/testdata/sampleplugin`. It implements the public interfaces without importing `server/*` and is the smallest authoritative example for compile-time API compatibility.

:::
