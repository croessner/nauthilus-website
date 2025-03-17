---
title: Redis
description: Common Redis related functions
keywords: [Lua]
sidebar_position: 12
---

<!-- TOC -->
* [Redis](#redis)
* [Redis custom pools](#redis-custom-pools)
  * [How to register a new pool?](#how-to-register-a-new-pool)
* [Functions](#functions)
  * [nauthilus\_redis.redis\_set](#nauthilus_redisredis_set)
  * [nauthilus\_redis.redis\_incr](#nauthilus_redisredis_incr)
  * [nauthilus\_redis.redis\_get](#nauthilus_redisredis_get)
  * [nauthilus\_redis.redis\_expire](#nauthilus_redisredis_expire)
  * [nauthilus\_redis.redis\_del](#nauthilus_redisredis_del)
  * [nauthilus\_redis.redis\_rename](#nauthilus_redisredis_rename)
  * [nauthilus\_redis.redis\_hget](#nauthilus_redisredis_hget)
  * [nauthilus\_redis.redis\_hset](#nauthilus_redisredis_hset)
  * [nauthilus\_redis.redis\_hdel](#nauthilus_redisredis_hdel)
  * [nauthilus\_redis.redis\_hlen](#nauthilus_redisredis_hlen)
  * [nauthilus\_redis.redis\_hgetall](#nauthilus_redisredis_hgetall)
  * [nauthilus\_redis.redis\_hincrby](#nauthilus_redisredis_hincrby)
  * [nauthilus\_redis.redis\_hincrbyfloat](#nauthilus_redisredis_hincrbyfloat)
  * [nauthilus\_redis.redis\_hexists](#nauthilus_redisredis_hexists)
  * [nauthilus\_redis.redis\_sadd](#nauthilus_redisredis_sadd)
  * [nauthilus\_redis.redis\_sismember](#nauthilus_redisredis_sismember)
  * [nauthilus\_redis.redis\_smembers](#nauthilus_redisredis_smembers)
  * [nauthilus\_redis.redis\_srem](#nauthilus_redisredis_srem)
  * [nauthilus\_redis.redis\_scard](#nauthilus_redisredis_scard)
  * [nauthilus\_redis.redis\_upload\script](#nauthilus_redisredis_uploadscript)
  * [nauthilus\_redis.redis\_run\redis](#nauthilus_redisredis_runredis)
<!-- TOC -->

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

Example of a sentinel custom pool:

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

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_set(handle, "key", "value", 3600)
```

The expiration value is optional.

If anything went fine, "OK" is returned as **result**. In cases of errors, the **result** equals nil and a string is returned as **error**.

## nauthilus\_redis.redis\_incr

You can increment a value in Redis with the following function:

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local number, error = nauthilus_redis.redis_incr(handle, "key")
```

If anything went fine, the current **number** is returned. In cases of an **error**, number equals nil and a string is returned.

## nauthilus\_redis.redis\_get

To retrieve a value from Redis use the following function:

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_get(handle, "key")
```

If anything went fine, the returned value is stored in **result**. In cases of errors, the **result** equals nil and a string is returned to **error*.

## nauthilus\_redis.redis\_expire

A Redis key can have an expiration time in seconds. Use the following function to achieve this goal:

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_expire(handle, "key")
```

If anything went fine, "OK" is returned as **result**. In cases of errors, the **result** equals nil and a string is returned as **error**.

## nauthilus\_redis.redis\_del

To delete a Redis key, use the following function:

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local result, error = nauthilus_redis.redis_del(handle, "key")
```
If anything went fine, "OK" is returned as **result**. In cases of errors, the **result** equals nil and a string is returned as **error**.

## nauthilus\_redis.redis\_rename

Rename a Redis key

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local oldkey = "abc"
local newkey = "def"

local result, err = nauthilus_redis.redis_rename(handle, oldkey, newkey)
```

## nauthilus\_redis.redis\_hget

Get a value from a Redis hash map

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local already_sent_mail, err_redis_hget2 = nauthilus_redis.redis_hget(handle, redis_key, "send_mail")
```

## nauthilus\_redis.redis\_hset

Set a value in a Redis hash map

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local _, err_redis_hset = nauthilus_redis.redis_hset(handle, redis_key, "send_mail", 1)
```

## nauthilus\_redis.redis\_hdel

Delete a key from a Redis hash map

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

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local length, err_redis_hlen = nauthilus_redis.redis_hlen(handle, redis_key)
```

## nauthilus\_redis.redis\_hgetall

Get all values from a Redis hash map

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local redis_key = "some_key"
local all_sessions, err_redis_hgetall = nauthilus_redis.redis_hgetall(handle, redis_key)
```

## nauthilus\_redis.redis\_hincrby

Increament the value (integer) of a Redis hash map key

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

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local field = "some_field"
local increment = 1.3

local result, err = nauthilus_redis.redis_hincrbyfloat(handle, key, field, increment)
```

## nauthilus\_redis.redis\_hexists

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local field = "some_field"

local result, err = nauthilus_redis.redis_hexists(handle, key, field)
```

## nauthilus\_redis.redis\_sadd

Add a value to a Redis set

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local value = "some_value"

local result, err = nauthilus_redis.redis_sadd(handle, key, value)
```

## nauthilus\_redis.redis\_sismember

Check, if a value is a mamber of a Redis set

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local value = "some_value"

local result, err = nauthilus_redis.redis_sismember(handle, key, value)
```
## nauthilus\_redis.redis\_smembers

Get all members from a Redis set

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"

local result, err = nauthilus_redis.redis_smembers(handle, key)
```

## nauthilus\_redis.redis\_srem

Remove a value from a Redis set

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"
local value = "some_value"

local result, err = nauthilus_redis.redis_srem(handle, key, value)
```

## nauthilus\_redis.redis\_scard

Return the number of values inside a Redis set

```lua
dynamic_loader("nauthilus_redis")
local nauthilus_redis = require("nauthilus_redis")

local key = "some_key"

local result, err = nauthilus_redis.redis_scard(handle, key)
```

## nauthilus\_redis.redis\_upload\script

Upload a Redis script onto a Redis server. If successful an sha1 hash is returned, nil on failure with an error returned as second result.

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

## nauthilus\_redis.redis\_run\redis

With this command, you can either upload a script and run it once, or you can run an already uploaded script by
giving the upload-script-name (defined by an upload call earlier. See above).

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
