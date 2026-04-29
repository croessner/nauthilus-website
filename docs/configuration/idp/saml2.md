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
- `GET /saml/slo`

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
        allowed_attributes:
          - "mail"
          - "cn"
          - "uid"
```

## Notes

- SLO is nested below `identity.saml.slo`
- old flat aliases such as `identity.saml.slo_enabled` are not part of the current surface
- browser MFA and frontend behavior are shared with OIDC through `identity.frontend` and `identity.mfa`
