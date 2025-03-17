---
title: Builtin
description: Logging and status messages
keywords: [Lua]
sidebar_position: 2
---

<!-- TOC -->
* [Builtin Lua functions](#builtin-lua-functions)
  * [nauthilus\_builtin.status\_message\_set](#nauthilus_builtinstatus_message_set)
  * [nauthilu\_builtin.custom\_log\_add](#nauthilu_builtincustom_log_add)
<!-- TOC -->

# Builtin Lua functions

## nauthilus\_builtin.status\_message\_set

If a client request should be rejected, you can overwrite the returned status message with the following function:

```lua
nauthilus_builtin.status_message_set("Reject message here")
```

## nauthilu\_builtin.custom\_log\_add

This function adds key-value pairs to the result log. In case of **features*, **backend** and **filters**, the logs are all added to the final result log line.
In cases of **actions**, logging is appended to the **action** log line. The reason is simple: Actions may run asynchronous to the main request, which
might already have been closed.

You cann call this function as many times as you like. Even with same key-value pairs.

:::note
Logs can not be removed if once set!
:::

```lua
nauthilus_builtin.custom_log_add("key", value)
```

A **value** can be a string, number or boolean. Anything else is replaced as "UNSUPPORTED".
