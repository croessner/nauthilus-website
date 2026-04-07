---
title: Relay Domains
description: Configuration for relay domains in Nauthilus
keywords: [Configuration, Relay, Domains]
sidebar_position: 6
---

# Relay Domains

If the username equals to an email address, Nauthilus can split the login into the local and domain part. The latter is
compared against a (currently) static list. If the domain is unknown, the client will be rejected.

## Configuration Options

### relay_domains::static
_Default: empty list_

This key holds a list of domain names.

```yaml
relay_domains:
  static:
    - example.com
    - foobar.org
```

## Example Configuration

```yaml
relay_domains:
  static:
    - domain1.tld
    - domain2.tld
    - domain3.tld
```