---
title: Authentication Pipeline
description: Authentication pipeline limits, caching, password history, and master-user login format
keywords: [Configuration, Authentication, Pipeline, Master User]
sidebar_position: 7
---

# Authentication Pipeline

`auth.pipeline` contains request concurrency, retry, cache, password-history, and master-user settings for the authentication pipeline.

```yaml
auth:
  pipeline:
    max_concurrent_requests: 100
    max_login_attempts: 15
    wait_delay: 0
    local_cache_ttl: 30s

    password_history:
      max_entries: 1000

    master_user:
      enabled: false
      user_format: "{user}*{master_user}"
```

## General Settings

| Key | Type | Default | Purpose |
|---|---:|---|---|
| `max_concurrent_requests` | integer | `100` | Maximum number of concurrent authentication requests handled by the pipeline. |
| `max_login_attempts` | integer | `15` | Maximum login attempts considered by the pipeline before the request is treated as exhausted. |
| `wait_delay` | duration/integer | `0` | Delay before selected authentication responses. |
| `local_cache_ttl` | duration | `30s` | Lifetime for local in-memory auth cache entries. |
| `password_history.max_entries` | integer | `1000` | Maximum password-history entries retained per tracked bucket. |

## Master User

`auth.pipeline.master_user.enabled` turns on master-user parsing for authentication requests.

`auth.pipeline.master_user.user_format` defines how the login name carries the requested target user and the authenticating master user. The format uses exactly one target-user placeholder and exactly one master-user placeholder.

Examples:

| Format | Login name | Parsed target user | Parsed master user |
|---|---|---|---|
| <code>&#123;user&#125;*&#123;master_user&#125;</code> | `alice@example.test*admin@example.test` | `alice@example.test` | `admin@example.test` |
| <code>&#123;user&#125;#&#123;master_user&#125;</code> | `alice@example.test#admin@example.test` | `alice@example.test` | `admin@example.test` |
| <code>&#123;master_user&#125;*&#123;user&#125;</code> | `admin@example.test*alice@example.test` | `alice@example.test` | `admin@example.test` |
| <code>login:&#123;user&#125;&#124;via:&#123;master_user&#125;</code> | `login:alice@example.test|via:admin@example.test` | `alice@example.test` | `admin@example.test` |

The literal text between the placeholders must make the split deterministic. Adjacent target-user and master-user placeholders are invalid because Nauthilus cannot know where one identity ends and the other begins.

The parsed master-user state is available to auth policies as `auth.master_user.active` for `authenticate` requests. See [Auth Policy Reference](auth-policy.md) for the corresponding policy attributes and examples.
