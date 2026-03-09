---
title: Backend Plugins
description: Lua API for implementing custom authentication backends
keywords: [Lua, Backend, Plugin, Authentication, MFA, WebAuthn]
sidebar_position: 15
---

# Backend Plugins

Nauthilus allows you to implement custom authentication backends using Lua. This is particularly useful for integrating with custom databases or legacy systems. With the introduction of the native Identity Provider, the Backend API has been extended to support Multi-Factor Authentication (MFA) and WebAuthn.

## Core Backend Functions

To implement a custom backend, you need to define specific functions in your Lua scripts. These functions are called by Nauthilus during various phases of authentication and user management.

### nauthilus_backend_verify_password

This is the primary function for user authentication.

#### Syntax
```lua
function nauthilus_backend_verify_password(request)
    -- ... implementation ...
    return result_code, result_object
end
```

#### Request Parameters (`request` table)
- `username` (string): The username provided by the user.
- `password` (string): The password provided by the user (empty if `no_auth` is true).
- `protocol` (string): The protocol being used (e.g., `imap`, `smtp`, `oidc`, `saml`).
- `no_auth` (boolean): If true, only user lookup and attribute retrieval should be performed, skipping password verification.
- `oidc_cid` (string): The OIDC Client ID (if applicable).
- `saml_entity_id` (string): The SAML Entity ID (if applicable).

#### Returns
- `result_code` (number): One of the `nauthilus_builtin.BACKEND_RESULT_*` constants.
- `result_object` (table): A `nauthilus_backend_result` object containing authentication status and user attributes.

---

### nauthilus_backend_list_accounts

Used to retrieve a list of all user accounts.

#### Syntax
```lua
function nauthilus_backend_list_accounts()
    -- ... implementation ...
    return result_code, accounts_table
end
```

#### Returns
- `result_code` (number): Success or error code.
- `accounts_table` (table): A simple list of strings containing usernames.

---

## MFA & WebAuthn Support

The following functions are used by the Identity Provider to manage secondary authentication factors.

### TOTP Management

#### nauthilus_backend_add_totp(request)
Stores a new TOTP shared secret for a user.
- `request.username`: The user's account name.
- `request.totp_secret`: The encrypted or plain TOTP secret.

#### nauthilus_backend_delete_totp(request)
Removes the TOTP shared secret for a user.
- `request.username`: The user's account name.

### Recovery Codes

#### nauthilus_backend_add_totp_recovery_codes(request)
Stores a list of recovery codes for a user.
- `request.username`: The user's account name.
- `request.totp_recovery_codes`: A table (list) of recovery code strings.

#### nauthilus_backend_delete_totp_recovery_codes(request)
Removes all recovery codes for a user.
- `request.username`: The user's account name.

### WebAuthn (FIDO2) Management

#### nauthilus_backend_get_webauthn_credentials(request)
Retrieves all registered WebAuthn credentials for a user.
- `request.username`: The user's account name.
- Returns: `result_code`, `credentials_table` (list of JSON strings).

#### nauthilus_backend_save_webauthn_credential(request)
Registers a new WebAuthn credential.
- `request.username`: The user's account name.
- `request.webauthn_credential`: The serialized JSON representation of the credential.

#### nauthilus_backend_delete_webauthn_credential(request)
Deletes a specific WebAuthn credential.
- `request.username`: The user's account name.
- `request.webauthn_credential`: The exact JSON string of the credential to delete.

#### nauthilus_backend_update_webauthn_credential(request)
Updates an existing WebAuthn credential (e.g., updating the sign count).
- `request.username`: The user's account name.
- `request.webauthn_old_credential`: The old JSON string.
- `request.webauthn_credential`: The new JSON string.

## Return Codes

The following constants are available via the `nauthilus_builtin` module:

| Constant | Description |
|----------|-------------|
| `BACKEND_RESULT_OK` | Operation completed successfully. |
| `BACKEND_RESULT_ERROR` | A generic error occurred. |
| `BACKEND_RESULT_NOT_FOUND` | The user or resource was not found. |
| `BACKEND_RESULT_DENIED` | Access was explicitly denied. |

## Example Backend Result

```lua
local b = nauthilus_backend_result.new()
b:authenticated(true)
b:user_found(true)
b:account_field("account")
b:attributes({
    mail = "user@example.com",
    display_name = "John Doe"
})
return nauthilus_builtin.BACKEND_RESULT_OK, b
```
