import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebar: SidebarsConfig = {
  apisidebar: [
    {
      type: "doc",
      id: "api-reference/idp/nauthilus-idp-api",
    },
    {
      type: "category",
      label: "OpenAPI",
      link: {
        type: "doc",
        id: "api-reference/idp/open-api",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/idp/get-public-id-p-open-apiyaml",
          label: "Get the public IdP OpenAPI document as YAML.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-public-id-p-open-apijson",
          label: "Get the public IdP OpenAPI document as JSON.",
          className: "api-method get",
        },
      ],
    },
    {
      type: "category",
      label: "OIDC",
      link: {
        type: "doc",
        id: "api-reference/idp/oidc",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/idp/get-oidc-discovery",
          label: "Get OIDC discovery metadata.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/authorize-oidc",
          label: "Start or continue an OIDC authorization request.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/exchange-oidc-token",
          label: "Exchange an OIDC or OAuth token request.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-oidc-user-info",
          label: "Get OIDC userinfo claims for the bearer token subject.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/introspect-oidc-token",
          label: "Introspect an OAuth token.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-oidcjwks",
          label: "Get the OIDC JSON Web Key Set.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/start-oidc-device-authorization",
          label: "Start the OAuth 2.0 device authorization flow.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-oidc-device-verify",
          label: "Render the device verification page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/post-oidc-device-verify",
          label: "Submit a device verification code.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-oidc-device-consent",
          label: "Render the device consent page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/post-oidc-device-consent",
          label: "Submit device consent.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/oidc-logout",
          label: "Start OIDC logout.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-oidc-consent",
          label: "Render the OIDC consent page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/post-oidc-consent",
          label: "Submit OIDC consent.",
          className: "api-method post",
        },
      ],
    },
    {
      type: "category",
      label: "SAML",
      link: {
        type: "doc",
        id: "api-reference/idp/saml",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/idp/get-saml-metadata",
          label: "Get SAML IdP metadata.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/saml-sso",
          label: "Start SAML single sign-on.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-samlslo",
          label: "Start SAML single logout with a redirect binding request.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/post-samlslo",
          label: "Start SAML single logout with a POST binding request.",
          className: "api-method post",
        },
      ],
    },
    {
      type: "category",
      label: "Browser",
      link: {
        type: "doc",
        id: "api-reference/idp/browser",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/idp/get-oidc-device-verify",
          label: "Render the device verification page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/post-oidc-device-verify",
          label: "Submit a device verification code.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-oidc-device-consent",
          label: "Render the device consent page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/post-oidc-device-consent",
          label: "Submit device consent.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/oidc-logout",
          label: "Start OIDC logout.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/browser-logout",
          label: "Start browser logout.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-oidc-consent",
          label: "Render the OIDC consent page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/post-oidc-consent",
          label: "Submit OIDC consent.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-login",
          label: "Render the primary login page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/post-login",
          label: "Submit primary login credentials.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-totp-login",
          label: "Render the TOTP login page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/post-totp-login",
          label: "Submit a TOTP login code.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-web-authn-login",
          label: "Render the WebAuthn login page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/begin-web-authn-login",
          label: "Begin WebAuthn login.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/finish-web-authn-login",
          label: "Finish WebAuthn login.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-mfa-selection",
          label: "Render the MFA method selection page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-recovery-login",
          label: "Render the recovery-code login page.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/idp/post-recovery-login",
          label: "Submit a recovery-code login.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/idp/get-logged-out",
          label: "Render the logged-out page.",
          className: "api-method get",
        },
      ],
    },
    {
      type: "category",
      label: "Schemas",
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/idp/schemas/deviceauthorizationresponse",
          label: "DeviceAuthorizationResponse",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/idp/schemas/errorresponse",
          label: "ErrorResponse",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/idp/schemas/introspectionrequest",
          label: "IntrospectionRequest",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/idp/schemas/introspectionresponse",
          label: "IntrospectionResponse",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/idp/schemas/jwks",
          label: "JWKS",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/idp/schemas/loginform",
          label: "LoginForm",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/idp/schemas/oautherror",
          label: "OAuthError",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/idp/schemas/oidcdiscovery",
          label: "OIDCDiscovery",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/idp/schemas/tokenrequest",
          label: "TokenRequest",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/idp/schemas/tokenresponse",
          label: "TokenResponse",
          className: "schema",
        },
      ],
    },
  ],
};

export default sidebar.apisidebar;
