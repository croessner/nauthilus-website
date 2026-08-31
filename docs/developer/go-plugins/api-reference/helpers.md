---
title: helpers Package
description: Complete deterministic account tag, IP scoping, and routability helper reference
keywords: [pluginapi helpers, AccountTag, ScopedIP, IsRoutableIP]
sidebar_position: 11
---

# `helpers` Package

```go
import "github.com/croessner/nauthilus/v4/pluginapi/v1/helpers"
```

This package contains deterministic, non-secret standalone functions. Unlike `Host.Helpers()`, callers supply explicit options.

## `AccountTagOptions`

```go
type AccountTagOptions struct {
    HashTagPrefix string
    UseHashTags   bool
}
```

`UseHashTags` enables Redis Cluster brace tags. `HashTagPrefix` is placed before the account digest; empty uses `acm-` when tags are enabled. The struct zero value disables tags because `UseHashTags` is false.

## `DefaultAccountTagOptions`

```go
func DefaultAccountTagOptions() AccountTagOptions
```

Returns:

```go
AccountTagOptions{
    HashTagPrefix: "acm-",
    UseHashTags:   true,
}
```

These are Lua-compatible defaults.

## `AccountTag`

```go
func AccountTag(username string, options AccountTagOptions) string
```

Returns an empty string when `username` is empty or `UseHashTags` is false. Otherwise it returns:

```text
{<prefix><lowercase MD5 hex of username bytes>}
```

With defaults, `alice` produces a tag shaped like `{acm-<32 hex characters>}`. The MD5 digest is used only for stable Redis slot distribution, not password hashing, authentication, anonymity, or collision resistance. Username bytes are not normalized; case and Unicode representation change the result.

## `IPScopingOptions`

```go
type IPScopingOptions struct {
    IPv4CIDR int
    IPv6CIDR int
}
```

`IPv4CIDR` must be 1-32 to group IPv4; `IPv6CIDR` must be 1-128 to group IPv6. Zero, negative, and out-of-range values disable grouping for that family.

## `ScopedIP`

```go
func ScopedIP(ip string, options IPScopingOptions) string
```

Returns the original input when it is empty, cannot be parsed by `net.ParseIP`, or the applicable CIDR is disabled/invalid. Otherwise it returns the canonical network string from `net.ParseCIDR`, such as `192.0.2.0/24`. It accepts only an address input, not an address already carrying a prefix. This helper does not decide whether the address is publicly routable.

## `IsRoutableIP`

```go
func IsRoutableIP(ip string) bool
```

Returns false for parse failures and addresses classified by `netip` as unspecified, loopback, multicast, link-local unicast, or private. It also excludes these explicit networks:

```text
0.0.0.0/8
100.64.0.0/10
192.0.0.0/24
192.0.2.0/24
192.88.99.0/24
198.51.100.0/24
203.0.113.0/24
240.0.0.0/4
fc00::/7
```

All other parsed addresses return true. This is a stable application helper, not a complete/live IANA special-purpose registry implementation; in particular, do not treat true as proof that routing will work or that an address is safe to contact. Apply deployment allow/deny rules separately.
