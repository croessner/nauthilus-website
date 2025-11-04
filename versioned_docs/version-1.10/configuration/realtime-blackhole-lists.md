---
title: Realtime Blackhole Lists
description: Configuration for realtime blackhole lists (RBL) in Nauthilus
keywords: [Configuration, RBL, Blackhole]
sidebar_position: 4
---

# Realtime Blackhole Lists

This is the *rbl* feature. It checks a remote client IP address against a list of defined RBL lists. The lists are run
simultaneously. They may contain a weight parameter which is added to a total value. If that value raises a threshold,
the features directly returns with a client reject.

## Configuration Options

### realtime_blackhole_lists::lists:
_Default: empty list_

This section defines one or more RBL lists. A RBL list requires the following fields:

| Field name     | Description                                                                                             |
|----------------|---------------------------------------------------------------------------------------------------------|
| name           | Example RBL name                                                                                        |
| rbl            | Domain part that is appended to the reversed IP address                                                 |
| ipv4           | Boolean that enables the list for IPv4 support                                                          |
| ipv6           | Boolean that enables the list for IPv6 support                                                          |
| return_code    | Expected DNS return code, if an IP address was listed                                                   |
| allow_failure  | Return a temporary failure, if a DNS lookup to the given list failed (not NXDOMAIN errors!)             |
| weight         | This value defines the weight for the given RBL list. See the **threshold** description for the meaning |

The **weight** value may be negative.

:::tip
The suggested **weight** value should be between -255 and 255. A negative weight turns the list into a whitelist
:::

### realtime_blackhole_lists::threshold
_Default: 0_

The threshold parameter defines an absolute value which tells Nauthilus, when to abort further list lookups. If the sum
of all weights is above the threshold value, the feature triggers an immediate client reject.

### realtime_blackhole_lists::ip_whitelist
_Default: empty list_

You can define IPv4 and IPv6 addresses with a CIDR mask to whitelist clients from this feature. If a client was found
on this list, the feature is not enabled while processing the authentication request.

```yaml
realtime_blackhole_lists:
  ip_whitelist:
    - 127.0.0.0/8
    - ::1
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
    - fd00::/8
    - 169.254.0.0/16
    - fe80::/10
```

## Example Configuration

```yaml
realtime_blackhole_lists:
  threshold: 10

  lists:
    - name: SpamRats AuthBL
      rbl: auth.spamrats.com
      ipv4: true
      ipv6: true
      return_code: 127.0.0.43
      weight: 10

    - name: AbusiX AuthBL
      rbl: YOUR-API-KEY.authbl.mail.abusix.zone
      ipv4: true
      ipv6: true
      return_code: 127.0.0.4
      weight: 10

  ip_whitelist:
    - 127.0.0.0/8
    - ::1
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
    - fd00::/8
    - 169.254.0.0/16
    - fe80::/10
```