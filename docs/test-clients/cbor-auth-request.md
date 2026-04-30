---
title: CBOR Auth Request Client
description: Python helper for exercising the CBOR authentication endpoint
keywords: [CBOR, Authentication, Test Client, contrib]
sidebar_position: 4
---

# CBOR Auth Request Client

`contrib/auth-cbor-request.py` sends complete `application/cbor` requests to `/api/v1/auth/cbor`. It is useful for smoke tests, proxy integration tests, and checking CBOR response handling without writing a custom client first.

The script uses Python's standard library for HTTP. If the optional `cbor2` package is installed, it uses that encoder with canonical output. Without `cbor2`, the script falls back to a small built-in encoder and decoder that supports the value types needed by Nauthilus authentication requests and responses.

## Basic Usage

Run it from the Nauthilus repository root:

```bash
python3 contrib/auth-cbor-request.py \
  --url http://127.0.0.1:8080/api/v1/auth/cbor \
  --username alice@example.test \
  --password secret \
  --client-ip 198.51.100.10 \
  --protocol imap \
  --method plain
```

The script prints the HTTP status, response headers, and a decoded response body. Use `--quiet` to print only the decoded body.

## Request Fields

The command-line options map directly to the CBOR request map sent to Nauthilus:

| Option | CBOR key | Default |
| --- | --- | --- |
| `--username` | `username` | `demo@example.test` |
| `--password` | `password` | `secret` |
| `--client-ip` | `client_ip` | `192.0.2.10` |
| `--client-port` | `client_port` | `54321` |
| `--client-hostname` | `client_hostname` | `client.example.test` |
| `--client-id` | `client_id` | `cbor-test-client` |
| `--external-session-id` | `external_session_id` | `cbor-test-session` |
| `--user-agent` | `user_agent` | `nauthilus-cbor-test/1.0` |
| `--local-ip` | `local_ip` | `127.0.0.1` |
| `--local-port` | `local_port` | `143` |
| `--protocol` | `protocol` | `imap` |
| `--method` | `method` | `plain` |
| `--ssl` | `ssl` | `off` |
| `--ssl-session-id` | `ssl_session_id` | empty |
| `--ssl-client-verify` | `ssl_client_verify` | `NONE` |
| `--ssl-client-dn` | `ssl_client_dn` | empty |
| `--ssl-client-cn` | `ssl_client_cn` | empty |
| `--ssl-issuer` | `ssl_issuer` | empty |
| `--ssl-client-notbefore` | `ssl_client_notbefore` | empty |
| `--ssl-client-notafter` | `ssl_client_notafter` | empty |
| `--ssl-subject-dn` | `ssl_subject_dn` | empty |
| `--ssl-issuer-dn` | `ssl_issuer_dn` | empty |
| `--ssl-client-subject-dn` | `ssl_client_subject_dn` | empty |
| `--ssl-client-issuer-dn` | `ssl_client_issuer_dn` | empty |
| `--ssl-protocol` | `ssl_protocol` | empty |
| `--ssl-cipher` | `ssl_cipher` | empty |
| `--ssl-serial` | `ssl_serial` | empty |
| `--ssl-fingerprint` | `ssl_fingerprint` | empty |
| `--oidc-cid` | `oidc_cid` | empty |
| `--auth-login-attempt` | `auth_login_attempt` | `1` |

Use `--dump-payload-json` to inspect the generated request map before it is encoded as CBOR.

## Modes

The default mode is a normal authentication request:

```bash
python3 contrib/auth-cbor-request.py --mode auth
```

For `mode=no-auth` and `mode=list-accounts`, the script appends the query parameter to the endpoint URL:

```bash
python3 contrib/auth-cbor-request.py \
  --mode list-accounts \
  --http-method GET \
  --username alice@example.test
```

`GET` skips the request body and is intended for the no-auth and list-accounts modes. `POST` sends the CBOR request map.

## API Authentication

Protected `/api/v1/*` deployments can be called with either bearer or Basic credentials:

```bash
python3 contrib/auth-cbor-request.py \
  --bearer-token "$ACCESS_TOKEN" \
  --username alice@example.test \
  --password secret
```

```bash
python3 contrib/auth-cbor-request.py \
  --api-basic-user api-user \
  --api-basic-password api-password \
  --username alice@example.test \
  --password secret
```

Additional headers can be added with repeated `--header 'Name: value'` options.

## TLS and Troubleshooting

Use `--insecure` only for local tests with self-signed certificates. `--timeout` controls the HTTP timeout in seconds.

For response decoding, the script understands `application/cbor`, `application/json`, and text responses. The request `Accept` header prefers CBOR first, then JSON, then text.
