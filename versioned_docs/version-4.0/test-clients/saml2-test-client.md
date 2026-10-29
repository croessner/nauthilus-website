---
title: SAML2 Test Client
description: SAML test client example using the current identity config
keywords: [SAML2, Test Client, Service Provider]
sidebar_position: 3
---

# SAML2 Test Client

The `saml2testclient` is a lightweight Service Provider used for end-to-end validation of Nauthilus SAML login and logout behavior.

## Required Nauthilus Configuration

```yaml
identity:
  saml:
    enabled: true
    entity_id: "https://localhost:9443/saml"
    cert: "YOUR_IDP_CERTIFICATE_HERE"
    key: "YOUR_IDP_KEY_HERE"
    service_providers:
      - entity_id: "https://localhost:9095/saml/metadata"
        acs_url: "https://localhost:9095/saml/acs"
        cert_file: "contrib/saml2testclient/sp-cert.pem"
```

Use the exported SP certificate from the test client in `identity.saml.service_providers[].cert_file`.
