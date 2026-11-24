---
title: Lua Cookbook
description: Tested, runnable Docker recipes that show every Lua interface of Nauthilus with everyday administrator tasks
keywords: [Lua, Cookbook, Examples, Docker, Recipes, Hooks, Backend, Policy]
sidebar_position: 1
---

# Lua Cookbook

The Lua Cookbook is a set of small, complete Nauthilus installations. Each recipe solves one everyday task of a mail
or identity administrator with a few lines of Lua: a user list in a file, a maintenance switch, an IP blocklist, a
login journal, and more. Every recipe

- starts with one `docker compose up`,
- contains every file it needs, with comments in the files themselves,
- ships a `test.sh` that proves the recipe works, and
- is explained file by file on its page.

The recipes are tested against the released Nauthilus image and, by the Nauthilus maintainers, against every new build
with the Lua JIT switched on and off. When a recipe page says "this works", a test has checked it.

## What you need

- Docker with the Compose plugin (`docker compose version`)
- `curl` and `bash` for the test scripts
- `openssl` for the recipes that create key material

Nothing is installed on your machine. Every stack listens only on `127.0.0.1`.

## The recipes

| Recipe | Everyday task | Lua interfaces | Port |
|---|---|---|---|
| [Flat-file users](flatfile-users.mdx) | Keep accounts in a text file instead of a directory server | init script, Lua backend, cache-flush callback | 28081 |
| [SQL users](sql-users.mdx) | Authenticate against an existing MariaDB/MySQL account table, including TOTP enrolment | Lua backend with account listing and MFA callbacks | 28082 |
| [Admin toolkit](admin-toolkit.mdx) | Switch on a maintenance mode and block networks through a small HTTP API | custom hooks, environment sources, policy registry | 28083 |
| [Account rules](account-rules.mdx) | Allow protocols per account, lock accounts during offboarding | subject sources, policy registry | 28084 |
| [Login journal](login-journal.mdx) | Answer "when did this user last log in, and from where?" and mail the admin on brute-force blocks | POST-action, brute-force action | 28085 |
| [Country rules per account](geo-regions.mdx) | Let some accounts log in only from the countries of their region | native Go plugin (GeoIP) together with a Lua environment source | 28087 |
| [Learning IP reputation](reputation.mdx) | Learn which addresses misbehave, protect privileged accounts from them, and override per address or network | native Go plugin (reputation) together with a Lua environment source | 28088 |
| [Policy API](policy-api.mdx) | Let a VPN gateway ask "may this user connect now?" | generic policy provider (`kind: lua`) | 28086 |

Every recipe page has the same structure: what the recipe does, how to start and test it, the configuration, every
Lua script with an explanation, and ideas for your own changes. Read [Flat-file users](flatfile-users.mdx) first if
Nauthilus is new to you; it explains the parts that all recipes share.

## Lua interfaces at a glance

Nauthilus calls Lua at many points. Each point expects a script with a fixed entry function:

| Interface | Entry function | Runs | Shown in |
|---|---|---|---|
| Init script | `nauthilus_run_hook(request)` | once when the process starts | Flat-file users |
| Lua backend | `nauthilus_backend_verify_password(request)`, `nauthilus_backend_list_accounts()` | for every password check that is not answered from the cache | Flat-file users, SQL users |
| Backend MFA callbacks | `nauthilus_backend_add_totp(request)` and friends | when TOTP or recovery codes are enrolled or removed | SQL users |
| Cache-flush callback | `nauthilus_cache_flush(request)` | for `DELETE /api/v1/cache/flush` | Flat-file users |
| Environment source | `nauthilus_call_environment(request)` | before the password is checked | Admin toolkit |
| Subject source | `nauthilus_call_subject(request)` | after the password is checked | Account rules |
| Action | `nauthilus_call_action(request)` | when a policy rule selects it, while the request waits | Login journal |
| POST-action | `nauthilus_call_action(request)` | after the answer was sent | Login journal |
| Custom hook | `nauthilus_run_hook(request)` | for `/api/v1/custom/<location>` | Admin toolkit |
| Policy registry script | top-level `nauthilus_policy.register_attribute(...)` | when the policy snapshot is built | Admin toolkit, Account rules |
| Generic policy provider | `_G["policy.facts.collect"]`, `_G["policy.effects.execute"]` | for the Policy decision API | Policy API |

Native Go plugins are the other way to extend Nauthilus. They deliver facts and effects to the same policy as Lua
scripts; [Country rules per account](geo-regions.mdx) combines the bundled GeoIP plugin with a Lua environment source,
and [Learning IP reputation](reputation.mdx) does the same with the bundled reputation plugin.

The [Lua API reference](../lua-api/introduction.md) describes every module. [Lua runtimes and
capabilities](../lua-api/runtimes.md) explains which modules each interface can use.

## Run a recipe

Download a recipe as an archive from its page, or take the files from the
[website repository](https://github.com/croessner/nauthilus-website/tree/main/static/cookbook). An archive unpacks
into `cookbook/<recipe>/` together with the shared test helper `cookbook/lib/cookbook.sh`:

```bash
curl -fsSLO https://nauthilus.org/cookbook/flatfile-users.tar.gz
tar -xzf flatfile-users.tar.gz
cd cookbook/flatfile-users
docker compose up -d --wait
./test.sh
```

`test.sh` prints one line per check and a summary:

```text
Lua backend: password checks
  ok    alice logs in (bcrypt hash)
  ok    bob logs in (SHA512-crypt hash)
  ...
16 checks passed, 0 failed, 0 known issues
```

A line that starts with `known` marks a check that is held back by a reported Nauthilus bug. It does not fail the run,
and it turns into an `ok` line as soon as a release fixes the bug.

Stop and remove a stack, including its data, with:

```bash
docker compose down -v
```

## Choose the Nauthilus image

The compose files use the released image `ghcr.io/croessner/nauthilus:v4.2.0`. The recipes need Nauthilus 4.1.3 or
later. Two environment variables change the image:

| Variable | Default | Meaning |
|---|---|---|
| `NAUTHILUS_IMAGE` | `ghcr.io/croessner/nauthilus:v4.2.0` | Image to start, for example a local build |
| `NAUTHILUS_LUA_JIT` | `true` | Switches the Lua JIT compiler of Nauthilus 4.2 and later on or off; earlier releases ignore it |

```bash
NAUTHILUS_IMAGE=nauthilus:dev NAUTHILUS_LUA_JIT=false docker compose up -d --wait
```

`run-all.sh` in the `cookbook` directory starts, tests, and removes every recipe one after the other. The Nauthilus
maintainers run it for every release with the JIT on and off:

```bash
NAUTHILUS_IMAGE=nauthilus:dev ./run-all.sh
NAUTHILUS_IMAGE=nauthilus:dev NAUTHILUS_LUA_JIT=false ./run-all.sh
```

## Rules the recipes follow

- **Secrets are demo values.** Passwords, nonces, and keys in the files are public. Replace every one before you copy
  a recipe into a real installation.
- **Callers get scoped credentials.** The mail server credential may only check logins; the administrator credential
  holds only the scopes it needs. See [Backchannel Basic credentials](../rest-api.md#backchannel-basic-credentials).
- **Lua emits facts, the policy decides.** Scripts that should stop a login emit a registered policy attribute, and a
  rule in `nauthilus.yml` turns it into `deny` or `tempfail`. The decision stays visible in the configuration.
- **Shared code lives in modules.** When two scripts need the same logic, it lives in one module that both load with
  `require`. `package_path` in `nauthilus.yml` tells Nauthilus where to find it.

## Problems these recipes found

Building the cookbook found several Nauthilus defects. All of them are fixed in Nauthilus 4.1.3 and 4.2.0, which is
why the recipes need 4.1.3 or later. See the [4.1.3 release notes](../release-notes/4.1-patch-releases.md):

- A Lua environment source that returned `ENVIRONMENT_TRIGGER_YES` did not reject the login (security fix).
- A `tempfail` rule answered with the generic temporary-failure text instead of its `response_message`.
- A rule whose `response_message` used `from: attribute_detail` stopped Nauthilus from starting, although
  `--config-check` accepted the configuration.
- Configured rules at `subject_analysis` did not see the attributes of subject sources.
- A custom hook that set the HTTP status and returned a Lua table sent an empty body.
- `nauthilus_backend_add_totp` did not receive `request.totp_secret`.
- `mode=list-accounts` with `Accept: text/plain` returned only one account.

When a future release breaks a recipe, its test prints a failing check, and a check that waits for a reported fix is
printed as `known`.
- `mode=list-accounts` with `Accept: text/plain` returns only one account; use `application/json`.
