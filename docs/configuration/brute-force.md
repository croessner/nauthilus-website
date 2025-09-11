---
title: Brute Force Protection
description: Configuration for brute force protection in Nauthilus
keywords: [Configuration, Brute Force, Protection]
sidebar_position: 8
---

# Brute Force Protection

This feature allows you to define brute force buckets. A bucket is a container on Redis that will collect failed login
attempts from remote clients. Each time a client fails the authentication process, the buckets are updated. If a bucket
is full, a client is rejected directly without validating the credentials against password database backends.

A bucket has an expiration time stamp. As long as failed logins are stored, a bucket will be refreshed. A bucket will be
removed from Redis, if no requests trigger the bucket and the TTL is expired.

You can define as many buckets as you want. A bucket has a name, a period, an indicator, if the bucket handles IPv4 or
IPv6 IPs and a maximum allowed failed requests counter.

These buckets are independent of a user login name. They will count strictly each failed login request. Features like
the **realtime_blackhole_lists** feature (and others) will also update the buckets directly.

If the **brute_force** feature recognizes a misconfigured MUA, it will not block the client forever!

## Recommendation

If you define chains of buckets, user lower TTLs for buckets that hold IPs with a smaller IP range. Use higher TTLs for
networks. See the example below.

## Configuration Options

### brute_force::buckets
_Default: empty list_

This section lists chains of buckets. Here is the definition of a bucket:

| Field name         | Description                                                                                          |
|--------------------|------------------------------------------------------------------------------------------------------|
| name               | A user friendly name for the bucket                                                                  |
| period             | The TTL after which an unused bucket is removed from Redis                                           |
| cidr               | The network mask of an IP address                                                                    |
| ipv4               | Boolean that enables the bucket for IPv4 support                                                     |
| ipv6               | Boolean that enables the bucket for IPv6 support                                                     |
| failed_requests    | Threshold value unitl a client will be blocked directly without asking authentication backends       |
| filter_by_protocol | Optional list of protocols for which this bucket should be used (available from version 1.7.5)       |
| filter_by_oidc_cid | Optional list of OIDC Client IDs for which this bucket should be used (available from version 1.7.5) |

### brute_force::ip_whitelist
_Default: empty list_

You can define a list of IPs and networks that are whitelisted from the **brute_force** feature.

```yaml
brute_force:
  ip_whitelist:
    - 127.0.0.0/8
    - ::1
    - 192.168.0.0/16
```

### brute_force::learning

By default, Nauthilus does not learn from features such as `relay_domains` or RBLs, as this could lead to incorrect 
learning. However, in environments where false positives can be ruled out, Nauthilus can also count violations in the buckets.

The `learning` parameter can include the following strings to enable learning:

* `realtime_blackhole_lists`
* `cleartext_networks`
* `relay_domains`
* `brute_force`
* `lua`

```yaml
brute_force:
  learning:
    - realtime_blackhole_lists
    - lua
```

### brute_force::tolerate_percent
_Default: 0_

This setting defines the percentage of failed login attempts that should be tolerated before blocking a client. This is useful for clients that might occasionally fail due to misconfiguration or user error.

```yaml
brute_force:
  tolerate_percent: 20
```

### brute_force::tolerate_ttl
_Default: 24h_

This setting defines the time-to-live for toleration entries. After this period, the toleration will expire.

```yaml
brute_force:
  tolerate_ttl: 48h
```

### brute_force::custom_tolerations

This section allows you to define custom toleration settings for specific IP addresses or networks.

```yaml
brute_force:
  custom_tolerations:
    - ip_address: 192.168.1.0/24
      tolerate_percent: 30
      tolerate_ttl: 72h
    - ip_address: 10.0.0.5
      tolerate_percent: 50
      tolerate_ttl: 24h
```

### brute_force::ip_scoping (IPv6)
_Default: all disabled (0)_

Controls how IPv6 client addresses are normalized for certain subsystems so that addresses with privacy extensions are
aggregated by network instead of by /128. This improves stability for households where multiple devices rotate IPv6
interface identifiers frequently.

Available options (introduced in v1.9.4):
- `brute_force.ip_scoping.rwp_ipv6_cidr` — Apply the given IPv6 CIDR when evaluating and storing Repeating‑Wrong‑Password
  (PW_HIST) data. Set to `0` to disable (default). Valid range: `1..128`.
- `brute_force.ip_scoping.tolerations_ipv6_cidr` — Apply the given IPv6 CIDR when tracking Tolerations. Set to `0` to
  disable (default). Valid range: `1..128`.

Notes:
- When enabled, IPv6 addresses are normalized to their network (e.g., `2001:db8::1` with `/64` is stored as
  `2001:db8::/64`).
- Cache flush is ip_scoping‑aware starting with v1.9.4: `/api/v1/cache/flush` removes both raw and scoped keys.
- IPv4 behavior is unchanged.

Example:
```yaml
brute_force:
  ip_scoping:
    # Group IPv6 password‑history and tolerations by /64 instead of /128
    rwp_ipv6_cidr: 64
    tolerations_ipv6_cidr: 64
```

## Neural Network Configuration

:::danger Deprecated Feature
This functionality has been dropped in version 1.8.0 and is no longer available.
:::

### brute_force::neural_network

This section configures the neural network machine learning system for brute force detection.

The machine learning approach enhances the traditional rule-based brute force detection by:

1. Learning from historical login patterns
2. Considering multiple features beyond just failed attempt counts
3. Adapting to different user behaviors
4. Potentially detecting attacks earlier based on subtle patterns

The system uses a weighted decision approach that combines both the traditional rule-based checks and the ML predictions:

- Static rule result is converted to a score (0.0 for not triggered, 1.0 for triggered)
- ML prediction provides a probability between 0.0 and 1.0
- These scores are weighted and combined (configurable weights)
- If the weighted score exceeds a threshold, the attempt is blocked

#### brute_force::neural_network::max_training_records
_Default: 10000_

This setting defines the maximum number of training records to keep for the neural network.

```yaml
brute_force:
  neural_network:
    max_training_records: 20000
```

#### brute_force::neural_network::hidden_neurons
_Default: 10_

This setting defines the number of hidden neurons in the neural network.

```yaml
brute_force:
  neural_network:
    hidden_neurons: 12
```

#### brute_force::neural_network::activation_function
_Default: "sigmoid"_

This setting defines the activation function to use in the neural network. Valid values are "sigmoid", "tanh", "relu", and "leaky_relu".

```yaml
brute_force:
  neural_network:
    activation_function: "tanh"
```

#### brute_force::neural_network::static_weight
_Default: 0.4_

This setting defines the weight for static rules in the weighted decision.

```yaml
brute_force:
  neural_network:
    static_weight: 0.5
```

#### brute_force::neural_network::ml_weight
_Default: 0.6_

This setting defines the weight for machine learning in the weighted decision.

```yaml
brute_force:
  neural_network:
    ml_weight: 0.5
```

#### brute_force::neural_network::threshold
_Default: 0.7_

This setting defines the threshold for the weighted decision.

```yaml
brute_force:
  neural_network:
    threshold: 0.8
```

#### brute_force::neural_network::learning_rate
_Default: 0.01_

This setting defines the learning rate for the neural network.

```yaml
brute_force:
  neural_network:
    learning_rate: 0.005
```

#### brute_force::neural_network::dry_run
_Default: false_  
_New in version 1.7.11_

When enabled, the neural network will make predictions but won't block any authentication attempts based on those predictions. This is useful for testing and evaluating the neural network's performance before fully enabling it.

```yaml
brute_force:
  neural_network:
    dry_run: true
```

## Example Configuration

```yaml
brute_force:
  ip_whitelist:
    - 127.0.0.0/8
    - ::1
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
    - fd00::/8
    - 169.254.0.0/16
    - fe80::/10

  buckets:
    - name: b_1min_ipv4_32
      period: 60
      cidr: 32
      ipv4: true
      failed_requests: 10

    - name: b_1min_ipv6_128
      period: 60
      cidr: 128
      ipv6: true
      failed_requests: 10

    - name: b_1h_ipv4_24
      period: 3600
      cidr: 24
      ipv4: true
      failed_requests: 15

    - name: b_1h_ipv6_64
      period: 3600
      cidr: 64
      ipv6: true
      failed_requests: 15

    - name: b_1d_ipv4_24
      period: 86400
      cidr: 24
      ipv4: true
      failed_requests: 25

    - name: b_1d_ipv6_64
      period: 86400
      cidr: 64
      ipv6: true
      failed_requests: 25

    - name: b_1w_ipv4_24
      period: 604800
      cidr: 24
      ipv4: true
      failed_requests: 40

    - name: b_1w_ipv6_64
      period: 604800
      cidr: 64
      ipv6: true
      failed_requests: 40

    # Example of a protocol-specific bucket (available from version 1.7.5)
    - name: b_1h_imap_ipv4_24
      period: 3600
      cidr: 24
      ipv4: true
      failed_requests: 5
      filter_by_protocol:
        - imap
        - imaps

    # Example of an OIDC Client ID-specific bucket (available from version 1.7.5)
    - name: b_1h_oidc_client_ipv4_24
      period: 3600
      cidr: 24
      ipv4: true
      failed_requests: 3
      filter_by_oidc_cid:
        - my-oidc-client-id
        - another-client-id
```
