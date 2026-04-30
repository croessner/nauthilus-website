---
title: gRPC Auth API
description: Typed gRPC authentication API for Nauthilus
keywords: [API, gRPC, Protobuf, Authentication, AuthService]
sidebar_position: 11
---

# gRPC Auth API

Nauthilus exposes a typed gRPC authentication API for clients that prefer protobuf contracts over the REST JSON and CBOR endpoints.

The gRPC service runs on its own listener under `runtime.servers.grpc.auth`. It reuses the same authentication pipeline as `/api/v1/auth/json` and `/api/v1/auth/cbor`: backend selection, feature evaluation, brute-force handling, Lua filters, post-actions, metrics, logging, cache behavior, and list-account semantics stay identical.

Custom Lua hooks remain HTTP-only. The gRPC API models the authentication surface, not arbitrary HTTP hook payloads.

## Listener Configuration

```yaml
runtime:
  servers:
    grpc:
      auth:
        enabled: true
        address: "127.0.0.1:9444"
        tls:
          enabled: false
          cert: ""
          key: ""
          client_ca: ""
          min_tls_version: "TLS1.2"
          require_client_cert: false
```

The default address is loopback-only. Use a private sidecar network or TLS/mTLS before exposing the listener beyond the local host. Plaintext gRPC is only accepted on loopback addresses.

`min_tls_version` accepts `TLS1.2` and `TLS1.3`; unset values default to `TLS1.2`. The gRPC listener always advertises HTTP/2 through ALPN and does not expose configurable cipher suites.

Timeouts are shared with HTTP authentication:

```yaml
runtime:
  timeouts:
    redis_read: 1s
    redis_write: 2s
    ldap_search: 3s
    ldap_bind: 3s
    ldap_modify: 5s
    lua_backend: 5s
    lua_script: 30s
```

## Caller Authentication

The gRPC listener uses the same backchannel configuration as `/api/v1/*`:

```yaml
auth:
  backchannel:
    basic_auth:
      enabled: true
      username: "backchannel"
      password: "change-me"
    oidc_bearer:
      enabled: true
```

Clients send credentials through gRPC metadata:

```text
authorization: Basic <base64(username:password)>
authorization: Bearer <access-token>
```

Caller-auth failures are transport errors such as `Unauthenticated` or `PermissionDenied`. User authentication failures are domain decisions in a successful RPC response.

## Service Contract

```proto
syntax = "proto3";

package nauthilus.auth.v1;

service AuthService {
  rpc Authenticate(AuthRequest) returns (AuthResponse);
  rpc ListAccounts(ListAccountsRequest) returns (ListAccountsResponse);
}
```

### Authenticate

`Authenticate` mirrors the JSON and CBOR request model.

```proto
message AuthRequest {
  string username = 1;
  string password = 2;
  string client_ip = 3;
  string client_port = 4;
  string client_hostname = 5;
  string client_id = 6;
  string external_session_id = 7;
  string user_agent = 8;
  string local_ip = 9;
  string local_port = 10;
  string protocol = 11;
  string method = 12;
  string ssl = 13;
  string ssl_session_id = 14;
  string ssl_client_verify = 15;
  string ssl_client_dn = 16;
  string ssl_client_cn = 17;
  string ssl_issuer = 18;
  string ssl_client_notbefore = 19;
  string ssl_client_notafter = 20;
  string ssl_subject_dn = 21;
  string ssl_issuer_dn = 22;
  string ssl_client_subject_dn = 23;
  string ssl_client_issuer_dn = 24;
  string ssl_protocol = 25;
  string ssl_cipher = 26;
  string ssl_serial = 27;
  string ssl_fingerprint = 28;
  string oidc_cid = 29;
  uint32 auth_login_attempt = 30;
}
```

`username` and `password` are required for normal password authentication. Optional metadata fields use the same meaning as the REST request fields.

```proto
enum AuthDecision {
  AUTH_DECISION_UNSPECIFIED = 0;
  AUTH_DECISION_OK = 1;
  AUTH_DECISION_FAIL = 2;
  AUTH_DECISION_TEMPFAIL = 3;
}

message AttributeValues {
  repeated string values = 1;
}

message AuthResponse {
  bool ok = 1;
  AuthDecision decision = 2;
  string session = 3;
  string account_field = 4;
  string totp_secret_field = 5;
  uint32 backend = 6;
  map<string, AttributeValues> attributes = 7;
  string status_message = 8;
  string error = 9;
}
```

Authentication failures return `decision=AUTH_DECISION_FAIL` with `ok=false`. Temporary backend or policy failures return `decision=AUTH_DECISION_TEMPFAIL`. Unexpected server errors are reported as gRPC transport errors.

### ListAccounts

`ListAccounts` is the gRPC equivalent of `mode=list-accounts`. It does not emulate HTTP query parameters.

```proto
message ListAccountsRequest {
  string username = 1;
  string client_ip = 2;
  string client_port = 3;
  string client_hostname = 4;
  string client_id = 5;
  string external_session_id = 6;
  string user_agent = 7;
  string local_ip = 8;
  string local_port = 9;
  string protocol = 10;
  string method = 11;
  string oidc_cid = 12;
}

message ListAccountsResponse {
  repeated string accounts = 1;
  string session = 2;
}
```

When OIDC bearer authentication is used, list-account access follows the same scope rules as the REST backchannel endpoint.

## grpcurl Examples

Plaintext loopback listener with Basic backchannel authentication:

```bash
grpcurl \
  -plaintext \
  -H "authorization: Basic $(printf 'backchannel:change-me' | base64)" \
  -d '{
    "username": "alice@example.test",
    "password": "secret",
    "clientIp": "198.51.100.10",
    "protocol": "imap",
    "method": "plain",
    "authLoginAttempt": 1
  }' \
  127.0.0.1:9444 \
  nauthilus.auth.v1.AuthService/Authenticate
```

List accounts with bearer metadata:

```bash
grpcurl \
  -plaintext \
  -H "authorization: Bearer ${ACCESS_TOKEN}" \
  -d '{
    "username": "alice@example.test",
    "clientIp": "198.51.100.10",
    "protocol": "account-provider"
  }' \
  127.0.0.1:9444 \
  nauthilus.auth.v1.AuthService/ListAccounts
```
