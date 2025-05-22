---
title: REST API
description: Nauthilus REST API Documentation
keywords: [REST, API, Documentation, Endpoints]
sidebar_position: 7
---

# Nauthilus REST API Documentation

This document provides a comprehensive reference for the Nauthilus REST API, following industry standards for API documentation.

## API Overview

Nauthilus provides a REST API that allows you to interact with the authentication and authorization system. The API is divided into two main channels:

1. **Backend Channel** - Used for server-to-server communication and administrative operations
2. **Frontend Channel** - Used for user-facing operations like login, consent, and two-factor authentication

## Security Considerations

**Important!** Backend channel endpoints should be properly secured and not exposed to the public internet without appropriate authentication mechanisms.

## Authentication Methods

The API supports multiple authentication methods:

- HTTP Basic Authentication
- JWT Authentication

## API Endpoints

### Authentication Endpoints

#### General Authentication

##### `POST /api/v1/auth/json`

Authenticate a user using JSON format.

**Description:** A general-purpose endpoint for authentication using JSON payload.

**Request:**
```json
{
  "username": "exampleUser",
  "password": "examplePass",
  "client_ip": "192.168.1.1",
  "client_port": "8080",
  "client_hostname": "client.example.com",
  "client_id": "client123",
  "local_ip": "10.0.0.1",
  "local_port": "443",
  "service": "loginService",
  "method": "LOGIN",
  "auth_login_attempt": 1,
  "ssl": "on",
  "ssl_session_id": "abc123",
  "ssl_client_verify": "SUCCESS",
  "ssl_client_dn": "CN=Client,C=US",
  "ssl_client_cn": "ClientCN",
  "ssl_issuer": "IssuerOrg",
  "ssl_client_notbefore": "2023-01-01T00:00:00Z",
  "ssl_client_notafter": "2023-12-31T23:59:59Z",
  "ssl_subject_dn": "CN=Client,C=US",
  "ssl_issuer_dn": "CN=Issuer,C=US",
  "ssl_client_subject_dn": "CN=Client,C=US",
  "ssl_client_issuer_dn": "CN=Issuer,C=US",
  "ssl_protocol": "TLSv1.2",
  "ssl_cipher": "ECDHE-RSA-AES256-GCM-SHA384",
  "ssl_serial": "0123456789ABCDEF",
  "ssl_fingerprint": "AA:BB:CC:DD:EE:FF",
  "oidc_cid": "my-oidc-client-id"
}
```

**Required Fields:**
- `username`: The identifier of the client/user sending the request
- `service`: The specific service that the client/user is trying to access

**Optional Fields:**
- `password`: The authentication credential
- `client_ip`: The IP address of the client/user
- `client_port`: The port number from which the client/user is sending the request
- `client_hostname`: The hostname of the client
- `client_id`: The unique identifier of the client/user
- `local_ip`: The IP address of the server receiving the request
- `local_port`: The port number of the server receiving the request
- `method`: The authentication method (e.g., PLAIN, LOGIN)
- `auth_login_attempt`: A flag indicating if the request is an authentication attempt
- `ssl`: Identifier if TLS is used (any non-empty value activates TLS)
- Various SSL/TLS related fields for certificate information
- `oidc_cid`: OIDC Client ID used for authentication (available from version 1.7.5)

**Query Parameters:**
- `mode` (optional): Special operation mode
  - `no-auth`: Perform lookup without authentication
  - `list-accounts`: List all accounts
- `in-memory` (optional): Set to "0" to disable in-memory cache
- `cache` (optional): Set to "0" to disable Redis cache

**Response:**
```json
{
  "passdb_backend": "ldapPassDB",
  "account_field": "entryUUID",
  "totp_secret_field": "",
  "webauth_userid_field": "uid",
  "display_name_field": "displayName",
  "attributes": {
    "cn": ["Test User"],
    "displayName": ["Test User"],
    "entryUUID": ["550e8400-e29b-41d4-a716-446655440000"],
    "givenName": ["Test"],
    "mail": ["testaccount@example.test"],
    "sn": ["User"],
    "uid": ["testaccount"]
  }
}
```

**Response Headers:**
```
Auth-Status: OK
X-Nauthilus-Session: 2MNJnKgGpgGJ5rRuFGcTltWefrO
Auth-User: testaccount@example.test
X-Nauthilus-Memory-Cache: Miss
```

The response includes both the JSON body and additional headers. The headers provide important information about the authentication status and session, while the JSON body contains detailed user information.

**Status Codes:**
- `200 OK`: Authentication successful
- `401 Unauthorized`: Authentication failed
- `403 Forbidden`: Access denied
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

---

##### `POST /api/v1/auth/header`

Authenticate a user using HTTP headers.

**Description:** Designed to be used with any service that can deal with HTTP request and response headers.

**Request Headers:**
All fields that are available in the JSON request are also supported as HTTP headers. The header endpoint accepts the same fields as the JSON endpoint, just in header format instead of JSON format.

**Required Headers:**
- `Auth-User`: Username
- `Auth-Protocol`: Protocol being used (e.g., "imap", "smtp", "pop3")

**Optional Headers:**
- `Auth-Pass`: Password
- `Auth-Password-Encoded`: Indicates if the password is base64 encoded (value "1" means encoded)
- `Auth-Method`: Authentication method (e.g., "plain")
- `Auth-Login-Attempt`: Login attempt counter
- `Client-IP`: Client IP address
- `X-Client-Port`: Client port
- `X-Client-Host`: Client hostname
- `X-Client-Id`: Client identifier
- `X-Local-IP`: Local IP address
- `X-Auth-Port`: Authentication port
- `Auth-SSL`: SSL status (any non-empty value activates TLS)
- `Auth-SSL-Session-ID`: SSL session identifier
- `Auth-SSL-Verify`: SSL verification status
- `Auth-SSL-Subject`: SSL subject
- `Auth-SSL-Client-CN`: SSL client common name
- `Auth-SSL-Issuer`: SSL issuer
- `Auth-SSL-Client-Not-Before`: SSL client certificate not valid before date
- `Auth-SSL-Client-Not-After`: SSL client certificate not valid after date
- `Auth-SSL-Subject-DN`: SSL subject distinguished name
- `Auth-SSL-Issuer-DN`: SSL issuer distinguished name
- `Auth-SSL-Client-Subject-DN`: SSL client subject distinguished name
- `Auth-SSL-Client-Issuer-DN`: SSL client issuer distinguished name
- `Auth-SSL-Cipher`: SSL cipher
- `Auth-SSL-Protocol`: SSL protocol
- `Auth-SSL-Serial`: SSL serial number
- `Auth-SSL-Fingerprint`: SSL fingerprint
- `X-OIDC-CID`: OIDC Client ID (available from version 1.7.5)

Note: The header names can be customized in the server configuration. The names shown above are the default values from the `default_http_request_header` configuration.

**Query Parameters:**
- `mode` (optional): Special operation mode
  - `no-auth`: Perform lookup without authentication
  - `list-accounts`: List all accounts
- `in-memory` (optional): Set to "0" to disable in-memory cache
- `cache` (optional): Set to "0" to disable Redis cache

**Response Headers:**
- `Auth-Status`: Authentication status ("OK" or "FAIL")
- `Auth-User`: Authenticated username
- `X-Nauthilus-Session`: Session identifier
- `X-Nauthilus-Memory-Cache`: Cache status ("Hit" or "Miss")
- `Auth-Wait`: Wait delay in seconds (only for failed authentication)
- Additional custom headers with user attributes prefixed with `X-Nauthilus-`

**Response Body:**
```
OK
```

**Status Codes:**
- `200 OK`: Authentication successful
- `401 Unauthorized`: Authentication failed
- `403 Forbidden`: Access denied
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

**Example:**
```
POST /api/v1/auth/header
Auth-Method: plain
Auth-User: testuser
Auth-Pass: testpassword
Auth-Protocol: imap
Auth-Login-Attempt: 0
Client-IP: 127.0.0.1
X-Client-Port: 12345
X-Client-Id: Test-Client
X-Local-IP: 127.0.80.80
X-Auth-Port: 143
Auth-SSL: success
Auth-SSL-Protocol: secured
```

---

##### `POST /api/v1/auth/nginx`

Authenticate a user for Nginx.

**Description:** Designed specifically for integration with Nginx authentication. This is a special form of the header endpoint with different response headers and return codes.

**Request Headers:**
The nginx endpoint accepts the same headers as the header endpoint. All fields that are available in the JSON request are also supported as HTTP headers.

**Required Headers:**
- `Auth-User`: Username
- `Auth-Protocol`: Protocol being used (e.g., "imap", "smtp", "pop3")

**Optional Headers:**
- `Auth-Pass`: Password
- `Auth-Password-Encoded`: Indicates if the password is base64 encoded (value "1" means encoded)
- `Auth-Method`: Authentication method (e.g., "plain")
- `Auth-Login-Attempt`: Login attempt counter
- `Client-IP`: Client IP address
- `X-Client-Port`: Client port
- `X-Client-Host`: Client hostname
- `X-Client-Id`: Client identifier
- `X-Local-IP`: Local IP address
- `X-Auth-Port`: Authentication port
- `Auth-SSL`: SSL status (any non-empty value activates TLS)
- `Auth-SSL-Session-ID`: SSL session identifier
- `Auth-SSL-Verify`: SSL verification status
- `Auth-SSL-Subject`: SSL subject
- `Auth-SSL-Client-CN`: SSL client common name
- `Auth-SSL-Issuer`: SSL issuer
- `Auth-SSL-Client-Not-Before`: SSL client certificate not valid before date
- `Auth-SSL-Client-Not-After`: SSL client certificate not valid after date
- `Auth-SSL-Subject-DN`: SSL subject distinguished name
- `Auth-SSL-Issuer-DN`: SSL issuer distinguished name
- `Auth-SSL-Client-Subject-DN`: SSL client subject distinguished name
- `Auth-SSL-Client-Issuer-DN`: SSL client issuer distinguished name
- `Auth-SSL-Cipher`: SSL cipher
- `Auth-SSL-Protocol`: SSL protocol
- `Auth-SSL-Serial`: SSL serial number
- `Auth-SSL-Fingerprint`: SSL fingerprint
- `X-OIDC-CID`: OIDC Client ID (available from version 1.7.5)

Note: The header names can be customized in the server configuration. The names shown above are the default values from the `default_http_request_header` configuration.

**Query Parameters:**
- `mode` (optional): Special operation mode
  - `no-auth`: Perform lookup without authentication
  - `list-accounts`: List all accounts
- `in-memory` (optional): Set to "0" to disable in-memory cache
- `cache` (optional): Set to "0" to disable Redis cache

**Response Headers:**
- `Auth-Status`: Authentication status ("OK" or "FAIL")
- `Auth-User`: Authenticated username
- `Auth-Port`: Port to connect to (for proxy authentication)
- `Auth-Server`: Server to connect to (for proxy authentication)
- `X-Nauthilus-Session`: Session identifier
- `Auth-Wait`: Wait delay in seconds (only for failed authentication)
- `Auth-Error-Code`: Error code (only for SMTP protocol and temporary failures)

**Protocol-Specific Backend Servers:**
The nginx endpoint returns protocol-specific backend servers based on the `Auth-Protocol` header:
- For IMAP: Returns the IMAP-specific backend server and port
- For POP3: Returns the POP3-specific backend server and port
- For SMTP: Returns the SMTP-specific backend server and port

This allows Nginx to proxy the connection to the appropriate backend server for the requested protocol.

**Response Body:**
```
OK
```

**Status Codes:**
- `200 OK`: Always returns 200 OK status code, regardless of authentication status. This is a specific behavior required by Nginx. The actual authentication status is indicated by the `Auth-Status` header.

---

##### `POST /api/v1/auth/saslauthd`

Authenticate a user for cyrus-saslauthd.

**Description:** Designed to be used with cyrus-saslauthd and its httpform backend.

**Request:**
Content-Type: application/x-www-form-urlencoded

```
protocol=submission&port=587&method=plain&tls=success&security=starttls&user_agent=saslauthd/2.1.27&username=testuser&realm=&password=testpassword
```

**Parameters:**
The saslauthd endpoint only supports the following fields:
- `method`: Authentication method (e.g., "plain")
- `realm`: Authentication realm (appended to username if provided)
- `user_agent`: User agent string
- `username`: Username
- `password`: Password
- `protocol`: The protocol being used (e.g., "submission")
- `port`: The port number
- `tls`: TLS status
- `security`: Security type

**Response Headers:**
- `Auth-Status`: Authentication status ("OK" or "FAIL")
- `Auth-User`: Authenticated username
- `X-Nauthilus-Session`: Session identifier

**Response Body:**
```
OK
```

**Status Codes:**
- `200 OK`: Authentication successful
- `401 Unauthorized`: Authentication failed
- `403 Forbidden`: Access denied
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

---

##### `POST /api/v1/auth/basic`

Authenticate a user using HTTP Basic Authentication.

**Description:** Standard HTTP Basic Authentication endpoint. Note that this endpoint lacks two-factor authentication capabilities.

**Authentication:**
- HTTP Basic Authentication

**Response:**
- Similar to other authentication endpoints

**Status Codes:**
- `200 OK`: Authentication successful
- `401 Unauthorized`: Authentication failed
- `403 Forbidden`: Access denied
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

---

### Cache Management Endpoints

#### `DELETE /api/v1/cache/flush`

Flush a user from the Redis cache.

**Description:** Removes a user's data from the cache, forcing a fresh authentication on the next request. This endpoint also flushes all brute force rules associated with the user's IP addresses, regardless of protocol.

**Request:**
```json
{
  "user": "testuser"
}
```

**Parameters:**
- `user`: Username to flush from cache. Note: Wildcards are not supported for this field.

**Response:**
```json
{
  "guid": "2HDSEmkavbN4Ih3K89gBBPAGwPy",
  "object": "cache",
  "operation": "flush",
  "result": {
    "user": "testuser",
    "removed_keys": ["nauthilus:ucp:__default__:testuser", "nauthilus:bf:3600:24:5:4:192.168.1.0/24:imap"],
    "status": "flushed"
  }
}
```

**Status Codes:**
- `200 OK`: Cache flush successful
- `400 Bad Request`: Invalid request
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Access denied
- `500 Internal Server Error`: Server error

---

### Brute Force Protection Endpoints

#### `DELETE /api/v1/bruteforce/flush`

Flush an IP address from a brute force bucket.

**Description:** Removes an IP address from the brute force protection system, allowing authentication attempts to resume.

**Request:**
```json
{
  "ip_address": "x.x.x.x",
  "rule_name": "testrule",
  "protocol": "imap",
  "oidc_cid": "my-oidc-client-id"
}
```

**Parameters:**
- `ip_address`: IP address to flush
- `rule_name`: Rule name to flush. Use "*" to flush all rules for the IP.
- `protocol` (optional): Protocol to flush. If specified, only rules with this protocol will be flushed.
- `oidc_cid` (optional): OIDC Client ID to flush. If specified, only rules with this OIDC Client ID will be flushed.

**Response:**
```json
{
  "guid": "2NMzAHKLwpSk6d20cJ4Zqj6hEAB",
  "object": "bruteforce",
  "operation": "flush",
  "result": {
    "ip_address": "x.x.x.x",
    "rule_name": "testrule",
    "protocol": "imap",
    "oidc_cid": "my-oidc-client-id",
    "removed_keys": ["nauthilus:bf:3600:24:5:4:192.168.1.0/24:imap"],
    "status": "flushed"
  }
}
```

**Status Codes:**
- `200 OK`: Brute force flush successful
- `400 Bad Request`: Invalid request
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Access denied
- `500 Internal Server Error`: Server error

**Protocol-Specific and OIDC Client ID-Specific Brute Force Rules:**

Nauthilus supports protocol-specific and OIDC Client ID-specific brute force rules (available from version 1.7.5), which allow you to define different brute force protection rules for:

1. Different protocols (e.g., IMAP, SMTP, POP3) using the `filter_by_protocol` option
2. Different OIDC Client IDs using the `filter_by_oidc_cid` option

When a rule is configured with specific protocols or OIDC Client IDs, it will only be triggered by authentication attempts using those protocols or Client IDs.

When flushing brute force rules, you can specify the protocol to flush only rules associated with that protocol. This is useful when you have different rules for different protocols and want to flush only specific ones.

The Redis keys for protocol-specific rules include the protocol name as part of the key, separated by a colon. For example: `nauthilus:bf:3600:24:5:4:192.168.1.0/24:imap`.

For OIDC Client ID-specific rules, the Redis keys include both the `:oidc:` marker and the Client ID. For example: `nauthilus:bf:3600:24:5:4:192.168.1.0/24:oidc:my-client-id`.

---

#### `POST /api/v1/bruteforce/list`

Get a list of all known IP addresses and accounts that have been blocked.

**Description:** Returns a list of all IP addresses and accounts currently blocked by the brute force protection system. Optionally accepts filters to narrow down the results. Note that this endpoint does not display protocol information for protocol-specific brute force rules.

**Request:**
```json
{
  "accounts": ["account1", "account2"],
  "ip_addresses": ["192.168.1.1", "10.0.0.1"]
}
```

**Parameters:**
- `accounts` (optional): List of account names to filter by
- `ip_addresses` (optional): List of IP addresses to filter by

If no filters are provided, all blocked IP addresses and accounts will be returned.

**Response:**
```json
{
  "guid": "2Nah6CvEP1ZK46u6M1GBl8ZuH01",
  "object": "bruteforce",
  "operation": "list",
  "result": [
    {
      "ip_addresses": {
        "2a05:bec0:abcd:1::4711": "ua_1d_ipv6"
      },
      "error": "none"
    },
    {
      "accounts": {
        "testuser": ["192.168.1.1", "10.0.0.1"]
      },
      "error": "none"
    }
  ]
}
```

**Status Codes:**
- `200 OK`: List retrieved successfully
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Access denied
- `500 Internal Server Error`: Server error

---

### JWT Authentication Endpoints

#### `POST /api/v1/jwt/token`

Generate a JWT token.

**Description:** Creates a new JWT token for authentication.

**Request:**
```json
{
  "username": "testuser",
  "password": "testpassword"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Status Codes:**
- `200 OK`: Token generated successfully
- `400 Bad Request`: Invalid request
- `401 Unauthorized`: Authentication failed
- `500 Internal Server Error`: Server error

---

#### `POST /api/v1/jwt/refresh`

Refresh a JWT token.

**Description:** Generates a new access token using a refresh token.

**Request:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**Status Codes:**
- `200 OK`: Token refreshed successfully
- `400 Bad Request`: Invalid request
- `401 Unauthorized`: Invalid refresh token
- `500 Internal Server Error`: Server error

---

### Custom Hook Endpoints

#### `ANY /api/v1/custom/{hook}`

Execute a custom Lua hook.

**Description:** Executes a custom Lua hook with the specified name and HTTP method.

**Path Parameters:**
- `hook`: The name of the hook to execute

**Request:**
- Depends on the specific hook implementation

**Response:**
- Depends on the specific hook implementation

**Status Codes:**
- `200 OK`: Hook executed successfully
- `400 Bad Request`: Invalid request
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Hook not found
- `500 Internal Server Error`: Server error

---

### Frontend Channel Endpoints

#### OAuth 2.0 / OpenID Connect Endpoints

##### `GET /login`
##### `POST /login/post`

Handle user login for OAuth 2.0 / OpenID Connect flows.

**Description:** Displays and processes the login form for OAuth 2.0 / OpenID Connect authentication flows.

---

##### `GET /consent`
##### `POST /consent/post`

Handle user consent for OAuth 2.0 / OpenID Connect flows.

**Description:** Displays and processes the consent form for OAuth 2.0 / OpenID Connect authentication flows.

---

##### `GET /logout`
##### `POST /logout/post`

Handle user logout for OAuth 2.0 / OpenID Connect flows.

**Description:** Displays and processes the logout confirmation for OAuth 2.0 / OpenID Connect authentication flows.

---

#### Two-Factor Authentication Endpoints

##### `GET /2fa/v1/register`

Register for two-factor authentication.

**Description:** Allows users to register for two-factor authentication.

---

##### `GET /2fa/v1/home`

Two-factor authentication home page.

**Description:** Displays the two-factor authentication home page with available options.

---

##### `GET /2fa/v1/{totp_page}`
##### `POST /2fa/v1/{totp_page}/post`

Handle TOTP registration.

**Description:** Displays and processes the TOTP registration form.

---

#### WebAuthn Endpoints

##### `GET /2fa/v1/{webauthn_page}/register/begin`

Begin WebAuthn registration.

**Description:** Initiates the WebAuthn registration process.

---

##### `POST /2fa/v1/{webauthn_page}/register/finish`

Complete WebAuthn registration.

**Description:** Completes the WebAuthn registration process.

---

#### Notification Endpoint

##### `GET /notify`

Display notifications to users.

**Description:** Displays error messages or other user information.

**Query Parameters:**
- `message`: The message to display

---

## Special Operation Modes

### Mode: no-auth

When using the `mode=no-auth` query parameter with authentication endpoints, the server will perform a lookup without authentication.

**Example:**
```
POST /api/v1/auth/header?mode=no-auth
Auth-Method: plain
Auth-User: testuser
Auth-Protocol: imap
...
```

### Mode: list-accounts

When using the `mode=list-accounts` query parameter with authentication endpoints, the server will return a list of all accounts.

**Example:**
```
GET /api/v1/auth/header?mode=list-accounts
Accept: application/json
```

## Response Headers

Authentication endpoints may return the following headers:

### Common Headers
- `Auth-Status`: Authentication status ("OK" or "FAIL")
- `Auth-User`: Authenticated username
- `X-Nauthilus-Session`: Session identifier (GUID for the request)
- `X-Nauthilus-Memory-Cache`: Cache status ("Hit" or "Miss")

### Proxy Authentication Headers (Nginx Service)
- `Auth-Port`: Port to connect to (for proxy authentication)
- `Auth-Server`: Server to connect to (for proxy authentication)

### User Attribute Headers (Header Service)
When using the Header service (`/api/v1/auth/header`), the server may return additional headers containing user attributes. These headers are prefixed with `X-Nauthilus-` and contain values from the user's attributes in the backend database.

For example:
- `X-Nauthilus-DisplayName`: User's display name
- `X-Nauthilus-Mail`: User's email address
- `X-Nauthilus-Uid`: User's unique identifier

The exact headers returned depend on the user's attributes in the backend database and the server configuration. These headers can be used by client applications to access additional user information without parsing the JSON response body.

### Custom Headers via Lua Scripts

Nauthilus allows you to add custom headers to HTTP responses using Lua scripts. This is particularly useful for adding application-specific information or integrating with other systems.

#### How to Add Custom Headers

Custom headers can be added by modifying the `Attributes` field of a `LuaBackendResult` object in your Lua script. Any key-value pairs added to this field will be included as headers in the HTTP response with the prefix `X-Nauthilus-`.

**Example Lua Script:**

```lua
-- Get the backend result object
local backend_result = require("nauthilus_backend_result")

-- Set custom attributes that will be converted to headers
backend_result.attributes({
  ["CustomHeader1"] = "Value1",
  ["CustomHeader2"] = "Value2",
  ["UserRole"] = "admin"
})
```

This script would add the following headers to the HTTP response:
- `X-Nauthilus-CustomHeader1: Value1`
- `X-Nauthilus-CustomHeader2: Value2`
- `X-Nauthilus-UserRole: admin`

#### Considerations

- All custom headers are prefixed with `X-Nauthilus-` to avoid conflicts with standard HTTP headers
- Header names are case-sensitive
- If a header with the same name already exists, it will not be overwritten
- Headers are only added for successful authentication responses
- For security reasons, certain header names may be restricted

## Error Handling

The API uses standard HTTP status codes to indicate the success or failure of a request:

- `200 OK`: The request was successful
- `400 Bad Request`: The request was malformed or invalid
- `401 Unauthorized`: Authentication is required or failed
- `403 Forbidden`: The client does not have permission to access the requested resource
- `404 Not Found`: The requested resource was not found
- `429 Too Many Requests`: The client has sent too many requests in a given amount of time
- `500 Internal Server Error`: An error occurred on the server

Error responses typically include a JSON body with more details about the error:

```json
{
  "error": "Error message",
  "guid": "2HDSEmkavbN4Ih3K89gBBPAGwPy"
}
```

## Rate Limiting

The API implements rate limiting to prevent abuse. If you exceed the rate limit, you will receive a `429 Too Many Requests` response.

## Security Recommendations

1. Always use HTTPS for all API requests
2. Secure backend channel endpoints from public access
3. Implement proper authentication for administrative endpoints
4. Regularly rotate authentication credentials
5. Monitor for suspicious activity
