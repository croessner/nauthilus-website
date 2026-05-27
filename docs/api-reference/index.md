---
title: API Reference
description: Generated OpenAPI references for Nauthilus HTTP APIs
keywords: [OpenAPI, REST API, API Reference, Nauthilus]
sidebar_position: 11
---

# API Reference

This section is generated from the OpenAPI contracts maintained in the Nauthilus server repository. The regular REST API documentation remains the narrative guide; these pages provide the endpoint explorer, request and response schemas, and downloadable raw contracts.

| Reference | Contract | Operations | Schemas | Raw Spec |
| --- | --- | ---: | ---: | --- |
| [Management API](./management/nauthilus-management-api) | Nauthilus Management API | 28 | 33 | [YAML](/openapi/management.yaml) · [JSON](/openapi/management.json) |
| [IdP API](./idp/nauthilus-idp-api) | Nauthilus IdP API | 32 | 10 | [YAML](/openapi/idp.yaml) · [JSON](/openapi/idp.json) |

## Workflow

- Update the canonical specs in the server repository.
- Run `npm run openapi:generate` in this repository to refresh static specs and generated API docs.
- Run `npm run build` to verify the complete Docusaurus site.
