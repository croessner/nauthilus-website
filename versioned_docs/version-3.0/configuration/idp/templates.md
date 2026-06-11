---
title: Identity Templates
description: Frontend template and asset configuration in config v2
keywords: [Identity, Templates, Frontend]
sidebar_position: 5
---

# Identity Templates

The browser-facing templates and static assets are configured through `identity.frontend`.

## Template Location

Use:

- `identity.frontend.assets.html_static_content_path`

to point Nauthilus at your template and static asset directory.

Language resource files are configured through:

- `identity.frontend.assets.language_resources`

## Related Frontend Settings

- `identity.frontend.enabled`
- `identity.frontend.localization.languages`
- `identity.frontend.localization.default_language`
- `identity.frontend.links.terms_of_service_url`
- `identity.frontend.links.privacy_policy_url`
- `identity.frontend.links.password_forgotten_url`
- `identity.frontend.security_headers.enabled`

## Customization

The recommended workflow is:

1. copy the shipped templates into your own directory
2. set `identity.frontend.assets.html_static_content_path`
3. keep your changes outside the application binary or container image

This keeps UI customization separate from runtime logic and matches the current config-v2 structure.
