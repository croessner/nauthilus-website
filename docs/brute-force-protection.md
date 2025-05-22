---
title: Brute Force Protection
description: How to manage brute force protection in Nauthilus
keywords: [brute force, protection, security, API, cache, flush]
sidebar_position: 8
---

# Brute Force Protection in Nauthilus

This document explains how brute force protection works in Nauthilus and provides detailed instructions on how administrators can free users from brute force protection when necessary.

## How Brute Force Protection Works

Nauthilus implements brute force protection to prevent attackers from guessing user credentials through repeated login attempts. When a user fails to authenticate multiple times, Nauthilus will block further authentication attempts from the IP address that was used for these failed attempts.

The brute force protection system works as follows:

1. Nauthilus tracks failed authentication attempts by IP address.
2. When the number of failed attempts exceeds a configured threshold within a specified time period, the IP address is blocked.
3. Blocked IP addresses are stored in Redis with information about which brute force rule triggered the block.
4. User accounts that have been affected by brute force attempts are also tracked in Redis.

## Freeing Users from Brute Force Protection

There are two main ways to free users from brute force protection:

1. **By User Account**: Remove all brute force protection associated with a specific user account.
2. **By IP Address**: Remove brute force protection for a specific IP address, optionally filtered by rule name, protocol, or OIDC Client ID.

### Freeing a User by Account

To free a user by account, you can use the `/api/v1/cache/flush` endpoint. This will remove all brute force protection associated with the user, including all IP addresses that have been blocked due to failed login attempts for this user.

#### Example

```bash
curl -X POST -H "Content-Type: application/json" -d '{"user": "username@example.com"}' http://nauthilus-server/api/v1/cache/flush
```

This will:
1. Find the user account in the cache
2. Get all IP addresses associated with the user
3. Remove all brute force rules for those IP addresses
4. Remove the user's password history
5. Remove the user from the affected accounts list
6. Remove the user from the cache

#### Response

```json
{
  "guid": "unique-identifier",
  "object": "cache",
  "operation": "flush",
  "result": {
    "user": "username@example.com",
    "removed_keys": [
      "nauthilus:bf:3600:32:5:4:192.168.1.0/32",
      "nauthilus:pw_hist_ips:username@example.com",
      "nauthilus:affected_accounts",
      "nauthilus:ucp:__default__:username@example.com"
    ],
    "status": "4 keys flushed"
  }
}
```

### Freeing a User by IP Address

To free a user by IP address, you can use the `/api/v1/bruteforce/flush` endpoint. This will remove brute force protection for a specific IP address, optionally filtered by rule name, protocol, or OIDC Client ID.

#### Example 1: Flush all rules for an IP address

```bash
curl -X POST -H "Content-Type: application/json" -d '{"ip_address": "192.168.1.100", "rule_name": "*"}' http://nauthilus-server/api/v1/bruteforce/flush
```

This will remove all brute force rules for the specified IP address.

#### Example 2: Flush a specific rule for an IP address

```bash
curl -X POST -H "Content-Type: application/json" -d '{"ip_address": "192.168.1.100", "rule_name": "default"}' http://nauthilus-server/api/v1/bruteforce/flush
```

This will remove only the "default" brute force rule for the specified IP address.

#### Example 3: Flush a rule with specific protocol and OIDC Client ID

```bash
curl -X POST -H "Content-Type: application/json" -d '{"ip_address": "192.168.1.100", "rule_name": "default", "protocol": "http", "oidc_cid": "client123"}' http://nauthilus-server/api/v1/bruteforce/flush
```

This will remove the "default" brute force rule for the specified IP address, but only for the "http" protocol and "client123" OIDC Client ID.

#### Response

```json
{
  "guid": "unique-identifier",
  "object": "bruteforce",
  "operation": "flush",
  "result": {
    "ip_address": "192.168.1.100",
    "rule_name": "default",
    "protocol": "http",
    "oidc_cid": "client123",
    "removed_keys": [
      "nauthilus:bf:3600:32:5:4:192.168.1.0/32:http:oidc:client123",
      "nauthilus:bruteforce"
    ],
    "status": "2 keys flushed"
  }
}
```

## Recommended Approach

When freeing users from brute force protection, we recommend the following approach:

1. **First, identify the affected user and IP addresses**:
   - Use the `/api/v1/bruteforce/list` endpoint to list all blocked IP addresses and affected accounts.
   - Example: `curl -X GET http://nauthilus-server/api/v1/bruteforce/list`

2. **If you know the user account**:
   - Use the `/api/v1/cache/flush` endpoint to remove all brute force protection for that user.
   - This is the simplest approach if you know which user is affected.

3. **If you only know the IP address**:
   - Use the `/api/v1/bruteforce/flush` endpoint with `"rule_name": "*"` to remove all brute force rules for that IP address.
   - This is useful if you don't know which user is affected but know the IP address.

4. **For more targeted removal**:
   - If you know the specific rule, protocol, or OIDC Client ID, you can use the `/api/v1/bruteforce/flush` endpoint with those parameters.
   - This is useful for more granular control over which brute force rules are removed.

## The `/api/v1/cache/flush` Endpoint

The `/api/v1/cache/flush` endpoint is particularly useful for freeing users from brute force protection because it:

1. Removes all brute force rules for all IP addresses associated with the user
2. Removes the user's password history
3. Removes the user from the affected accounts list
4. Removes the user from the cache

This makes it a comprehensive solution for freeing a user from brute force protection, as it removes all traces of the user's failed login attempts.

### Request Format

```json
{
  "user": "username@example.com"
}
```

### Response Format

```json
{
  "guid": "unique-identifier",
  "object": "cache",
  "operation": "flush",
  "result": {
    "user": "username@example.com",
    "removed_keys": [
      "nauthilus:bf:3600:32:5:4:192.168.1.0/32",
      "nauthilus:pw_hist_ips:username@example.com",
      "nauthilus:affected_accounts",
      "nauthilus:ucp:__default__:username@example.com"
    ],
    "status": "4 keys flushed"
  }
}
```

## Conclusion

Nauthilus provides flexible and powerful tools for managing brute force protection. By understanding how these tools work, administrators can effectively free users from brute force protection when necessary, ensuring that legitimate users can regain access to their accounts while maintaining security against actual brute force attacks.