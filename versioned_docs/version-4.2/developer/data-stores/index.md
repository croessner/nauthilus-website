---
title: Data Stores
description: Developer references for the Redis keyspace and the ClickHouse data model that Nauthilus reads and writes
keywords: [Nauthilus, Developer, Redis, ClickHouse, Keyspace, Data Model, Schema]
sidebar_position: 1
---

# Data Stores

Nauthilus keeps its state in two stores. This section documents what is stored where, which code owns it, and how long
it lives. It is written for developers who add or change stored state, and for operators who inspect Redis or
ClickHouse and want to know what they are looking at.

| Store | What it holds | Reference |
| --- | --- | --- |
| Redis | Runtime state: caches, brute-force counters and bans, account mapping, OIDC tokens and codes, browser sessions and flows, SAML logout state, and the keys and Lua scripts of the bundled plugins | [Redis Keyspace Reference](./redis-keyspace.md) |
| ClickHouse | The durable history of authentication requests, step events, and brute-force evidence that the support history reads. Optional: Nauthilus stays fully operable without it | [ClickHouse Data Model Reference](./clickhouse-data-model.md) |

Both references follow the same rules:

- **Code is the authority.** Every entry points at the Go constant, builder function, Lua helper, or DDL object that
  defines it, so the reference can be checked with `grep`. When a change adds, renames, or removes a key or a column,
  the reference is updated in the same change.
- **Paths refer to the repository.** Paths such as `server/...` and `contrib/...` name files in the Nauthilus source
  repository. They are not links on this site, because the files are source code, DDL, and scripts.

## Where to start

| You want to | Start here |
| --- | --- |
| Find out which keys a feature creates, and when they expire | [Key overview](./redis-keyspace.md#2-key-overview) |
| Understand Redis Cluster hash tags and why a key has one | [Hash tags and Redis Cluster](./redis-keyspace.md#12-hash-tags-and-redis-cluster) |
| Add a Redis key to the server or a plugin | [Adding a key](./redis-keyspace.md#16-adding-a-key) |
| Inspect brute-force counters, bans, or toleration state in Redis | [Brute-force protection keys](./redis-keyspace.md#31-brute-force-protection) |
| Review the Redis Lua scripts and the Redis use without keys | [Redis Lua scripts](./redis-keyspace.md#4-redis-lua-scripts) |
| See which ClickHouse tables exist and who writes and reads them | [Purpose and overview](./clickhouse-data-model.md#1-purpose-and-overview) |
| Look up a column of `logins` and the component that fills it | [`nauthilus.logins`](./clickhouse-data-model.md#41-nauthiluslogins) |
| Provision the read-only account for the support history | [Access model](./clickhouse-data-model.md#6-access-model) |
| Upgrade or migrate the ClickHouse schema | [Schema files, migrations, and versions](./clickhouse-data-model.md#7-schema-files-migrations-and-versions) |

## Related operator pages

- [Server configuration: `storage`](../../configuration/server-configuration.md#storage) configures Redis, its
  topologies, and the support history reader.
- [ClickHouse plugin reference](../go-plugins/reference-plugins/clickhouse.md) describes the plugin that writes the
  ClickHouse tables, its streams, and its configuration.
- [Support Authentication History](../../guides/support-authentication-history.md) is the read-only API that answers
  support questions from the ClickHouse evidence.
- [Brute Force Protection](../../configuration/brute-force.md) explains the behavior behind the brute-force keys and
  evidence tables.
