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
local result, error = nauthilus_redis.register_redis_pool(name, mode, config)
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

Stores a value in Redis with an optional expiration time.

### Syntax

```lua
local result, error = nauthilus_redis.redis_set(handle, key, value, expiration)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key to store the value under
- `value` (string): The value to store
- `expiration` (number, optional): Time in seconds after which the key will expire

### Returns

- `result` (string): "OK" if the operation was successful
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_set(handle, "key", "value", 3600)
```

## nauthilus\_redis.redis\_incr

Increments a numeric value stored in Redis by one.

### Syntax

```lua
local number, error = nauthilus_redis.redis_incr(handle, key)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key whose value should be incremented

### Returns

- `number` (number): The new value after incrementing
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local number, error = nauthilus_redis.redis_incr(handle, "key")
```

## nauthilus\_redis.redis\_get

Retrieves a value from Redis by key.

### Syntax

```lua
local result, error = nauthilus_redis.redis_get(handle, key)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key to retrieve the value for

### Returns

- `result` (string): The value stored at the specified key
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_get(handle, "key")
```

## nauthilus\_redis.redis\_expire

Sets an expiration time (in seconds) for a Redis key.

### Syntax

```lua
local result, error = nauthilus_redis.redis_expire(handle, key, seconds)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key to set expiration for
- `seconds` (number): The expiration time in seconds

### Returns

- `result` (string): "OK" if the operation was successful
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_expire(handle, "key", 3600)
```

## nauthilus\_redis.redis\_del

Deletes a key from Redis.

### Syntax

```lua
local result, error = nauthilus_redis.redis_del(handle, key)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key to delete

### Returns

- `result` (string): "OK" if the operation was successful
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_del(handle, "key")
```

## nauthilus\_redis.redis\_rename

Renames a Redis key to a new name.

### Syntax

```lua
local result, err = nauthilus_redis.redis_rename(handle, oldkey, newkey)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `oldkey` (string): The current name of the Redis key
- `newkey` (string): The new name for the Redis key

### Returns

- `result` (string): "OK" if the operation was successful
- `err` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local oldkey = "abc"
local newkey = "def"

local result, err = nauthilus_redis.redis_rename(handle, oldkey, newkey)
```

## nauthilus\_redis.redis\_hget

Retrieves a value for a specific field from a Redis hash map.

### Syntax

```lua
local value, error = nauthilus_redis.redis_hget(handle, key, field)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the hash map
- `field` (string): The field name within the hash map

### Returns

- `value` (string): The value of the specified field
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local already_sent_mail, err_redis_hget = nauthilus_redis.redis_hget(handle, redis_key, "send_mail")
```

## nauthilus\_redis.redis\_hset

Sets a field value in a Redis hash map.

### Syntax

```lua
local result, error = nauthilus_redis.redis_hset(handle, key, field, value)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the hash map
- `field` (string): The field name within the hash map
- `value` (string/number): The value to set for the field

### Returns

- `result` (number): 1 if field is a new field in the hash and value was set, 0 if field already exists and the value was updated
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local result, err_redis_hset = nauthilus_redis.redis_hset(handle, redis_key, "send_mail", 1)
```

## nauthilus\_redis.redis\_hdel

Deletes a field from a Redis hash map.

### Syntax

```lua
local deleted, error = nauthilus_redis.redis_hdel(handle, key, field)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the hash map
- `field` (string): The field name to delete from the hash map

### Returns

- `deleted` (number): The number of fields that were removed (1 if successful, 0 if field did not exist)
- `error` (string): An error message if the operation fails

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

Gets the number of fields in a Redis hash map.

### Syntax

```lua
local length, error = nauthilus_redis.redis_hlen(handle, key)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the hash map

### Returns

- `length` (number): The number of fields in the hash map
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local length, err_redis_hlen = nauthilus_redis.redis_hlen(handle, redis_key)
```

## nauthilus\_redis.redis\_hgetall

Retrieves all fields and values from a Redis hash map.

### Syntax

```lua
local hash_table, error = nauthilus_redis.redis_hgetall(handle, key)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the hash map

### Returns

- `hash_table` (table): A Lua table containing all field-value pairs from the hash map
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local all_sessions, err_redis_hgetall = nauthilus_redis.redis_hgetall(handle, redis_key)
```

## nauthilus\_redis.redis\_hincrby

Increments the integer value of a field in a Redis hash map by a specified amount.

### Syntax

```lua
local new_value, error = nauthilus_redis.redis_hincrby(handle, key, field, increment)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the hash map
- `field` (string): The field name within the hash map
- `increment` (number): The integer value to increment by

### Returns

- `new_value` (number): The new value of the field after the increment operation
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local field = "some_field"
local increment = 1

local new_value, err = nauthilus_redis.redis_hincrby(handle, key, field, increment)
```

## nauthilus\_redis.redis\_hincrbyfloat

Increments the floating-point value of a field in a Redis hash map by a specified amount.

### Syntax

```lua
local new_value, error = nauthilus_redis.redis_hincrbyfloat(handle, key, field, increment)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the hash map
- `field` (string): The field name within the hash map
- `increment` (number): The floating-point value to increment by

### Returns

- `new_value` (string): The new value of the field after the increment operation (as a string representation of the float)
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local field = "some_field"
local increment = 1.3

local new_value, err = nauthilus_redis.redis_hincrbyfloat(handle, key, field, increment)
```

## nauthilus\_redis.redis\_hexists

Checks if a field exists in a Redis hash map.

### Syntax

```lua
local exists, error = nauthilus_redis.redis_hexists(handle, key, field)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the hash map
- `field` (string): The field name to check for existence

### Returns

- `exists` (number): 1 if the field exists in the hash, 0 if it does not exist
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local field = "some_field"

local exists, err = nauthilus_redis.redis_hexists(handle, key, field)
```

## nauthilus\_redis.redis\_sadd

Adds a member to a Redis set.

### Syntax

```lua
local added, error = nauthilus_redis.redis_sadd(handle, key, value)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the set
- `value` (string): The value to add to the set

### Returns

- `added` (number): 1 if the member was added to the set, 0 if it was already a member
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local value = "some_value"

local added, err = nauthilus_redis.redis_sadd(handle, key, value)
```

## nauthilus\_redis.redis\_sismember

Checks if a value is a member of a Redis set.

### Syntax

```lua
local is_member, error = nauthilus_redis.redis_sismember(handle, key, value)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the set
- `value` (string): The value to check for membership

### Returns

- `is_member` (number): 1 if the value is a member of the set, 0 if it is not
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local value = "some_value"

local is_member, err = nauthilus_redis.redis_sismember(handle, key, value)
```
## nauthilus\_redis.redis\_smembers

Retrieves all members from a Redis set.

### Syntax

```lua
local members, error = nauthilus_redis.redis_smembers(handle, key)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the set

### Returns

- `members` (table): A Lua table containing all members of the set
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"

local members, err = nauthilus_redis.redis_smembers(handle, key)
```

## nauthilus\_redis.redis\_srem

Removes a member from a Redis set.

### Syntax

```lua
local removed, error = nauthilus_redis.redis_srem(handle, key, value)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the set
- `value` (string): The value to remove from the set

### Returns

- `removed` (number): 1 if the member was removed from the set, 0 if it was not a member
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local value = "some_value"

local removed, err = nauthilus_redis.redis_srem(handle, key, value)
```

## nauthilus\_redis.redis\_scard

Returns the number of members in a Redis set.

### Syntax

```lua
local count, error = nauthilus_redis.redis_scard(handle, key)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the set

### Returns

- `count` (number): The number of members in the set
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"

local count, err = nauthilus_redis.redis_scard(handle, key)
```

## nauthilus\_redis.redis\_upload\_script

Uploads a Lua script to a Redis server for later execution.

### Syntax

```lua
local sha1, error = nauthilus_redis.redis_upload_script(handle, script, script_name)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `script` (string): The Lua script to upload to the Redis server
- `script_name` (string): A name to identify the script for later execution

### Returns

- `sha1` (string): The SHA1 hash of the script, used to identify it when executing
- `error` (string): An error message if the operation fails

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

Executes a Lua script on a Redis server, either by providing the script directly or by referencing a previously uploaded script.

### Syntax

```lua
local result, error = nauthilus_redis.redis_run_script(handle, script, script_name, keys, args)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `script` (string): The Lua script to execute (leave empty if using script_name)
- `script_name` (string): The name of a previously uploaded script (leave empty if providing script directly)
- `keys` (table): A Lua table containing the Redis keys that will be accessed by the script
- `args` (table): A Lua table containing additional arguments for the script

### Returns

- `result` (any): The result returned by the executed script
- `error` (string): An error message if the operation fails

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

---

## nauthilus\_redis.redis\_zcount

_New in version 1.7.7_

Counts the number of members in a Redis Sorted Set with scores between min and max.

### Syntax

```lua
local count, err = nauthilus_redis.redis_zcount(handle, key, min, max)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The name of the Redis Sorted Set
- `min` (string): The minimum score (can be a number or "-inf")
- `max` (string): The maximum score (can be a number or "+inf")

### Returns

- `count` (number): The number of members in the specified score range
- `err` (string): An error message, if an error occurs

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local count, err = nauthilus_redis.redis_zcount("default", "my_sorted_set", "10", "20")
if err then
    print("Error:", err)
else
    print("Number of members in range:", count)
end
```

---

## nauthilus\_redis.redis\_zscore

_New in version 1.7.7_

Retrieves the score of a member in a Redis Sorted Set.

### Syntax

```lua
local score, err = nauthilus_redis.redis_zscore(handle, key, member)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The name of the Redis Sorted Set
- `member` (string): The member whose score you want to retrieve

### Returns

- `score` (number): The score of the member in the sorted set
- `err` (string): An error message if the operation fails or if the member does not exist

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local score, err = nauthilus_redis.redis_zscore("default", "my_sorted_set", "member1")
if err then
    print("Error:", err)
else
    print("Score of member:", score)
end
```

---

## nauthilus\_redis.redis\_lpush

_New in version 1.7.7_

Adds one or more values to the beginning of a Redis list and returns the length of the list after the push operation.

### Syntax

```lua
local length, error = nauthilus_redis.redis_lpush(handle, key, value1, value2, ...)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the list
- `value1` (string/number): The first value to add to the beginning of the list
- `value2, ...` (string/number, optional): Additional values to add to the beginning of the list

### Returns

- `length` (number): The length of the list after the push operation
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local length, err = nauthilus_redis.redis_lpush("default", "my_list", "value1", "value2")
if err then
    print("Error:", err)
else
    print("List length after push:", length)
end
```

## nauthilus\_redis.redis\_rpush

_New in version 1.7.7_

Adds one or more values to the end of a Redis list and returns the length of the list after the push operation.

### Syntax

```lua
local length, error = nauthilus_redis.redis_rpush(handle, key, value1, value2, ...)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the list
- `value1` (string/number): The first value to add to the end of the list
- `value2, ...` (string/number, optional): Additional values to add to the end of the list

### Returns

- `length` (number): The length of the list after the push operation
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local length, err = nauthilus_redis.redis_rpush("default", "my_list", "value1", "value2")
if err then
    print("Error:", err)
else
    print("List length after push:", length)
end
```

## nauthilus\_redis.redis\_lpop

_New in version 1.7.7_

Removes and returns the first element of a Redis list.

### Syntax

```lua
local value, error = nauthilus_redis.redis_lpop(handle, key)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the list

### Returns

- `value` (string): The value of the first element of the list
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local value, err = nauthilus_redis.redis_lpop("default", "my_list")
if err then
    print("Error:", err)
else
    print("Popped value:", value)
end
```

## nauthilus\_redis.redis\_rpop

_New in version 1.7.7_

Removes and returns the last element of a Redis list.

### Syntax

```lua
local value, error = nauthilus_redis.redis_rpop(handle, key)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the list

### Returns

- `value` (string): The value of the last element of the list
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local value, err = nauthilus_redis.redis_rpop("default", "my_list")
if err then
    print("Error:", err)
else
    print("Popped value:", value)
end
```

## nauthilus\_redis.redis\_lrange

_New in version 1.7.7_

Returns a range of elements from a Redis list.

### Syntax

```lua
local elements, error = nauthilus_redis.redis_lrange(handle, key, start, stop)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the list
- `start` (number): The starting index of the range (0-based)
- `stop` (number): The ending index of the range (inclusive, can be negative to count from the end)

### Returns

- `elements` (table): A Lua table containing the elements in the specified range
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local elements, err = nauthilus_redis.redis_lrange("default", "my_list", 0, -1)
if err then
    print("Error:", err)
else
    for i, value in ipairs(elements) do
        print(i, value)
    end
end
```

## nauthilus\_redis.redis\_llen

_New in version 1.7.7_

Returns the length of a Redis list.

### Syntax

```lua
local length, error = nauthilus_redis.redis_llen(handle, key)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key` (string): The Redis key of the list

### Returns

- `length` (number): The length of the list
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local length, err = nauthilus_redis.redis_llen("default", "my_list")
if err then
    print("Error:", err)
else
    print("List length:", length)
end
```

## nauthilus\_redis.redis\_mget

_New in version 1.7.7_

Retrieves the values of multiple keys from Redis.

### Syntax

```lua
local values, error = nauthilus_redis.redis_mget(handle, key1, key2, ...)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key1, key2, ...` (string): One or more Redis keys to retrieve values for

### Returns

- `values` (table): A Lua table where keys are the Redis keys and values are the corresponding values
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local values, err = nauthilus_redis.redis_mget("default", "key1", "key2", "key3")
if err then
    print("Error:", err)
else
    for key, value in pairs(values) do
        print(key, value)
    end
end
```

## nauthilus\_redis.redis\_mset

_New in version 1.7.7_

Sets multiple key-value pairs in Redis.

### Syntax

```lua
local result, error = nauthilus_redis.redis_mset(handle, key1, value1, key2, value2, ...)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `key1, value1, key2, value2, ...` (string/number): Key-value pairs to set in Redis

### Returns

- `result` (string): "OK" if the operation was successful
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, err = nauthilus_redis.redis_mset("default", "key1", "value1", "key2", "value2")
if err then
    print("Error:", err)
else
    print("Result:", result)
end
```

## nauthilus\_redis.redis\_keys

_New in version 1.7.7_

Returns all keys matching a pattern.

### Syntax

```lua
local keys, error = nauthilus_redis.redis_keys(handle, pattern)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `pattern` (string): The pattern to match keys against (e.g., "user:*")

### Returns

- `keys` (table): A Lua table containing all keys matching the pattern
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local keys, err = nauthilus_redis.redis_keys("default", "user:*")
if err then
    print("Error:", err)
else
    for i, key in ipairs(keys) do
        print(i, key)
    end
end
```

::::warning
The KEYS command should be used with caution in production environments as it may impact performance when executed against large databases.
::::

## nauthilus\_redis.redis\_scan

_New in version 1.7.7_

Incrementally iterates over keys in Redis.

### Syntax

```lua
local result, error = nauthilus_redis.redis_scan(handle, cursor, match, count)
```

### Parameters

- `handle` (userdata/string): Redis connection handle or "default" for the default connection
- `cursor` (number): The cursor to start the scan from (use 0 for the first call)
- `match` (string, optional): The pattern to match keys against (default: "*")
- `count` (number, optional): The number of keys to return per call (default: 10)

### Returns

- `result` (table): A Lua table with two fields:
  - `cursor` (number): The cursor to use for the next scan (0 when the scan is complete)
  - `keys` (table): A Lua table containing the keys found in this scan
- `error` (string): An error message if the operation fails

### Example

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local cursor = 0
repeat
    local result, err = nauthilus_redis.redis_scan("default", cursor, "user:*", 10)
    if err then
        print("Error:", err)
        break
    end

    cursor = result.cursor

    for i, key in ipairs(result.keys) do
        print(i, key)
    end
until cursor == 0
```

::::tip
The SCAN command is the recommended way to iterate over keys in a production environment as it has minimal impact on performance.
::::
