# Identity Provider Templates

Nauthilus provides a modern, responsive, and highly customizable frontend for the Identity Provider (OIDC/SAML2). The UI is built using a lightweight stack:

*   **[HTMX](https://htmx.org/):** Handles dynamic updates and AJAX requests without complex JavaScript frameworks.
*   **[Tailwind CSS](https://tailwindcss.com/):** For utility-first styling.
*   **[DaisyUI](https://daisyui.com/):** A component library for Tailwind CSS providing themes and UI elements.

## Template Location

All IdP templates are located in the directory specified by the `server::frontend::html_static_content_path` configuration setting (defaulting to the `static/templates` folder in the project root).

## Template Structure

Templates follow a standard Go `html/template` structure. Most pages are composed of a header, the specific content, and a footer.

### Shared Components

*   **`idp_header.html`**: Contains the HTML `<head>`, CSS/JS includes, navigation bar, language switcher, and user profile menu.
*   **`idp_footer.html`**: Contains the closing tags for the main content area, a modal container for HTMX dialogs, and the footer bar.
*   **`idp_error_modal.html`**: A reusable fragment for displaying error messages in a modal dialog.

## Template Reference

The following templates are used by the Identity Provider, grouped by their purpose:

### Authentication & Session
| Template | Description |
| :--- | :--- |
| `idp_login.html` | The main login page (Username/Password). |
| `idp_recovery_login.html` | Login page using MFA recovery codes. |
| `idp_logged_out.html` | Simple confirmation page after a successful logout. |
| `idp_logout_frames.html` | Used for coordinating OIDC Front-Channel logout (renders hidden iframes). |

### Multi-Factor Authentication (MFA)
| Template | Description |
| :--- | :--- |
| `idp_mfa_select.html` | Selection screen when multiple MFA methods are available. |
| `idp_totp_verify.html` | Verification screen for TOTP (Time-based One-Time Password). |
| `idp_webauthn_verify.html` | Verification screen for WebAuthn (Security Keys, Biometrics). |

### MFA Management (User Self-Service)
| Template | Description |
| :--- | :--- |
| `idp_2fa_home.html` | Overview page for managing own MFA devices. |
| `idp_totp_register.html` | Registration page for a new TOTP secret (QR code). |
| `idp_webauthn_register.html` | Registration page for a new WebAuthn credential. |
| `idp_2fa_webauthn_devices.html` | List of registered WebAuthn devices with management options. |
| `idp_recovery_codes_modal.html` | Displays newly generated recovery codes to the user. |

### Device Code Flow (RFC 8628)
| Template | Description |
| :--- | :--- |
| `idp_device_verify.html` | Device code verification page where users enter the code displayed on their device and sign in. |
| `idp_device_verify_success.html` | Success page shown after the device has been successfully authorized. |

### Protocols
| Template | Description |
| :--- | :--- |
| `idp_consent.html` | OIDC Consent page where users approve requested scopes for an application. |

## Template Variables

The following variables are available in the templates.

### Global Variables (available in almost all templates)

| Variable | Type | Description |
| :--- | :--- | :--- |
| `.LanguageTag` | `string` | The current language tag (e.g., "en", "de"). |
| `.LanguageCurrentName` | `string` | The name of the current language in its own language. |
| `.LanguagePassive` | `[]Language` | List of other available languages for the switcher. |
| `.Username` | `string` | The username of the currently logged-in user (if any). |
| `.DevMode` | `bool` | True if `NAUTHILUS_DEVELOPER_MODE` is active. |
| `.HXRequest` | `bool` | True if the current request was initiated by HTMX. |
| `.Title` | `string` | The page title, usually localized. |
| `.CSRFToken` | `string` | The token used for CSRF protection (see [CSRF Integration](#csrf-integration) below). |
| `.ConfirmTitle` | `string` | Localized title for confirmation dialogs. |
| `.ConfirmYes` | `string` | Localized "Yes" label. |
| `.ConfirmNo` | `string` | Localized "Cancel" label. |

### Context-Specific Variables

*   **Login (`idp_login.html`)**:
    *   `.UsernameLabel`, `.UsernamePlaceholder`, `.PasswordLabel`, `.PasswordPlaceholder`, `.Submit`: Localized UI strings.
    *   `.PostLoginEndpoint`: The URL where the login form is submitted.
    *   `.ShowRememberMe`: Boolean flag to show/hide the "Remember Me" checkbox.
    *   `.RememberMeLabel`: Localized label for the "Remember Me" checkbox.
    *   `.TermsOfServiceURL`, `.PrivacyPolicyURL`: URLs for legal pages (optional).
    *   `.LegalNoticeLabel`, `.PrivacyPolicyLabel`: Localized labels for legal links.
*   **Consent (`idp_consent.html`)**:
    *   `.Application`: Localized "Application" label.
    *   `.ClientID`: The OIDC Client ID of the requesting application.
    *   `.Scopes`: List of requested OIDC scopes.
    *   `.ConsentChallenge`: The unique ID for this consent request.
    *   `.PostConsentEndpoint`: The URL to submit the consent decision.
*   **Device Code Verification (`idp_device_verify.html`)**:
    *   `.DeviceVerifyDescription`: Localized description text for the device verification page.
    *   `.UserCodeLabel`: Localized label for the user code input field.
    *   `.UserCode`: Pre-filled user code (if provided via query parameter).
    *   `.PostDeviceVerifyEndpoint`: The URL to submit the device verification form.
    *   `.ErrorMessage`: Error message to display (if any).

*   **Device Code Success (`idp_device_verify_success.html`)**:
    *   `.DeviceVerifySuccessMessage`: Localized success message.
    *   `.DeviceVerifySuccessHint`: Localized hint telling the user to return to their device.

*   **MFA Management**:
    *   `.TOTPEnabled`, `.WebAuthnEnabled`: Boolean flags indicating available methods.
    *   `.RecoveryCodesRemaining`: Count of unused recovery codes.

## Template Functions

Nauthilus provides a few helper functions for use within templates:

*   **`int`**: Converts various numeric types (int32, int64, float64) to a standard `int`.
*   **`upper`**: Converts a string to uppercase (e.g., `{{ .Username | upper }}`).

## CSRF Integration

Nauthilus uses CSRF (Cross-Site Request Forgery) protection on all IdP pages. The `.CSRFToken` variable is available in all templates and **must** be included in requests depending on the type of submission.

### HTML Forms

For standard HTML form submissions, include the token as a hidden input field:

```html
<form method="POST" action="/some/endpoint">
    <input type="hidden" name="csrf_token" value="{{ .CSRFToken }}"/>
    <!-- other form fields -->
    <button type="submit">Submit</button>
</form>
```

### HTMX Requests

For HTMX-powered requests, include the token in the `hx-headers` attribute:

```html
<button hx-post="/some/endpoint"
        hx-headers='{"X-CSRF-Token": "{{ .CSRFToken }}"}'>
    Submit
</button>

<form hx-post="/some/endpoint"
      hx-headers='{"X-CSRF-Token": "{{ .CSRFToken }}"}'
      hx-target="#result">
    <!-- form fields -->
</form>
```

### JavaScript Fetch Requests

For JavaScript `fetch()` calls, include the token in the request headers:

```javascript
const response = await fetch("/some/endpoint", {
    method: "POST",
    headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": "{{ .CSRFToken }}"
    },
    body: JSON.stringify(data)
});
```

:::important
All POST, PUT, PATCH, and DELETE requests to IdP endpoints require a valid CSRF token. Requests without a valid token will be rejected with a `400 Bad Request` response.
:::

## Flow State Management

Nauthilus stores IdP flow state (OIDC authorization parameters, SAML request data) in secure, HTTP-only cookies rather than URL query parameters. This approach:

*   **Prevents Open Redirect vulnerabilities**: The redirect target is validated and stored server-side.
*   **Simplifies template logic**: No query parameters need to be passed between pages.
*   **Improves security**: Sensitive flow data is not exposed in URLs or browser history.

After successful MFA verification or login, the server automatically reads the flow state from the cookie and redirects the user to the appropriate IdP endpoint (OIDC authorization or SAML SSO).

## Customization & Theming

### idp-theme.css

The file `static/css/idp-theme.css` is included in the header and is the primary place for visual customizations. You can override DaisyUI variables or add your own CSS rules here.

### Logos and Images

By default, the header looks for `/static/img/logo.png`. You can replace this file or modify `idp_header.html` to point to a different path or URL.

### Customizing Templates

To customize the UI, you should copy the default templates from the Nauthilus source into your own directory and point `server::frontend::html_static_content_path` to that directory. This allows you to modify the HTML structure, change the order of elements, or add custom scripts while keeping the core logic intact.

## Developer Mode

When developing or debugging templates, you can enable the Developer Mode by setting the environment variable:

```bash
export NAUTHILUS_DEVELOPER_MODE=true
```

### Effects of Developer Mode
*   Templates are reloaded on every request (if they are not embedded).
*   Additional debug information is shown in the UI.
*   Session cookies are not marked as `Secure`, allowing testing over plain HTTP.
*   HTMX logging is enabled in the browser console (`htmx.logAll()`).

### UI Debug Endpoint

The endpoint `/api/v1/dev/ui` is available in developer mode to preview UI components and fragments in isolation. This is particularly useful for testing localized strings and HTMX interactions without going through a full login flow.
