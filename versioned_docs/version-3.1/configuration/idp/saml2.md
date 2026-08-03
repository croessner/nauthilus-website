---
sidebar_position: 3
description: Native SAML configuration in config v2
keywords: [Identity Provider, SAML2]
---

# SAML

Nauthilus includes a native SAML IdP.

The current configuration root is:

- `identity.saml`

## Endpoints

- `GET /saml/metadata`
- `GET /saml/sso`
- `GET /saml/slo` for the Redirect binding
- `POST /saml/slo` for the POST binding

## Example

```yaml
identity:
  saml:
    enabled: true
    entity_id: "https://idp.example.com/saml"
    cert_file: "/etc/nauthilus/saml/idp.pem"
    key_file: "/etc/nauthilus/saml/idp.key"
    signature_method: "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
    default_expire_time: 1h
    name_id_format: "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"
    slo:
      enabled: true
      front_channel_enabled: true
      back_channel_enabled: false
      request_timeout: 3s
      max_participants: 64
      back_channel_max_retries: 1
    service_providers:
      - name: "Example SP"
        entity_id: "https://sp.example.com/metadata"
        acs_url: "https://sp.example.com/saml/acs"
        slo_url: "https://sp.example.com/saml/slo"
        slo_back_channel_url: "https://sp.example.com/saml/slo/backchannel"
        cert_file: "/etc/nauthilus/saml/sp.pem"
        authn_requests_signed: true
        logout_requests_signed: true
        logout_responses_signed: true
        require_mfa:
          - "totp"
        supported_mfa:
          - "totp"
          - "webauthn"
        required_mfa_level: 2
        allowed_attributes:
          - "mail"
          - "cn"
          - "uid"
```

## Request Signature Policy

`authn_requests_signed`, `logout_requests_signed`, and `logout_responses_signed` control the inbound signature policy
for a service provider. Their default is `false`.

When one of these fields is `true`, the service provider must also provide a valid signing certificate through `cert`
or `cert_file`; Nauthilus validates that configuration at startup. An unsigned message for a required-signature flow is
rejected. When a signature is present even though it is not required, Nauthilus still validates it and rejects an
invalid signature.

Redirect-binding messages use the detached query signature. POST-binding SLO messages use an XML signature. Nauthilus
rejects malformed signature parameter combinations and unsupported algorithms, including SHA-1 signature algorithms.

## Single Logout Security

SAML SLO validates message type, signature, protocol fields, destination, time bounds, participant correlation, and
request replay state before local session cleanup. `identity.saml.slo` controls front-channel and back-channel fanout.

Back-channel SLO delivery does not follow HTTP redirects. Configure every `slo_back_channel_url` as the final HTTPS
endpoint. A `3xx` response is a failed delivery and may fall back to front-channel fanout when that channel is enabled.

Keep `request_timeout`, `max_participants`, and `back_channel_max_retries` non-negative. Setting `slo.enabled: false`
also makes the channel-specific flags ineffective.

## Attribute Release

`allowed_attributes` is an allowlist for assertion attributes. An empty list permits normal releasable attributes, but
Nauthilus always removes secret-bearing values such as passwords, tokens, private keys, TOTP secrets, and recovery-code
fields. Adding a sensitive name to `allowed_attributes` does not override that protection.

Attribute names are classified defensively across case and common word separators. Keep authentication secrets in
dedicated backend fields and never design a service provider to consume them from a SAML assertion.

## MFA Assurance

Service providers can configure `require_mfa`, `supported_mfa`, `required_mfa_level`, and local `mfa_policy.levels`.
Nauthilus verifies the current proof strength before issuing an assertion and separately enforces required factor
enrollment. See [MFA Assurance Policy](mfa-assurance.md).

## Notes

- SLO is nested below `identity.saml.slo`
- old flat aliases such as `identity.saml.slo_enabled` are not part of the current surface
- browser MFA and frontend behavior are shared with OIDC through `identity.frontend` and `identity.mfa`
