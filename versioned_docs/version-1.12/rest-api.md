2. Different OIDC Client IDs using the `filter_by_oidc_cid` option

When a rule is configured with specific protocols or OIDC Client IDs, it will only be triggered by authentication attempts using those protocols or Client IDs.

When flushing brute force rules, you can specify the protocol to flush only rules associated with that protocol. This is useful when you have different rules for different protocols and want to flush only specific ones.

The Redis keys for protocol-specific rules include the protocol name as part of the key, separated by a colon. For example: `nauthilus:bf:3600:24:5:4:192.168.1.0/24:imap`.

For OIDC Client ID-specific rules, the Redis keys include both the `:oidc:` marker and the Client ID. For example: `nauthilus:bf:3600:24:5:4:192.168.1.0/24:oidc:my-client-id`.

---

#### `POST /api/v1/bruteforce/list`

Get a list of all known IP addresses and accounts that have been blocked.

**Description:** Returns a list of all IP addresses and accounts currently blocked by the brute force protection system. Optionally accepts filters to narrow down the results. Note that this endpoint does not display protocol information for protocol-specific brute force rules.

**Authentication:** 
- When JWT authentication is enabled, this endpoint requires a user with either the "security" or "admin" role (available from version 1.7.11)
- When Basic Authentication is enabled, the configured username and password must be provided

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

### Configurtion endpoints
_Available from version 1.7.11_

#### `GET /api/v1/config/load`

Retrieve the current configuration in JSON format.

**Description** Returns the current configuration in JSON format to the caller.

**Response:**
- Depends on the current configuration

**Status Codes:**
- `200 OK`: Hook executed successfully
- `400 Bad Request`: Invalid request
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Hook not found
- `500 Internal Server Error`: Server error

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


---

#### `DELETE /api/v1/bruteforce/flush/async` (since 1.11.4)

Enqueue an asynchronous brute-force key flush for an IP address and return immediately.

**Description:** Same request body as the synchronous variant; execution happens in the background. Returns `202 Accepted` with a `jobId` to track the operation.

**Authentication:** Same as the synchronous endpoint.

**Request:**
```json
{
  "ip_address": "x.x.x.x",
  "rule_name": "*",
  "protocol": "imap",
  "oidc_cid": "my-oidc-client-id"
}
```

**Response (202 Accepted):**
```json
{
  "guid": "2NMzAHKLwpSk6d20cJ4Zqj6hEAB",
  "object": "bruteforce",
  "operation": "flush_async",
  "result": {
    "jobId": "1733669295001-9c1a4b...",
    "status": "QUEUED"
  }
}
```

---

### Async Jobs

#### `GET /api/v1/async/jobs/{jobId}` (since 1.11.4)

Fetch the status of a previously enqueued async job.

**Description:** Returns the current status and metadata for the async job created via one of the `/async` endpoints.

**Response (200 OK):**
```json
{
  "guid": "2HDSEmkavbN4Ih3K89gBBPAGwPy",
  "object": "async",
  "operation": "status",
  "result": {
    "jobId": "1733669295000-2d5f1e...",
    "status": "INPROGRESS | DONE | ERROR | QUEUED",
    "type": "CACHE_FLUSH | BF_FLUSH",
    "createdAt": "2025-12-08T15:20:30.123Z",
    "startedAt": "2025-12-08T15:20:31.456Z",
    "finishedAt": "2025-12-08T15:20:33.000Z",
    "resultCount": 42,
    "error": ""
  }
}
```

**Status Codes:**
- `200 OK`: Job found; status returned
- `404 Not Found`: Unknown jobId or expired job record

Notes:
- Jobs expire automatically after a retention period.
- The `resultCount` indicates how many keys were removed.