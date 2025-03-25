---
title: Redis
description: Common Redis related functions
keywords: [Lua]
sidebar_position: 12
---
# Redis

There is basic Redis support in Nauthilus. Most of the time it should be enough to use simple Redis keys and string values
as arguments. Type conversion can be done within Lua itself.

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")
```

---

# Redis custom pools

In the init script of the Nauthilus server, you can define custom pools. For each Redis command, the first parameter is
either a string called "default" or a connection handle. The "default" will use Redis servers from the Nauthilus server itself.

## How to register a new pool?

Register a custom pool

### Syntax

```lua
local result, error = nauthilus_redis.register_redis_pool(name, mode, config,)
```
### Parameters

- `name` (string) - Name of the new redis pool
- `mode` (string) - Defines the type of redis configuration, Possible values are:
- * **standalone** - Configure a simple standalone Redis instance
  * **cluster** - Configure a Redis cluster
  * **sentinel** - Configure a Redis sentinel
  * **sentinel\_replica** - Configure a failover client primaryly for read requests
- `config` (table) - The configuration parameters for the new pool
  * **address** (string) - Address for the standalone system (master or replica)
  * **addresses** (table) - List of addresses for clusters and sentinels
  * **master\_name** (string) - Master name is for sentinels
  * **sentinel\_username** (string) - Optional username for sentinels
  * **sentinel\_password** (string) - Optional password for sentinels
  * **username** (string) - Optional username (used for standalone or sentinel setups)
  * **password** (string) - Optional password (used for standalone or sentinel setups)
  * **db** (number) - The database number in Redis
  * **pool\_size** (number) - Maximum number of connections in the pool
  * **min\_idle\_conns** (number) - Minimum number of idle connections in the pool
  * **tls\_enabled** (boolean) - Activates TLS support
  * **tls\_cert\_file** (string) - Optional path to a certificate file in PEM format
  * **tls\_key\_file** (string) - Optional path to a key file in PEM format
  
### Returns

- `result` (string) -  "OK" is returned, if the pool was configured successfully.
- `error` (string) - An error message, if an error occurs.

### Example

```lua
local _, err_redis_reg = nauthilus_redis.register_redis_pool("my_custom_name", "sentinel", {
            addresses = { "redis-sentinel-sentinel.ot-operators:26379" },
            master_name = "myMaster",
            password = "",
            db = 3,
            pool_size = 10,
            min_idle_conns = 1,
            tls_enabled = false
        })
```

To get the handle of this pool, do the following in you Lua scripts:

```lua
local custom_pool, err_redis_client = nauthilus_redis.get_redis_connection("my_custom_name")
```

Now you can use **custom\_pool** as the first argument to each Redis function.

You can define as many pools as you like. Currently supported is "standalone", "sentinel" and "cluster".

Documentation for the parameters is TODO.

In the following, I will use the name "handle" for a pool handler.

---

# Functions

## nauthilus\_redis.redis\_set

You can store a value in Redis with the following function:

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_set(handle, "key", "value", 3600)
```

The expiration value is optional.

If anything went fine, "OK" is returned as **result**. In cases of errors, the **result** equals nil and a string is returned as **error**.

## nauthilus\_redis.redis\_incr

You can increment a value in Redis with the following function:

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local number, error = nauthilus_redis.redis_incr(handle, "key")
```

If anything went fine, the current **number** is returned. In cases of an **error**, number equals nil and a string is returned.

## nauthilus\_redis.redis\_get

To retrieve a value from Redis use the following function:

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_get(handle, "key")
```

If anything went fine, the returned value is stored in **result**. In cases of errors, the **result** equals nil and a string is returned to **error*.

## nauthilus\_redis.redis\_expire

A Redis key can have an expiration time in seconds. Use the following function to achieve this goal:

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_expire(handle, "key")
```

If anything went fine, "OK" is returned as **result**. In cases of errors, the **result** equals nil and a string is returned as **error**.

## nauthilus\_redis.redis\_del

To delete a Redis key, use the following function:

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_del(handle, "key")
```
If anything went fine, "OK" is returned as **result**. In cases of errors, the **result** equals nil and a string is returned as **error**.

## nauthilus\_redis.redis\_rename

Rename a Redis key

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local oldkey = "abc"
local newkey = "def"

local result, err = nauthilus_redis.redis_rename(handle, oldkey, newkey)
```

## nauthilus\_redis.redis\_hget

Get a value from a Redis hash map

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local already_sent_mail, err_redis_hget2 = nauthilus_redis.redis_hget(handle, redis_key, "send_mail")
```

## nauthilus\_redis.redis\_hset

Set a value in a Redis hash map

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local _, err_redis_hset = nauthilus_redis.redis_hset(handle, redis_key, "send_mail", 1)
```

## nauthilus\_redis.redis\_hdel

Delete a key from a Redis hash map

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result = {}
result.dovecot_session = "123"

local redis_key = "some_key"
local deleted, err_redis_hdel = nauthilus_redis.redis_hdel(handle, redis_key, result.dovecot_session)
```

## nauthilus\_redis.redis\_hlen

Get the number of entries in a hash map

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local length, err_redis_hlen = nauthilus_redis.redis_hlen(handle, redis_key)
```

## nauthilus\_redis.redis\_hgetall

Get all values from a Redis hash map

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local all_sessions, err_redis_hgetall = nauthilus_redis.redis_hgetall(handle, redis_key)
```

## nauthilus\_redis.redis\_hincrby

Increament the value (integer) of a Redis hash map key

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local field = "some_field"
local increment = 1

local result, err = nauthilus_redis.redis_hincrby(handle, key, field, increment)
```

## nauthilus\_redis.redis\_hincrbyfloat

Increament the value (float) of a Redis hash map key

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local field = "some_field"
local increment = 1.3

local result, err = nauthilus_redis.redis_hincrbyfloat(handle, key, field, increment)
```

## nauthilus\_redis.redis\_hexists

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local field = "some_field"

local result, err = nauthilus_redis.redis_hexists(handle, key, field)
```

## nauthilus\_redis.redis\_sadd

Add a value to a Redis set

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local value = "some_value"

local result, err = nauthilus_redis.redis_sadd(handle, key, value)
```

## nauthilus\_redis.redis\_sismember

Check, if a value is a mamber of a Redis set

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local value = "some_value"

local result, err = nauthilus_redis.redis_sismember(handle, key, value)
```
## nauthilus\_redis.redis\_smembers

Get all members from a Redis set

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"

local result, err = nauthilus_redis.redis_smembers(handle, key)
```

## nauthilus\_redis.redis\_srem

Remove a value from a Redis set

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local value = "some_value"

local result, err = nauthilus_redis.redis_srem(handle, key, value)
```

## nauthilus\_redis.redis\_scard

Return the number of values inside a Redis set

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"

local result, err = nauthilus_redis.redis_scard(handle, key)
```

## nauthilus\_redis.redis\_upload\script

Upload a Redis script onto a Redis server. If successful an sha1 hash is returned, nil on failure with an error returned as second result.

### Syntax

### Parameters

### Returns

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local script = [[
        local redis_key = KEYS[1]
        local send_mail = redis.call('HGET', redis_key, 'send_mail')

        if send_mail == false then
            redis.call('HSET', redis_key, 'send_mail', '1')

            return {'send_email', redis_key}
        else
            return {'email_already_sent'}
        end
    ]]

local upload_script_name = "nauthilus_send_mail_hash"
local sha1, err_upload = nauthilus_redis.redis_upload_script(handle, script, upload_script_name)
```

:::tip
Use an init script to upload scripts at startup
:::

## nauthilus\_redis.redis\_run\_script

With this command, you can either upload a script and run it once, or you can run an already uploaded script by
giving the upload-script-name (defined by an upload call earlier. See above).

### Syntax

### Parameters

### Returns

### Example

```lua
local redis_key = "some_redis_key"
local script = ""
local upload_script_name = "nauthilus_send_mail_hash"

-- Set either script or upload_script_name!
local script_result, err_run_script = nauthilus_redis.redis_run_script(handle, script, upload_script_name, { redis_key }, {})
```

:::note
If running a script, you must set the upload-script-name to ""
:::


## nauthilus\_redis.redis\_zadd

_New in version 1.4.10_

Adds members with their associated scores to a Redis Sorted Set.

### Syntax

```lua
local result, err = nauthilus_redis.redis_zadd(key, members)
```

### Parameters

- `key` (string): The name of the Redis Sorted Set.
- `members` (table): A Lua table where:
  - **Keys** are the members (strings).
  - **Values** are the scores (numbers).

### Returns

- `result` (number): The total number of members successfully added.
- `err` (string): An error message, if an error occurs.

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local added, err = nauthilus_redis.redis_zadd("my_sorted_set", { member1 = 10, member2 = 20 })
if err then
    print("Error:", err)
else
    print("Added elements:", added)
end
```

---

## nauthilus\_redis.redis\_zrange

_New in version 1.4.10_

Retrieves a subset of elements from a Redis Sorted Set based on an index range (in ascending order).

### Syntax

```lua
local elements, err = nauthilus_redis.redis_zrange(key, start, stop)
```

### Parameters

- `key` (string): The name of the Redis Sorted Set.
- `start` (number): The starting index of the range.
- `stop` (number): The stopping index of the range.

### Returns

- `elements` (table): A Lua table containing the retrieved elements.
- `err` (string): An error message, if an error occurs.

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local elements, err = nauthilus_redis.redis_zrange("my_sorted_set", 0, -1)
if err then
    print("Error:", err)
else
    for _, val in ipairs(elements) do
        print(val)
    end
end
```

---

## nauthilus\_redis.redis\_zrevrange

_New in version 1.4.10_

Retrieves a subset of elements from a Redis Sorted Set in descending order based on an index range.

### Syntax

```lua
local elements, err = nauthilus_redis.redis_zrevrange(key, start, stop)
```

### Parameters
- `key` (string): The name of the Redis Sorted Set.
- `start` (number): The starting index of the range.
- `stop` (number): The stopping index of the range.

### Returns
- `elements` (table): A Lua table containing the retrieved elements.
- `err` (string): An error message, if an error occurs.

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local elements, err = nauthilus_redis.redis_zrevrange("my_sorted_set", 0, -1)
if err then
    print("Error:", err)
else
    for _, val in ipairs(elements) do
        print(val)
    end
end
```

---

## nauthilus\_redis.redis\_zrangebyscore

_New in version 1.4.10_

Retrieves elements within a score range from a Redis Sorted Set. Optional pagination is supported.

### Syntax

```lua
local elements, err = nauthilus_redis.redis_zrangebyscore(key, min_score, max_score, options)
```

### Parameters

- `key` (string): The name of the Redis Sorted Set.
- `min_score` (number): The lower bound of the score range.
- `max_score` (number): The upper bound of the score range.
- `options` (table, optional): A Lua table for optional pagination:
  - `offset` (number): The starting position of the results.
  - `count` (number): The maximum number of results retrieved.

### Returns

- `elements` (table): A Lua table containing the retrieved elements.
- `err` (string): An error message, if an error occurs.

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local elements, err = nauthilus_redis.redis_zrangebyscore("my_sorted_set", 10, 50, { offset = 0, count = 5 })
if err then
    print("Error:", err)
else
    for _, val in ipairs(elements) do
        print(val)
    end
end
```

---

## nauthilus\_redis.redis\_zrem

_New in version 1.4.10_

Removes members from a Redis Sorted Set.

### Syntax

```lua
local result, err = nauthilus_redis.redis_zrem(key, members)
```

### Parameters

- `key` (string): The name of the Redis Sorted Set.
- `members` (table): A Lua table containing the members (as strings) to be removed.

### Returns

- `result` (number): The number of members successfully removed.
- `err` (string): An error message, if an error occurs.

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local removed, err = nauthilus_redis.redis_zrem("my_sorted_set", { "member1", "member2" })
if err then
    print("Error:", err)
else
    print("Removed elements:", removed)
end
```

---

## nauthilus\_redis.redis\_zrank

_New in version 1.4.10_

Gets the rank of a member in a Redis Sorted Set, with scores sorted in ascending order.

### Syntax

```lua
local rank, err = nauthilus_redis.redis_zrank(key, member)
```

### Parameters

- `key` (string): The name of the Redis Sorted Set.
- `member` (string): The member whose rank you want to retrieve.

### Returns

- `rank` (number): The rank of the member (0-based index).
- `err` (string): An error message, if an error occurs.

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local rank, err = nauthilus_redis.redis_zrank("my_sorted_set", "member1")
if err then
    print("Error:", err)
else
    print("Rank of member:", rank)
end
```

---

## nauthilus\_redis.redis\_zremrangebyscore

_New in version 1.4.10_

Removes all members within a given score range from a Redis Sorted Set.

### Syntax

```lua
local result, err = nauthilus_redis.redis_zremrangebyscore(key, min_score, max_score)
```

### Parameters

- `key` (string): The name of the Redis Sorted Set.
- `min_score` (number): The lower bound of the score range.
- `max_score` (number): The upper bound of the score range.

### Returns

- `result` (number): The number of members removed.
- `err` (string): An error message, if an error occurs.

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local removed, err = nauthilus_redis.redis_zremrangebyscore("my_sorted_set", 10, 20)
if err then
    print("Error:", err)
else
    print("Removed elements:", removed)
end
```
