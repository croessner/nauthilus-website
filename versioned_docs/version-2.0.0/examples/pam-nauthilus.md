---
title: PAM (pam_nauthilus)
description: Complete guide for the contrib/pam_nauthilus PAM module
keywords: [PAM, SSH, Device Code, OIDC]
sidebar_position: 6
---

# PAM with `pam_nauthilus`

`pam_nauthilus` is a PAM module from `contrib/pam_nauthilus` that authenticates users via the Nauthilus IdP Device Authorization flow (RFC 8628).

It presents a verification URL and user code to the user and polls the OIDC token endpoint until the flow is approved, denied, or timed out.

## What It Is

- Implementation: pure C shared library (`pam_nauthilus.so`)
- Intended use: PAM stacks (for example `sshd`, `login`)
- IdP requirements: OIDC Device Authorization Grant enabled for the configured client

## Build Requirements

- C compiler (`gcc` or `clang`)
- PAM headers: `libpam-dev` (Debian/Ubuntu) or `pam-devel` (RHEL/Fedora)
- libcurl headers: `libcurl4-openssl-dev` or `libcurl-devel`
- OpenSSL headers: `libssl-dev` or `openssl-devel`
- cJSON headers: `libcjson-dev` or `cjson-devel`
- `pkg-config`

## Build and Install

Build:

```bash
make build
```

Install:

```bash
sudo make install LIBDIR=/lib/security
```

Notes:
- Some systems use `/usr/lib/security` or `/usr/lib64/security`.
- The module file name is `pam_nauthilus.so`.

## PAM Configuration Example

Example `/etc/pam.d/sshd` line:

```text
auth required pam_nauthilus.so \
    issuer=https://idp.example.com \
    client_id=ssh \
    client_secret=REDACTED \
    scope=openid \
    user_claim=preferred_username \
    timeout=5m \
    request_timeout=10s
```

If multiple scopes are needed in PAM config, encode spaces (for example `scope=openid%20profile`).

## Module Options (Complete)

| Option | Required | Default | Description |
|---|---|---|---|
| `issuer` | yes* | none | Base IdP URL, e.g. `https://idp.example.com` |
| `device_endpoint` | no | `${issuer}/oidc/device` | Device authorization endpoint override |
| `token_endpoint` | no | `${issuer}/oidc/token` | Token endpoint override |
| `userinfo_endpoint` | no | `${issuer}/oidc/userinfo` | UserInfo endpoint override |
| `jwks_endpoint` | no | `${issuer}/oidc/jwks` | JWKS endpoint override |
| `introspection_endpoint` | no | `${issuer}/oidc/introspect` | Introspection endpoint override |
| `client_id` | yes | none | OIDC client ID |
| `client_secret` | yes | none | OIDC client secret |
| `scope` | no | `openid` | Requested scope list |
| `user_claim` | no | `preferred_username` | Claim used to match PAM username |
| `timeout` | no | `5m` | Overall flow timeout |
| `request_timeout` | no | `10s` | Per-request HTTP timeout |
| `ca_file` | no | none | Additional PEM CA bundle |
| `tls_server_name` | no | none | TLS SNI override |
| `allow_http` | no | `false` | Allow `http://` endpoints (testing only) |

\* `issuer` is required unless all endpoint overrides are set explicitly.

## Required Nauthilus IdP Configuration

Minimal OIDC section for this PAM flow:

```yaml
idp:
  oidc:
    enabled: true
    issuer: "https://idp.example.com"
    signing_keys:
      - id: "main"
        key_file: "/etc/nauthilus/oidc.key"
        active: true
    device_code_expiry: 10m
    device_code_polling_interval: 5
    device_code_user_code_length: 8
    clients:
      - name: "SSH"
        client_id: "ssh"
        client_secret: "REDACTED"
        grant_types:
          - urn:ietf:params:oauth:grant-type:device_code
        token_endpoint_auth_method: "client_secret_basic"
        scopes:
          - openid
          - profile
          - email
```

## Security Behavior

- HTTPS is enforced by default.
- `allow_http=true` should only be used for local/trusted test environments.
- The module validates username binding using `userinfo` + configured `user_claim`.
- Token signature is validated using JWKS (RS256).
- Token activity is checked via introspection (`active` claim).

## Docker Demo from `contrib/pam_nauthilus`

The contrib directory contains:

- `Dockerfile.demo` (builds and installs the PAM module in container)
- `entrypoint.sh` (renders `/etc/pam.d/login` from env vars)
- `docker-compose.yml` (demo stack)

Build demo image:

```bash
docker build -f Dockerfile.demo -t pam_nauthilus-demo .
```

Run demo container:

```bash
docker run -d --name test_pam_nauthilus \
  -e PAM_ISSUER=http://host.docker.internal:8080 \
  -e PAM_CLIENT_ID=ssh \
  -e PAM_CLIENT_SECRET=REDACTED \
  -e PAM_SCOPE=openid \
  -e PAM_ALLOW_HTTP=true \
  pam_nauthilus-demo
```

Then test login through PAM:

```bash
docker exec -it test_pam_nauthilus -- /sbin/login
```

On Linux, add `--add-host=host.docker.internal:host-gateway` or use `--network=host` if needed.

### Demo Environment Variables (entrypoint mapping)

These env vars map directly to PAM options in `entrypoint.sh`:

- `PAM_ISSUER`
- `PAM_DEVICE_ENDPOINT`
- `PAM_TOKEN_ENDPOINT`
- `PAM_USERINFO_ENDPOINT`
- `PAM_JWKS_ENDPOINT`
- `PAM_INTROSPECTION_ENDPOINT`
- `PAM_CLIENT_ID`
- `PAM_CLIENT_SECRET`
- `PAM_SCOPE` (default `openid`)
- `PAM_USER_CLAIM` (default `preferred_username`)
- `PAM_TIMEOUT` (default `5m`)
- `PAM_REQUEST_TIMEOUT` (default `10s`)
- `PAM_CA_FILE`
- `PAM_TLS_SERVER_NAME`
- `PAM_ALLOW_HTTP`

## Troubleshooting

- TLS errors with self-signed certificates: provide `ca_file` or use `allow_http=true` only in local test setups.
- Username mismatch: ensure IdP returns the claim configured in `user_claim` and that it matches the PAM username.
- Device flow timeout: increase `timeout` and/or `idp.oidc.device_code_expiry` as needed.
