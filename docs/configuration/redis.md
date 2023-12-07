---
title: Redis
sidebar_position: 3
---
# Redis

Nauthilus requires Redis to store metrics and user password histories. The latter is used by the "cache" backend. See
below in this document.

<!-- TOC -->
* [Redis](#redis)
  * [Standalone](#standalone)
      * [NAUTHILUS_REDIS_ADDRESS, NAUTHILUS_REDIS_PORT](#nauthilusredisaddress-nauthilusredisport)
      * [NAUTHILUS_REDIS_REPLICA_ADDRESS, NAUTHILUS_REDIS_REPLICA_PORT](#nauthilusredisreplicaaddress-nauthilusredisreplicaport)
  * [Sentinel](#sentinel)
      * [NAUTHILUS_REDIS_SENTINEL_MASTER_NAME](#nauthilusredissentinelmastername)
      * [NAUTHILUS_REDIS_SENTINELS](#nauthilusredissentinels)
  * [Backend support](#backend-support)
<!-- TOC -->

Internally it manages a pool of connections depending on the way you have configured it.

## Standalone

If nauthilus can reach the address 127.0.0.1 on port 6379, everything is fine and it uses the connection automatically
for reading and writing. If you require a different address or port, you must configure the following environment
variables:

#### NAUTHILUS_REDIS_ADDRESS, NAUTHILUS_REDIS_PORT

This is an IP address and port that is used for writing to Redis.

#### NAUTHILUS_REDIS_REPLICA_ADDRESS, NAUTHILUS_REDIS_REPLICA_PORT

This is an IP address and port that is used for reading from Redis.

> Note
>
> If you change the address of NAUTHILUS_REDIS_ADDRESS, you must also modify NAUTHILUS_REDIS_REPLICA_ADDRESS, if the same
> Redis server shall be used for reading and writing!

The current implementation compares the variable address/port pairs and if they differ, it starts two different pools.

## Sentinel

Nauthilus can work with sentinels to manage the Redis connections. This way, you only need to specify a list of sentinel
servers and the name of the "master".

#### NAUTHILUS_REDIS_SENTINEL_MASTER_NAME

This is the name of the "master". In Redis you would find aline similar to this:

```
sentinel monitor mymaster 192.168.0.2 6379 2
```

#### NAUTHILUS_REDIS_SENTINELS

This is a space seperated list of ip:port pairs, each specifying a sentinel server.

## Backend support

You can use Redis as a password backend in front of any other database. Simply add the word "cache" to the list of
backends. Note that the position matters, as backends are processed from left to right and the rule is: First match
wins!

To add it, use the environment variable NAUTHILUS_PASSDB_BACKENDS.
