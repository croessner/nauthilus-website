---
sidebar_position: 2
description: Native OIDC, hosted resources, and restricted dynamic client registration configuration in config v2
keywords: [Identity Provider, OIDC, Authorization Code, Device Code, Client Credentials, Dynamic Client Registration, Hosted Resources, RFC 8414, RFC 9207]
---

# OIDC

Nauthilus provides a built-in OpenID Connect provider with:

- Authorization Code
- Device Authorization
- Client Credentials
- restricted RFC 7591 Dynamic Client Registration for public native mail clients
- RFC 8414 authorization server metadata and RFC 9207 issuer identification
- hosted resources that Nauthilus serves itself, such as the read-only MCP support endpoint

The current configuration root is:

- `identity.oidc`

## Endpoints

- `GET /.well-known/openid-configuration`
- `GET /.well-known/oauth-authorization-server`
- `GET /.well-known/oauth-authorization-server/<issuer path>` for an issuer with a path
- `POST /oidc/register` when restricted Dynamic Client Registration is enabled
- `GET /oidc/authorize`
- `POST /oidc/token`
- `POST /oidc/introspect`
- `GET /oidc/userinfo`
- `GET /oidc/jwks`
- `GET /oidc/logout`
- `POST /oidc/device`
- `GET /oidc/device/verify`

Optional legacy GET support for `/oidc/token` is controlled by:

- `identity.oidc.tokens.token_endpoint_allow_get`

## Authorization Server Metadata and Issuer Identification

The provider metadata is one document. Nauthilus serves it as OIDC discovery at `/.well-known/openid-configuration` and,
unchanged, as RFC 8414 authorization server metadata at `/.well-known/oauth-authorization-server`. OAuth clients that do
not speak OIDC discovery, such as MCP clients, find the issuer there.

For an issuer with a path, for example `https://idp.example.com/auth`, the RFC 8414 path-insertion location
`https://idp.example.com/.well-known/oauth-authorization-server/auth` answers as well. Only the path of the configured
issuer is served; any other path below `/.well-known/oauth-authorization-server/` answers `404`. Issuer paths with
several segments are served the same way. The root form is always served, which is also what a reverse proxy reaches
when it strips the issuer path from the appended form
`https://idp.example.com/auth/.well-known/oauth-authorization-server`.

Every authorization response that is redirected to the client, with a code or with an error, carries the RFC 9207 `iss`
parameter with the exact value of `identity.oidc.issuer`:

```text
http://127.0.0.1:53682/callback?code=...&iss=https%3A%2F%2Fidp.example.com&state=...
```

The metadata advertises this with `authorization_response_iss_parameter_supported: true`. A client that implements RFC
9207 compares `iss` with the issuer it discovered and rejects a mismatch, so a client that talks to several
authorization servers detects a mix-up before it redeems a code. Clients without RFC 9207 support ignore the parameter.
Requests that are refused with a plain `400` before any redirect, for example an unknown `client_id` or `redirect_uri`,
carry no `iss`.

:::note Upgrade notes

- Both metadata documents contain the new field `authorization_response_iss_parameter_supported`, and every callback
  URL carries the additional query parameter `iss`. Keep `identity.oidc.issuer` exactly as your clients know it; an
  RFC 9207 client rejects a response whose `iss` differs, for example by a trailing slash.
- If your reverse proxy forwards only `/.well-known/openid-configuration` to Nauthilus, also forward
  `/.well-known/oauth-authorization-server` (and its path-insertion form for an issuer with a path). A CORS policy with
  `path_prefixes: ["/.well-known/"]` already covers the new document.

:::

## Client Authentication Metadata

OIDC discovery publishes token and introspection client-auth metadata separately:

| Metadata | Values |
| --- | --- |
| `token_endpoint_auth_methods_supported` | Configured through `identity.oidc.token_endpoint_auth_methods_supported`; defaults to `client_secret_post`, `client_secret_basic`, `private_key_jwt`, and `none`. |
| `token_endpoint_auth_signing_alg_values_supported` | `RS256` and `EdDSA` when `private_key_jwt` is advertised for the token endpoint. |
| `introspection_endpoint_auth_methods_supported` | `client_secret_post`, `client_secret_basic`, and `private_key_jwt`. |
| `introspection_endpoint_auth_signing_alg_values_supported` | `RS256` and `EdDSA`. |

The introspection endpoint intentionally does not advertise or accept `none` client authentication.

For `private_key_jwt`, the JWT `aud` claim must be the exact endpoint URL. Use `issuer + "/oidc/token"` for token requests and `issuer + "/oidc/introspect"` for introspection requests. A token-endpoint assertion is not reusable for introspection.

## Token Introspection Authorization

`POST /oidc/introspect` authenticates the inspecting client with its configured `token_endpoint_auth_method`. After the
token itself has passed signature, expiry, revocation, and authoritative storage checks, Nauthilus decides whether the
authenticated client may see it:

- A static client may inspect access tokens whose validated audience contains its own `client_id`. Audience arrays are
  supported; a missing or malformed audience fails closed.
- Dynamic clients registered through `/oidc/register` can never inspect tokens.
- A static confidential client with `allow_backchannel_introspection: true` may additionally inspect service access
  tokens issued to other clients whose normalized audience set is exactly `nauthilus:backchannel`.
- A static confidential client with a `token_introspection` block may additionally inspect user access tokens issued to
  other clients, as described in
  [Resource Servers and Resource Indicators](#resource-servers-and-resource-indicators).

These are two independent authorities: `allow_backchannel_introspection` covers Nauthilus service tokens, and
`token_introspection` covers user access tokens that a protected resource, for example a mail server, receives from
other clients.

Any other token returns HTTP `200` with only `{"active": false}`, as required by RFC 7662. Failed client authentication
still returns `invalid_client`. When the token store or signing keys cannot be read, introspection answers HTTP `503`
instead of `active: false`, so a protected resource never treats a valid token as revoked because of an outage.

| Key under `identity.oidc.clients[]` | Type | Default | Meaning |
| --- | --- | --- | --- |
| `allow_backchannel_introspection` | boolean | `false` | Permit this static confidential client to inspect other clients' `nauthilus:backchannel` service access tokens. |
| `token_introspection.resources` | list of strings | `[]` | RFC 8707 resource indicators this client owns. Clients may request them with the `resource` parameter; the issued user access token then carries the resource in `aud` and only this client may introspect it. Each resource has exactly one owner. |
| `token_introspection.clients` | list of strings | `[]` | Static clients whose plain user access tokens (issued without a resource indicator) this client may introspect. The same list decides which static clients may request the resources above. |
| `token_introspection.dynamic_client_profiles` | list of strings | `[]` | Dynamic client registration profiles (currently `mail-client-v1`) treated like `clients` for dynamically registered clients. |

Configuration validation rejects the flag for public clients, dynamic clients, unsupported authentication methods,
secret authentication without a `client_secret`, and `private_key_jwt` without `client_public_key` or
`client_public_key_file`. The flag grants no token issuance, no API access, and no access to other clients' browser or
ID tokens. It is an operator setting, not a requested scope or token claim.

A dedicated introspection client for a sidecar that validates backchannel caller tokens needs neither the
`client_credentials` grant nor backchannel scopes:

```yaml
identity:
  oidc:
    clients:
      - name: "Sidecar introspection"
        client_id: "sidecar-introspection"
        client_secret: "${SIDECAR_INTROSPECTION_SECRET}"
        token_endpoint_auth_method: "client_secret_basic"
        allow_backchannel_introspection: true
        grant_types: ["authorization_code"]
        redirect_uris: []
        scopes: ["openid"]
```

Without a redirect URI this client cannot run a browser flow. The sidecar submits the caller's bearer in the `token`
form field. A delegated response contains `active`, `iss`, `aud`, `exp`, `scope`, the issuing caller's `client_id`, and
`token_type: "Bearer"`; the sidecar must still check issuer, audience, expiry, and per-method scopes.

Opaque `client_credentials` service tokens persist their expiry and expose it as `exp`. Redis TTL and revocation remain
authoritative for opaque-token validity.

### Resource Servers and Resource Indicators

A protected resource such as a mail server authenticates to `/oidc/introspect` as its own confidential static client and
introspects the user access tokens that other clients present to it. Both ways to allow this are configured in the
`token_introspection` block of the resource server's client entry:

- **Allowlist.** `clients` names static clients and `dynamic_client_profiles` names dynamic client registration
  profiles. Plain user access tokens of these issuers, obtained without a resource indicator, are visible to the
  resource server.
- **Resource indicators (RFC 8707).** `resources` lists the resource indicators the resource server owns. A resource
  has exactly one owner across all clients. The same allowlist decides which clients may request the resource.

```yaml
identity:
  oidc:
    clients:
      - name: "Mail server introspection"
        client_id: "mail-introspection"
        client_secret: "${MAIL_INTROSPECTION_SECRET}"
        token_endpoint_auth_method: "client_secret_basic"
        grant_types: ["authorization_code"]
        redirect_uris: []
        scopes: ["openid"]
        token_introspection:
          resources: ["https://mail.example.org/jmap"]
          clients: ["roundcube-app"]
          dynamic_client_profiles: ["mail-client-v1"]
```

A webmail client obtains a JMAP token with `/oidc/authorize?...&resource=https%3A%2F%2Fmail.example.org%2Fjmap`, and the
mail server introspects it as `mail-introspection`. Plain `roundcube-app` tokens and tokens of `mail-client-v1` dynamic
clients are visible to the mail server as well.

**Validation.** The block requires the same confidential static client authentication as
`allow_backchannel_introspection`. Configuration validation rejects the block for public, dynamic, or incompletely
authenticated clients, and it rejects:

- resources that are not absolute URIs, contain a fragment or whitespace, use the reserved `nauthilus:` scheme, equal a
  configured `client_id`, or are already owned by another client;
- `clients` entries that are unknown or name the client itself;
- `dynamic_client_profiles` entries other than the configured registration profile, and any entry while dynamic client
  registration is disabled;
- `resources` without at least one `clients` or `dynamic_client_profiles` entry.

**Token content.** Every user access token, JWT and opaque, carries the issuer-owned claim `azp` with the client ID it
was issued to; custom claim mappings cannot set `azp`. Service tokens keep `client_id` and receive no `azp`. Without
resources, `aud` stays the plain client ID string. With resources, `aud` becomes an array of the client ID followed by
the resources, for example `["roundcube-app", "https://mail.example.org/jmap"]`. ID tokens are unchanged.

**Authorization and device requests.** `GET /oidc/authorize` and `POST /oidc/device` accept the multi-valued `resource`
parameter. Every value must be an absolute URI without fragment, registered by a resource server, and requestable by the
client; duplicates are removed. Any other value fails with `invalid_target`: a redirect to the validated redirect URI for
dynamic clients, a plain `400` for static clients and at the device endpoint. The validated resources survive login,
MFA, and consent resumes and are bound to the authorization code or device request. A hosted resource is registered by
Nauthilus itself rather than by a resource server client; it must be the only `resource` value of a request and is never
accepted at the device endpoint. See [Hosted Resources](#hosted-resources).

**Token endpoint.**

| Grant | `resource` parameter |
| --- | --- |
| `authorization_code` | Optional subset of the granted resources; narrows only the issued access token. |
| `refresh_token` | Optional subset of the stored grant; narrows only the new access token, the stored grant never changes. |
| `urn:ietf:params:oauth:grant-type:device_code` | Optional subset of the resources of the device authorization request. |
| `client_credentials` | Not supported; any value returns `invalid_target`. |

A token request without `resource` receives the full granted resource set; it does not mean "no resources". A value
outside the grant returns `invalid_target`. Issuance re-checks every resource against the current configuration: after
an operator withdraws a client from the owner's allowlist, code and refresh exchanges of grants carrying that resource
fail with `invalid_target` until the client authorizes again. At the authorization-code exchange these checks run before
the code is consumed, so a rejected `resource` leaves the code redeemable once.

**Consent.** A remembered consent is keyed by identity, client, and scopes only and does not cover resources. The
owner's allowlist is the gate for resources, so requesting an additional resource does not show the consent page again
when the scopes are already covered.

**Introspection decision.** For a caller with a `token_introspection` block, a user access token is additionally active
when:

1. its audience names a resource the caller owns; the allowlist does not apply to such tokens, so a token for another
   resource server's resource stays inactive even when its issuer is allowlisted; or
2. it carries no resource and its issuing client, taken from `azp` (for older tokens without `azp`, the single-string
   audience), is listed in `clients`, or is a dynamic client whose registration profile is listed in
   `dynamic_client_profiles`. A dynamic issuer that cannot be resolved denies the request.

Service tokens stay inactive for callers that only have `token_introspection`. Everything else answers
`{"active": false}`. The response shape is unchanged apart from `azp` and an array `aud`. JWT access tokens of dynamic
clients are still revalidated against their client through `azp`, so an array audience never bypasses the dynamic-client
checks.

## Hosted Resources

`identity.oidc.hosted_resources` declares RFC 8707 protected resources that Nauthilus serves itself. For such a resource
Nauthilus is the authorization server and the resource server. No client owns it, so delegated introspection through a
`token_introspection` block never matches its tokens. The read-only MCP support endpoint is the hosted resource that
`runtime.servers.mcp.hosted_resource` names; see [Read-only Support Access over MCP](../../guides/support-mcp-access.md)
for the listener, the reverse proxy, and the client setup.

```yaml
identity:
  oidc:
    hosted_resources:
      - name: "support-mcp"
        resource: "https://login.example.com/mcp"
        scopes:
          - "nauthilus:history_read"
          - "nauthilus:history_detail"
          - "nauthilus:operations_read"
        user_right:
          from: "groups"
          any_of: ["nauthilus-support"]
        max_authentication_age: 12h
        max_access_token_lifetime: 15m
        static_clients: ["support-cli"]
```

| Key under `identity.oidc.hosted_resources[]` | Default | Meaning |
| --- | --- | --- |
| `name` | required | Reference name: 1 to 63 lower-case letters, digits, or dashes, starting with a letter or digit; unique. |
| `resource` | required | The resource indicator, which is also the token audience. Absolute HTTPS URL with a host and without query, user info, fragment, or whitespace; plain HTTP only for loopback hosts. |
| `scopes` | required | The scopes the resource gates: a non-empty subset of `nauthilus:history_read`, `nauthilus:history_detail`, and `nauthilus:operations_read`. |
| `user_right.from` | required | `groups` evaluates group names, `group_dns` group distinguished names. |
| `user_right.any_of` | required | Groups that entitle a user; at least one. |
| `max_authentication_age` | `12h` | How long after the interactive login a grant may still be issued or refreshed; `5m` to `720h`. |
| `max_access_token_lifetime` | `15m` | Ceiling for the lifetime of every access token that carries the resource; `1m` to `1h`. |
| `static_clients` | required | The only clients admitted to the resource. |

**Validation.** Configuration validation requires `identity.oidc.enabled` and rejects unknown keys, names or resources
that repeat, a resource that equals a configured `client_id`, a resource owned by a `token_introspection` block, and a
reserved `nauthilus:` audience. Every entry of `static_clients` must be a configured static client that

- is public or sets `require_pkce`;
- allows only `authorization_code`, optionally with `refresh_token`;
- requires MFA through `require_mfa` or `required_mfa_level`;
- lists at least one scope of the resource in its `scopes`.

**Issuer behaviour.**

| Step | Behaviour |
| --- | --- |
| Authorization request | Only a client in `static_clients` may name the resource. A dynamically registered client never may, whatever it declared. The resource must be the only `resource` value. Violations fail with `invalid_target`. |
| Login age | A browser session whose login is older than `max_authentication_age` must log in again, including MFA. With `prompt=none` the client receives `login_required`. |
| User right | The groups (`groups`) or group distinguished names (`group_dns`) from the fresh backend lookup that builds the token claims must contain one entry of `any_of`; otherwise the client receives `access_denied` and the flow is consumed. A token claim never decides it. |
| Code exchange and refresh | Refused with `invalid_grant` once the login is older than `max_authentication_age`. A client that is no longer in `static_clients` receives `invalid_target`. |
| Access token | Audience is the client ID plus the resource. The lifetime is the client's lifetime, capped at `max_access_token_lifetime`. |
| Device authorization | Never grants a hosted resource; requests and device-code exchanges that carry one fail with `invalid_target`. |

The authentication backend must resolve groups for the `oidc` protocol, for example through an LDAP `groups` search
(see [Groups Resolution](../database-backends/ldap.md#groups-resolution)). A user whose groups cannot be resolved has no
user right.

A removed group membership ends access at the next authorization, at the latest after `max_authentication_age`, when
refresh fails. Removing a client from `static_clients` ends access at once, because the resource server checks the
admission of the issuing client on every request.

## CORS for Discovery

OIDC discovery endpoints are often fetched directly by browser-based clients. Configure cross-origin behavior under `runtime.servers.http.cors`, not directly below `runtime.http`:

```yaml
runtime:
  servers:
    http:
      cors:
        enabled: true
        policies:
          - name: "oidc_discovery"
            enabled: true
            path_prefixes:
              - "/.well-known/"
            allow_origins:
              - "https://app.example.com"
            allow_methods:
              - "GET"
              - "OPTIONS"
            allow_headers:
              - "Authorization"
              - "Content-Type"
            expose_headers: []
            allow_credentials: false
            max_age: 600
```

Policies are evaluated in order. The first enabled policy whose `path_prefixes` entry matches the request path controls the response.

If Nauthilus is behind a reverse proxy or identity sidecar that filters response headers, forward at least `Vary` and the `Access-Control-*` response headers. Otherwise the browser can report a missing `Access-Control-Allow-Origin` header even though Nauthilus emitted it.

## Example

```yaml
identity:
  oidc:
    enabled: true
    issuer: "https://idp.example.com"
    signing_keys:
      - id: "main"
        key_file: "/etc/nauthilus/keys/oidc.pem"
        algorithm: "RS256"
        active: true
    custom_scopes:
      - name: "tenant"
        description: "Tenant information"
        claims:
          - name: "tenant_id"
            type: "string"
    scopes_supported:
      - "openid"
      - "profile"
      - "email"
      - "groups"
      - "offline_access"
    response_types_supported:
      - "code"
    subject_types_supported:
      - "public"
    id_token_signing_alg_values_supported:
      - "RS256"
    token_endpoint_auth_methods_supported:
      - "client_secret_basic"
      - "client_secret_post"
      - "private_key_jwt"
      - "none"
    code_challenge_methods_supported:
      - "S256"
    claims_supported:
      - "sub"
      - "name"
      - "email"
      - "preferred_username"
      - "groups"
    consent:
      ttl: 720h
      mode: "all_or_nothing"
    tokens:
      default_access_token_lifetime: 1h
      default_refresh_token_lifetime: 720h
      revoke_refresh_token: true
      token_endpoint_allow_get: false
    logout:
      front_channel_supported: true
      front_channel_session_supported: false
      back_channel_supported: true
      back_channel_session_supported: false
    device_flow:
      code_expiry: 10m
      polling_interval: 5
      user_code_length: 8
    clients:
      - name: "Example Web App"
        client_id: "example-web"
        client_secret: "change-me"
        redirect_uris:
          - "https://app.example.com/callback"
        scopes:
          - "openid"
          - "profile"
          - "email"
          - "offline_access"
        grant_types:
          - "authorization_code"
        token_endpoint_auth_method: "client_secret_basic"
        require_pkce: true
        required_scopes:
          - "openid"
        optional_scopes:
          - "profile"
          - "email"
        require_mfa:
          - "totp"
        supported_mfa:
          - "totp"
          - "webauthn"
        required_mfa_level: 2
```

## Restricted Native Dynamic Client Registration

Nauthilus can expose an anonymous `POST /oidc/register` endpoint for public native mail clients. This is a constrained
RFC 7591 profile named `mail-client-v1`, not a general-purpose registration service. It permits only Authorization Code
with PKCE `S256`, literal IPv4 or IPv6 loopback redirects, public client authentication, RS256 ID tokens, and access
tokens of at most 15 minutes. Access tokens are opaque by default; `access_token_type: jwt` issues JWT access tokens
for resource servers that validate tokens locally.

The profile can also serve native applications that register automatically and send neither `scope` nor
`grant_types`: `default_scopes` supplies their registered scopes, `implied_scopes` adds registered scopes to every
authorization, `id_token_claims`/`access_token_claims` apply claim mappings to all dynamic clients, and `skip_consent`
waives the consent page for all dynamic clients. `delayed_response` enables the delayed login-failure presentation for
all dynamic clients, and `require_mfa`, `supported_mfa`, and `required_mfa_level` set their MFA enrollment and assurance
policy. All of these are operator-owned profile settings that apply to already registered clients on their next use.

The feature is disabled by default. A minimal policy is:

```yaml
identity:
  oidc:
    enabled: true
    issuer: "https://idp.example.com"
    auto_key_rotation: true
    custom_scopes:
      - name: "mail:imap"
        description: "Access IMAP mail"
        claims:
          - name: "mail_access"
            type: "string"
      - name: "mail:smtp"
        description: "Submit mail through SMTP"
        claims:
          - name: "mail_submit"
            type: "string"
    dynamic_client_registration:
      enabled: true
      required_scopes: ["openid"]
      optional_scopes: ["offline_access", "mail:imap", "mail:smtp"]
      allow_refresh_tokens: true
      source_hmac_key: "${NAUTHILUS_DCR_SOURCE_HMAC_KEY}"
```

Every required or optional scope must also be present in `scopes_supported` or `custom_scopes`. The mail scope names and
their resource-server meaning are deployment-owned; Nauthilus does not assign IMAP or SMTP semantics automatically.

When enabled, discovery publishes `registration_endpoint`. Registration responses never contain a client secret,
registration access token, or registration management URI. RFC 7592 client management is outside this profile.

See [Operating OIDC Dynamic Client Registration](../../guides/oidc-dynamic-client-registration.md) for the complete
configuration reference, registration examples, lifecycle behavior, monitoring, revocation, and troubleshooting.

## PKCE

- only `S256` is supported
- public clients must use PKCE
- public means no `client_secret` or `token_endpoint_auth_method: none`
- confidential clients can require PKCE by setting `require_pkce: true`

## Client Types and Grant Boundaries

Nauthilus enforces the security properties of each client type at configuration and request time:

- `client_credentials` requires confidential client authentication. A public client configured for this grant is
  rejected during configuration validation.
- A `client_credentials` request must not request `openid`. Service tokens do not represent an end user and do not
  receive an ID token or UserInfo claims; such a request fails with `invalid_scope`.
- Confidential device-authorization clients must authenticate before Nauthilus allocates device-flow state.
- When a request selects `private_key_jwt`, a failed assertion does not fall back to a client secret.
- Public Authorization Code clients must use PKCE with `S256`.
- Confidential Authorization Code clients with `require_pkce: true` must also use PKCE with `S256`.

Client Credentials access tokens are bound to the Nauthilus backchannel resource. JWT tokens carry the issuer-owned
claims `token_type=access_token` and `aud=nauthilus:backchannel`; opaque tokens resolve to the same claims during server
validation. Backchannel authorization rejects ID tokens and access tokens for another audience.

Do not include `openid` in the scope list of a machine-to-machine client:

```yaml
identity:
  oidc:
    clients:
      - name: "Operations Client"
        client_id: "operations-client"
        client_secret: "change-me"
        grant_types:
          - "client_credentials"
        token_endpoint_auth_method: "client_secret_basic"
        scopes:
          - "nauthilus:authenticate"
          - "nauthilus:admin"
          - "nauthilus:security"
```

## Redirect URI Validation

The rules in this section apply to static `identity.oidc.clients[]`. Exact matching is the default, with controlled
exceptions for native clients and explicitly configured wildcard patterns:

- A trailing `*` is allowed only at the end of a configured URI and not after a query string.
- Wildcard matching preserves parsed scheme, host, port, and path-segment boundaries. A prefix for
  `https://app.example/callback/*` cannot match another host or `/callback-evil`.
- Query and fragment components of the requested URI are ignored only while evaluating a permitted trailing wildcard.
- A configured `*` matches HTTP and HTTPS redirect URIs and is strongly discouraged in production.
- HTTP loopback redirects for `127.0.0.1`, `localhost`, and `::1` may use a dynamic port.
- Wildcards are disabled for requested URIs with user-info or unsafe path traversal segments, including encoded forms.
- `post_logout_redirect_uri` is always checked exactly against `post_logout_redirect_uris`.

Prefer exact redirect URIs. Use a loopback exception only for native applications, and keep wildcard patterns within a
dedicated callback path.

Dynamic `mail-client-v1` registrations use a separate, narrower redirect policy. They reject `localhost`, HTTPS,
private-use schemes, wildcards, query strings, fragments, userinfo, encoded paths, and path traversal. Only
`http://127.0.0.1`, `http://127.0.0.1/<path>`, `http://[::1]`, and `http://[::1]/<path>` are accepted, with an optional
numeric port that may change during authorization.

### Loopback Redirects and CSP `form-action`

Native applications receive the authorization response on a loopback port chosen at runtime (RFC 8252 section 7.3). A
CSP `form-action` source without a port only matches the default port, so a browser would block the redirect that
follows the consent form. When the frontend security headers are enabled, Nauthilus therefore appends wildcard-port
sources to the rendered `form-action` directive:

- `http://127.0.0.1:*` when dynamic client registration is enabled;
- `http://<host>:*` for every static client with an `http` redirect URI on `127.0.0.1` or `localhost`.

An explicit `form-action 'none'` is left unchanged. CSP host sources cannot contain IPv6 literals, so a redirect to
`http://[::1]:<port>` after the consent form is still blocked by browsers. Native applications that show a consent page
must use `127.0.0.1`.

## Custom Scopes

A custom scope declares a scope of the deployment: its name and the text shown on the consent page (`description`, and
`description_<language>` for a translation). `claims` is optional since 4.1.0 and lists the custom claims the scope
releases. A scope
without claims only authorizes, for example at a resource server that checks the `scope` claim of the access token.

```yaml
identity:
  oidc:
    custom_scopes:
      # Declares the scope and its consent text; releases no claim.
      - name: "mail:diagnose"
        description: "Read mail store diagnostics (read-only)"

      # Additionally releases the tenant_id claim to clients that map it.
      - name: "tenant"
        description: "Tenant information"
        claims:
          - name: "tenant_id"
            type: "string"
```

Global custom scopes under `identity.oidc.custom_scopes` are the base. A client can add or replace definitions under
`identity.oidc.clients[].custom_scopes`; a client scope with the same name fully replaces the global one. Discovery
(`scopes_supported`) lists the global custom scopes only.

Declaring a scope does not allow any client to request it. A client may request the scopes listed in its own `scopes`;
the custom scope supplies the consent text and, when it lists claims, the claim release.

A mapped claim is only written to a token when a requested scope releases it: its standard scope (for example `groups`
for the `groups` claim) or a custom scope that lists the claim. A client that requests only resource scopes, as MCP
clients do, therefore gets `groups` in its access token only if one of those scopes lists `groups` under `claims`.

### Scope Consistency Warnings

When the OIDC issuer is enabled, Nauthilus checks the configuration for three inconsistencies at load (since 4.1.0). Each is logged
as a warning and never fails the load, because a scope may be defined by a component the configuration does not
describe:

| Warning | Meaning and remedy |
|---|---|
| `OIDC claim mapping is never released: no scope allowed for the client releases the claim` | A claim in `id_token_claims` or `access_token_claims` has no releasing scope among the scopes of that client, so the mapping is skipped for every request that names a scope. Add the claim to a custom scope the client may request, or allow its standard scope. |
| `OIDC custom scope is not allowed for any client` | No client lists the scope in `scopes`, and dynamic client registration does not offer it. Without `client_id` the warning names a global custom scope, otherwise a custom scope of that client. |
| `OIDC client scope is neither built in nor declared in custom_scopes or by a hook` | A scope in `scopes` or `implied_scopes` of the client is defined nowhere: it is not built in, not a custom scope, and not required by a Lua hook or a native plugin hook. This is usually a typing error. Declare the scope as a custom scope when another component defines it. |

The warnings carry the attributes `client_id`, `scope`, and `claim` as far as they apply.

## Token and Claim Boundaries

UserInfo requires an access token whose granted scopes contain `openid`. ID tokens are identity assertions, not API
credentials, and introspection reports them as inactive. Successful access-token introspection includes
`token_type: "Bearer"`.

Custom ID-token and access-token claim mappings cannot override issuer-owned protocol and security claims such as
`iss`, `sub`, `aud`, `azp`, `exp`, `iat`, `scope`, `client_id`, `nonce`, `auth_time`, or `token_type`. Keep application claims in
distinct names instead of relying on collisions with standard claims.

OIDC back-channel logout calls do not follow HTTP redirects. Configure `backchannel_logout_uri` as the final endpoint;
a `3xx` response is a failed delivery.

## Verification Key Cache

Token validation keeps the public half of a Redis-held signing key, looked up by key ID, in a process-local cache for at
most 10 seconds and never beyond the key's expiry. Private keys, unknown key IDs, and storage failures are never cached,
and key rotation or cleanup in the same process drops the cache immediately. If you delete a still-valid key from Redis
by hand, every process can keep verifying tokens signed with it for up to 10 seconds.

## Token State in Redis

Opaque access tokens, refresh tokens, authorization codes, device codes, user codes, dynamic client records, and user
revocation epochs are stored in Redis. Plan the IdP Redis with these properties:

- **Keyed references.** Bearer tokens, refresh tokens, device codes, user codes, and authorization codes appear in Redis
  keys only as HMAC-SHA256 digests keyed with `storage.redis.encryption_secret`, each with its own domain separator.
  The secret is mandatory: configuration validation rejects an empty value or one shorter than 16 characters.
- **Consent challenges.** A pending consent decision lives in its own key family and digest namespace
  (`oidc:consent:<digest>`), apart from authorization codes (`oidc:code:<digest>`), and is consumed with `GETDEL` when
  the user decides. The consent challenge is visible to the user agent, so it can never be redeemed at the token
  endpoint. The token endpoint also rejects every `code` value outside the issued shape (unreserved URI characters, at
  most 256 characters) with `invalid_grant` before it reads code storage.
- **Secret rotation.** Changing `storage.redis.encryption_secret` changes every keyed reference. Running device flows,
  unredeemed authorization codes, and all opaque access and refresh tokens become invalid. Revocation epochs and dynamic
  client records are not keyed and survive the rotation.
- **Revoked JWT access tokens** are stored under a domain-separated SHA-256 digest key
  (`oidc:denied_access_token:sha256:<hex>`) instead of the raw token. For one release, Nauthilus also writes and reads
  the legacy key that embeds the raw token, so a rollback to the previous release still sees revocations. A failed
  denylist read is a storage failure, not "not denied".
- **Redis Cluster.** Each atomic unit has its own hash tag: token state per subject (`oidc:subject:{<digest>}:...`), a
  single-key locator per token reference (`oidc:token:{<reference>}:subject`), one tag per dynamic client
  (`oidc:dcr:client:{<client_id>}`), and one tag per device request and user code. Only the dynamic-client quota index
  and the registration rate limits share the `{registry}` tag. No IdP script or transaction can fail with `CROSSSLOT`.
- **No eviction.** Revocation epochs have no TTL. Run the IdP Redis with `maxmemory-policy noeviction`; an evicted
  epoch key would fall back to the epoch floor and could make revoked tokens valid again.
- **Redis 6.2 or newer** (or a compatible Valkey) is required, because code redemption uses `GETDEL`, the registry
  repair uses `ZRANDMEMBER`, and device updates use `SET ... XX KEEPTTL`.
- **Online guessing of user codes.** Device user codes are short by design. Enable the per-client-IP HTTP rate limit
  (`runtime.servers.http.middlewares.rate` with `runtime.servers.http.rate_limit.per_second` and `burst`). It covers
  all IdP, frontend, and UI endpoints, including `/oidc/device/verify`. Probes and `/metrics` are exempt, and on the
  caller-authenticated backchannel API the limit only counts failed caller authentications (see
  [Backchannel Caller Rejections](../../rest-api.md#backchannel-caller-rejections)).

:::warning Upgrading from earlier v4 prereleases

The Redis layout of IdP token state changed without migration. The previous keys are not read. After the upgrade:

- all opaque access tokens and all static and dynamic refresh tokens are invalid, so users authenticate again;
- all JWT access tokens issued before the upgrade are rejected, for users and for `client_credentials` service tokens
  alike. Revocation epochs now start at the floor `1000000000000`, and tokens with a lower epoch or without the
  `nauthilus_user_epoch` claim are rejected;
- all dynamic client registrations are gone, so native clients register again;
- running device authorization flows and unredeemed authorization codes are lost.

Split edges keep their cached caller token in edge Redis (`caller_auth.oidc_bearer.token_cache`). That token was issued
by the authority before the upgrade and is rejected afterwards. Edges replace it on their own: the first
`UNAUTHENTICATED` answer discards the cached token and the RPC is retried once with a freshly issued one, so the edge
token cache needs no manual flush. See
[Rejected Caller Tokens](../identity-proxy.md#rejected-caller-tokens).

Most retired keys expire with their original TTLs. The former revocation epochs
(`<prefix>oidc:dcr:{dynamic}:dynamic_user_epoch:*`) and the former active-client index
(`<prefix>oidc:dcr:{registry}:active`) have no TTL. Remove them manually, for example on the Redis master that owns the
`{dynamic}` slot:

```bash
redis-cli -h <master> --scan --pattern '<prefix>oidc:dcr:{dynamic}:*' | xargs -r -n 100 redis-cli -h <master> unlink
redis-cli -c unlink '<prefix>oidc:dcr:{registry}:active'
```

Leave the other retired keys to their TTLs. Former device codes, user codes, and authorization codes share key prefixes
with the new digest keys, so a broader pattern scan could remove live state.

:::

:::warning Consent challenges in Nauthilus 4.0

Nauthilus 4.0.0 through 4.0.9 stored a pending consent decision as `consent:<challenge>` in the authorization-code key
space. A client that read the challenge from the consent URL or form could redeem it at the token endpoint with its own
credentials and PKCE verifier and receive tokens before the user decided. 4.1.0 separates the key families and refuses
such values. During a rolling update, a consent page that an older instance started cannot be decided on a newer one;
the user starts the authorization again, which costs at most the ten-minute authorization lifetime. No stored value has
to be migrated or removed.

:::

## MFA Assurance

Each browser client may configure `require_mfa`, `supported_mfa`, `required_mfa_level`, and local
`mfa_policy.levels`. Enrollment, offered challenges, and the strength of the current proof are evaluated separately.
See [MFA Assurance Policy](mfa-assurance.md) for the complete model.

## Browser SSO and Explicit Account Selection

Without Remember me, the browser envelope is a session cookie without `Max-Age`. The server still keeps SSO state across
protocol steps and browser tabs: 30 minutes idle, and at most seven days without a new primary authentication. Closing
one tab does not end this session, and browser session restoration may also retain session cookies. Remember me adds
cookie persistence for `identity.session.remember_me_ttl`, capped at 30 days. Application tokens have independent
lifetimes.

A fresh authorization request with `prompt=login` or `prompt=select_account` starts an anonymous browser session and
invalidates the previous browser SSO anchor and pending operations. Existing application tokens are not revoked. The
user presents credentials again to choose the account; pending login tabs of the previous browser session must restart.
A `login_hint` from the bound authorization request only prefills the editable username; it never selects or
authenticates an identity.

Prompt values are space-separated: `select_account consent` requests both account choice and consent. Combining `none`
with other values is rejected before the session changes.

## Backchannel Bearer Access

If you want to use OIDC-issued Bearer tokens for `/api/v1/*` backchannel calls, enable:

```yaml
auth:
  backchannel:
    oidc_bearer:
      enabled: true
```

Related request-header propagation for subject sources/logging lives at:

- `auth.request.headers.oidc_cid`

Clients that validate opaque OIDC bearer tokens through `/oidc/introspect` can authenticate with client secrets or `private_key_jwt`. For `private_key_jwt`, use the introspection endpoint URL as the client-assertion audience.

Each route family asks only for its own scopes. `nauthilus:authenticate` opens the authentication routes and the
management OpenAPI documents; it is no longer a base scope of every `/api/v1` route. See
[REST API](../../rest-api.md#oidc-bearer-access-for-apiv1) for the route matrix and
[Backchannel Basic Credentials](../../rest-api.md#backchannel-basic-credentials) for Basic authentication, including
scoped Basic credentials that hold the same scopes without a token.

## Built-in Scope Families

The reserved `nauthilus:*` scopes are used for backchannel administration, authority RPCs, and MFA/WebAuthn operations. They are granted through `identity.oidc.clients[].scopes` like any other allowed scope.

| Scope | Purpose |
| --- | --- |
| `nauthilus:admin` | Full administrative access to backchannel API surfaces that accept the admin scope: every HTTP management route that asks for a security, MFA, or WebAuthn scope, and administrative hooks. It does not open the authentication routes and grants no support access. |
| `nauthilus:security` | Read and write access to the security controls: brute-force listings and flushes, cache flushes, and OIDC session administration. Includes `nauthilus:security_read` and `nauthilus:security_write`. |
| `nauthilus:security_read` | Since 4.1.0. Read-only security state: brute-force listings, OIDC session listings, and the status of asynchronous security jobs. |
| `nauthilus:security_write` | Since 4.1.0. Mutations of security state: cache and brute-force flushes, OIDC session deletion, and the status of the asynchronous jobs these start. |
| `nauthilus:authenticate` | Password authentication through backchannel or gRPC authority APIs, and the management OpenAPI documents. |
| `nauthilus:lookup_identity` | Trusted identity lookup and remote user resolution. |
| `nauthilus:list_accounts` | Account listing. |
| `nauthilus:mfa_read` | Read public MFA state. |
| `nauthilus:mfa_verify` | Verify TOTP or recovery-code material. |
| `nauthilus:mfa_write` | Register, update, or delete TOTP and recovery-code state. |
| `nauthilus:webauthn_read` | Read public WebAuthn credential descriptors. |
| `nauthilus:webauthn_write` | Save, update, or delete WebAuthn credentials. |
| `nauthilus:attribute_read` | Release identity attributes to a trusted authority caller. |
| `nauthilus:history_read` | Read-only support history of a named subject (support projection). |
| `nauthilus:history_detail` | Support history with the detail projection; implies `nauthilus:history_read`. |
| `nauthilus:operations_read` | Read-only operational diagnostics. |

For split edge/authority deployments, configure the edge service-principal client with only the scopes needed by its remote backend `allowed_operations`.

The three support scopes are accepted from backchannel service tokens and scoped Basic credentials on the
`/api/v1/support/*` routes and from user tokens of a hosted resource. They are the only scopes a hosted resource may
gate. `nauthilus:admin`, `nauthilus:security`, and the unrestricted Basic credential grant no support access. See
[Read-only Support Access over MCP](../../guides/support-mcp-access.md) and
[Support Authentication History](../../guides/support-authentication-history.md).
