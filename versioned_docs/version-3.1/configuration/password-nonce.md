---
title: Password Nonce
description: Configuration for storage.redis.password_nonce
keywords: [Configuration, Password, Nonce]
sidebar_position: 10
---

# Password Nonce

The current path is:

- `storage.redis.password_nonce`

This is a required random string used when hashing password material for Redis-side logic. It must be long, random, and must not contain spaces.

## Example

```yaml
storage:
  redis:
    password_nonce: "replace-with-a-long-random-string"
```

Related setting:

- `storage.redis.encryption_secret`

Do not keep either value in plaintext dumps unless you explicitly use `-P`.
