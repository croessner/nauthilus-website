---
title: Authentication Load Test Client
description: Drive CSV-based authentication traffic with the native nauthilus-client tool
keywords: [Nauthilus client, load test, CSV, TLS, authentication]
sidebar_position: 5
---

# Authentication Load Test Client

`nauthilus-client` is the repository's CSV-driven authentication and load-test tool. It can replay or generate login rows, control concurrency and request rate, inject selected failure modes, and report latency/error thresholds.

It is a test tool, not an end-user authentication SDK. Run it only against targets you own and within an agreed load budget.

## Build

From the Nauthilus source checkout:

```shell
make build-client
```

The Makefile writes the binary to:

```text
nauthilus/bin/nauthilus-client
```

Current source builds require the repository Go toolchain and `GOEXPERIMENT=runtimesecret`.

## Generate input

Generate a synthetic CSV:

```shell
./nauthilus/bin/nauthilus-client \
  --generate-csv \
  --generate-count 1000 \
  --csv /tmp/logins.csv
```

The current generator includes `username`, `password`, `ip`, and `expected_ok`. `expected_ok` controls whether the row is expected to succeed. Keep real credentials out of shared test artifacts.

## Run a bounded test

```shell
./nauthilus/bin/nauthilus-client \
  --csv /tmp/logins.csv \
  --url https://nauthilus.test.example/api/v1/auth/json \
  --method POST \
  --headers 'Content-Type: application/json' \
  --basic-auth 'loadtest:replace-with-secret' \
  --concurrency 8 \
  --rps 25 \
  --duration 2m \
  --timeout-ms 5000 \
  --progress-interval 10s
```

Important control groups:

| Area | Representative flags |
| --- | --- |
| Input/endpoint | `--csv`, `--url`, `--method`, `--headers`, `--basic-auth`, `--ok-status`, `--json-ok` |
| Execution | `--concurrency`, `--rps`, `--jitter-ms`, `--delay-ms`, `--timeout-ms`, `--max`, `--shuffle`, `--loops`, `--duration` |
| Parallelism | `--max-parallel`, `--parallel-prob`, `--abort-prob`, `--compare-parallel`, `--idempotency-key` |
| CSV | `--generate-csv`, `--generate-count`, `--generate-cidr-prob`, `--generate-cidr-prefix`, `--csv-delim`, `--csv-debug` |
| Output/thresholds | `--progress-interval`, `--progress-bar`, `--color`, `--warn-p95`, `--crit-p95`, error/tracking thresholds |
| Adaptive mode | `--auto` and the `--auto-*` target, limit, backoff, plateau, and focus controls |
| Fault injection | `--random-no-auth`, `--random-bad-pass` and their probability flags |

Run `nauthilus-client --help` from the exact build for the complete current flag set.

## TLS verification

HTTPS certificate verification is enabled by default. This is the production-safe behavior and should be preserved for normal integration and performance tests.

For an isolated development target with a deliberately untrusted certificate, the client has an explicit escape hatch:

```shell
./nauthilus/bin/nauthilus-client \
  --insecure-tls \
  --url https://127.0.0.1:9443/api/v1/auth/json \
  --csv /tmp/logins.csv
```

:::warning Development only

`--insecure-tls` disables certificate verification. It permits machine-in-the-middle interception of backchannel credentials and test rows. Do not use it for production, shared staging, or any route carrying real credentials. Install the test CA in the client trust store instead.

:::

## Backchannel authentication

`--basic-auth username:password` sets the management/backchannel HTTP Basic credentials. It is independent of the user password in each CSV row. Protect the command line and process list; prefer an isolated test account and environment.

## Result interpretation

The client can evaluate a configured success HTTP status or a JSON `{ "ok": true|false }` response, compare parallel responses, and color output using latency/error/tracking thresholds. Threshold colors are diagnostics unless your wrapper turns the process result into a CI gate.

Start with low concurrency/RPS, confirm response correctness and server metrics, then increase one dimension at a time. Use [Prometheus metrics](../configuration/metrics.md) and [OpenTelemetry tracing](../guides/tracing-opentelemetry.md) to separate client saturation from Nauthilus/backend saturation.
