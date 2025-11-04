---
slug: nauthilus-test-client
title: Load and Performance Testing with the Nauthilus CSV Test Client
authors: [croessner]
tags: [testing, performance, load, tools]
description: Nauthilus ships a CSV‑driven test/load client. This article shows the exact, repository‑verified way to use it for realistic performance and load tests.
---

This guide is for anyone who wants a quick, reliable way to see how Nauthilus handles authentication under load. In a few minutes you’ll drive realistic requests from a CSV and get clear counters for throughput and failures—perfect for spotting regressions and finding safe limits.

If you just want the commands, start with the TL;DR below. The rest of the article explains scenarios, tips, and tuning—everything verified against the repository files `client/README.md` and `client/nauthilus-testing.yml`.

## TL;DR
1) Build the client
```bash
cd client
go build -o nauthilus-testclient
```

2) Start the server with the test config
```bash
TESTING_CSV=client/logins.csv ./nauthilus -config client/nauthilus-testing.yml -config-format yaml
```

3) Run a small load
```bash
./nauthilus-testclient --csv ./client/logins.csv --concurrency 8 --rps 40 --json-ok
```
You’ll see total/failed requests and throughput. Increase `--rps`/`--concurrency` to explore limits.

<!-- truncate -->

## What you can test

- Authentication requests to /api/v1/auth/json using CSV rows
- Success/failure validation via JSON field `{"ok": true|false}` or HTTP status
- Concurrency, rate limiting (RPS), jitter, and pacing across many rows

## Prerequisites

- Go 1.25.x (for building)
- Local Redis on 127.0.0.1:6379 (required by the test server config)

## Build the test client

From the nauthilus repo:

```
cd client
go build -o nauthilus-testclient
```

## Prepare test data (CSV)

An example exists at client/logins.csv. Required column: expected_ok. Minimal example:

```
username,password,client_ip,expected_ok,user_agent,protocol,method,ssl,ssl_protocol,ssl_cipher,ssl_client_verify,ssl_client_cn
alice,secret,198.51.100.10,true,MyTestClient/1.0,imap,PLAIN,on,TLSv1.3,TLS_AES_128_GCM_SHA256,SUCCESS,alice-cn
bob,badpass,198.51.100.11,false,MyTestClient/1.0,imap,PLAIN,on,TLSv1.3,TLS_AES_128_GCM_SHA256,FAIL,bob-cn
```

Tip: Generate a large CSV (e.g., 10,000 rows):

```
# from the client/ directory
./nauthilus-testclient --generate-csv --generate-count 10000 --csv ./logins.csv
```

## Start the server with the test configuration

Use the repository’s YAML at client/nauthilus-testing.yml. It wires the Lua CSV backend and sets server.address to 0.0.0.0:8080.

```
TESTING_CSV=client/logins.csv \
./nauthilus -config client/nauthilus-testing.yml -config-format yaml
```

Notes:
- The Lua backend scripts are located under server/lua-plugins.d and are pre‑referenced in the YAML.
- The client defaults to POST http://localhost:8080/api/v1/auth/json.

## Run the load test

Typical run (CSV + JSON validation + rate limiting):

```
./nauthilus-testclient \
  --csv ./client/logins.csv \
  --url http://localhost:8080/api/v1/auth/json \
  --concurrency 32 \
  --rps 200 \
  --jitter-ms 50 \
  --json-ok
```

Useful options:
- --headers 'Header1: v1||Header2: v2' add extra headers
- --basic-auth username:password adds Authorization: Basic ... (unless provided via --headers)
- --method POST|GET (default: POST)
- --timeout 5s set HTTP timeout
- --duration 5m loop over the CSV for a total time (pairs well with --rps)
- --loops 3 run N complete passes over the CSV
- --shuffle randomize CSV order; --max N limit used rows
- --delay-ms N per‑request delay; --jitter-ms N adds randomness
- --json-ok=false switch to status‑based validation; override ok status via --ok-status (default 200)

## Result summary

At the end, the client prints aggregated counters:
- Requests total/failed
- Throughput (req/s)

## Tips for consistent numbers

- Keep the environment stable (hardware, config, data)
- Run multiple times and compare medians
- Run the client on a different machine than the server when possible

Repository references for this article:
- client/README.md (Nauthilus Test Client)
- client/nauthilus-testing.yml (server test config for Lua CSV backend)

## Why this matters (imagine this scenario)

If login gets slow, every other metric on your platform feels slow. Support tickets pile up (“I can’t log in”), caches can mask real issues, and the one endpoint everyone hits becomes your bottleneck. We built the CSV‑driven test client to make auth performance boring again: predictable, measurable, and easy to tune. Think of it as a sharp little scalpel rather than a sledgehammer—purpose‑built for authentication workloads, not a generic HTTP blaster.

Now imagine this plausible situation: during a 250 RPS mix, the failure rate creeps from ~0.2% to ~3% and throughput stops scaling. With a repeatable test, you quickly pinpoint the cause (for example, a retry tweak plus a tighter Redis pool), make two small changes, and watch failures drop back below 0.5% while throughput scales smoothly again. We didn’t actually hit this exact incident—treat it as a mental model—but it shows how systematic testing gives you decision‑ready numbers (throughput, failure rate, tipping points) and a fast feedback loop.

## A 5‑minute quickstart you can actually follow

1. Build the client (once):
   - cd client && go build -o nauthilus-testclient
2. Start Redis locally (default 127.0.0.1:6379).
3. Start the server with the test YAML:
   - TESTING_CSV=client/logins.csv ./nauthilus -config client/nauthilus-testing.yml -config-format yaml
4. Run a small load:
   - ./nauthilus-testclient --csv ./client/logins.csv --concurrency 8 --rps 40 --json-ok
5. Watch the summary (requests, failures, throughput). If it looks good, dial it up.

## Reading the numbers like a pro

- Throughput (req/s): Correlate with RPS and concurrency. If RPS is capped but requests back up, you’re hitting a limit (pool sizes, locks, I/O).
- Failures: Separate transport errors (timeouts, connection refused) from logical failures (`{"ok": false}`). They tell different stories.

Rule of thumb: As you increase RPS, the system should degrade gracefully. Sudden cliffs indicate a hard limit (thread pools, DB connections, Redis pool, Lua VM pool, etc.).

## Real‑world scenarios to copy and paste

- Baseline: --concurrency 16 --rps 100 --duration 2m
  - Purpose: Establish a steady reference. Repeat daily to detect regressions.
- Spike: --concurrency 128 --rps 0 (no rate limit) --max 2000
  - Purpose: What happens when everyone logs in at once? Watch failure bursts and throughput headroom.
- Soak: --concurrency 24 --rps 60 --duration 1h
  - Purpose: Memory growth, connection leaks, counters/evictions under sustained pressure.
- Stress to fail: --concurrency 256 --rps 800 --duration 10m
  - Purpose: Find the tipping point safely. Note at which RPS failures exceed 1% or throughput flattens.
- Chaos‑ish jitter: add --jitter-ms 100 and --shuffle to mimic real devices and ordering.

Tip: Run the client from a different host than the server to avoid CPU and NIC contention. If you must run on one box, cap RPS lower to avoid measuring the load generator instead of the server.

## Server‑side tuning hints (low‑risk first)

- Redis pool size: If you see timeouts or queueing, increase server.redis.pool_size and keep Redis local for tests.
- Lua VM pools: The testing YAML already sets backend/action/filter pools generously. If errors rise linearly with concurrency or throughput stalls, right‑size these pools.
- Caching: Use positive/negative cache TTLs wisely; authentication patterns often benefit from a short positive cache and a longer negative cache to damp brute force noise.
- Logging: Keep JSON logs and warn level for load tests—excessive logging is a latency tax.

## Client‑side recipes beyond the basics

- Mixed CSVs: Include both known‑good and known‑bad rows via expected_ok to verify business logic under load.
- Headers at scale: --headers 'X-Env: staging||X-Scenario: spike' makes runs self‑describing in logs.
- Pacing vs bursts: Prefer --rps with --duration for smooth load. Use high concurrency without --rps to study burst behavior.
- Debug a single row: --max 1 -v to verify mapping and server response before scaling up.

## Common pitfalls (and how to avoid them)

- The server looks fine at low RPS but collapses under load: Check external dependencies (LDAP/DB, Redis), and network MTU/misconfig.
- High failure rate with low CPU: Usually locks, pool depletion, GC pauses, or I/O waits. Correlate with server logs and Redis metrics.
- CSV mismatch: Ensure the header contains expected_ok and that delimiter detection isn’t fooled by semicolons. Use --csv-debug.
- Localhost illusions: Moving client and server onto separate machines often changes the picture dramatically.

## Troubleshooting checklist

- Validation mode: In JSON validation mode, ensure the server returns `{"ok": true|false}`. Otherwise run with --json-ok=false and rely on HTTP status.
- Timeouts: Increase --timeout (e.g., 5s → 10s) to separate slow from broken.
- Warm‑up: Always discard the first 30–60s of numbers; JITs, caches, and pools need to settle.
- Reproducibility: Pin versions, commit your exact command line into your run notes, and keep CSV seeds deterministic.

## Frequently asked questions

- Can I use it in CI? Yes. Keep RPS low, run a 30–60s baseline, and alert on deltas vs. the previous median.
- How big should my CSV be? Enough to reflect real variety. 1k–10k rows is common. Use the built‑in generator for scale.
- What’s a good target? Many auth flows aim for failure rate < 0.5% at steady‑state while maintaining the desired throughput. Your SLOs may differ; measure, then decide.
- How do I test brute force protections? Include bad credentials and watch failure rates alongside the brute_force buckets in the server config.

## A simple rubric for “good enough”

- At your expected peak RPS, failures < 0.5% and throughput meets your target.
- Doubling RPS may reduce per-request headroom, but shouldn’t produce runaway failures.
- Soak for 1h shows stable memory and steady throughput.

If you hit those, you’re in a healthy place. If not, you have a map above to iterate.

## Next steps and further reading

- Automate: Wrap your favorite scenarios in small shell scripts (or Make targets) so they’re easy to repeat.
- Compare builds: Run before/after on every auth change and track a simple dashboard of throughput and failure rate.
- Read the sources that power this article: client/README.md and client/nauthilus-testing.yml in the repository.

Happy testing—and may your failure rates stay boring.