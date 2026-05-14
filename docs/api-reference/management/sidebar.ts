import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebar: SidebarsConfig = {
  apisidebar: [
    {
      type: "doc",
      id: "api-reference/management/nauthilus-management-api",
    },
    {
      type: "category",
      label: "OpenAPI",
      link: {
        type: "doc",
        id: "api-reference/management/open-api",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/management/get-open-apiyaml",
          label: "Get the OpenAPI document as YAML.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/management/get-open-apijson",
          label: "Get the OpenAPI document as JSON.",
          className: "api-method get",
        },
      ],
    },
    {
      type: "category",
      label: "Authentication",
      link: {
        type: "doc",
        id: "api-reference/management/authentication",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/management/get-json-auth",
          label: "Run the JSON authentication endpoint without a JSON body.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/management/post-json-auth",
          label: "Authenticate with a strict JSON request body.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/management/get-cbor-auth",
          label: "Run the CBOR authentication endpoint without a CBOR body.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/management/post-cbor-auth",
          label: "Authenticate with a strict CBOR request body.",
          className: "api-method post",
        },
      ],
    },
    {
      type: "category",
      label: "BruteForce",
      link: {
        type: "doc",
        id: "api-reference/management/brute-force",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/management/list-brute-force-entries",
          label: "List active brute-force bans and blocked accounts.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/management/list-filtered-brute-force-entries",
          label: "List active brute-force data with optional account and IP filters.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/management/flush-brute-force-rule",
          label: "Flush brute-force data for a configured rule.",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "api-reference/management/enqueue-brute-force-rule-flush",
          label: "Enqueue an asynchronous brute-force rule flush.",
          className: "api-method delete",
        },
      ],
    },
    {
      type: "category",
      label: "Cache",
      link: {
        type: "doc",
        id: "api-reference/management/cache",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/management/flush-user-cache",
          label: "Flush authentication cache entries for a user.",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "api-reference/management/enqueue-user-cache-flush",
          label: "Enqueue an asynchronous user cache flush.",
          className: "api-method delete",
        },
      ],
    },
    {
      type: "category",
      label: "Config",
      link: {
        type: "doc",
        id: "api-reference/management/config",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/management/load-runtime-config",
          label: "Return the loaded runtime configuration as JSON text.",
          className: "api-method get",
        },
      ],
    },
    {
      type: "category",
      label: "Async",
      link: {
        type: "doc",
        id: "api-reference/management/async",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/management/get-async-job-status",
          label: "Get the status of an asynchronous backchannel job.",
          className: "api-method get",
        },
      ],
    },
    {
      type: "category",
      label: "MFA",
      link: {
        type: "doc",
        id: "api-reference/management/mfa",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/management/setup-totp",
          label: "Start TOTP registration for the current session account.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/management/register-totp",
          label: "Complete TOTP registration for the current session account.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/management/delete-totp",
          label: "Remove TOTP for the current session account.",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "api-reference/management/generate-recovery-codes",
          label: "Generate recovery codes for the current session account.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/management/begin-web-authn-registration",
          label: "Begin WebAuthn credential registration.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/management/finish-web-authn-registration",
          label: "Finish WebAuthn credential registration.",
          className: "api-method post",
        },
        {
          type: "doc",
          id: "api-reference/management/delete-web-authn-credential",
          label: "Remove a WebAuthn credential for the current session account.",
          className: "api-method delete",
        },
      ],
    },
    {
      type: "category",
      label: "OIDCSessions",
      link: {
        type: "doc",
        id: "api-reference/management/oidc-sessions",
      },
      collapsed: true,
      items: [
        {
          type: "doc",
          id: "api-reference/management/list-oidc-sessions",
          label: "List active OIDC sessions for a user.",
          className: "api-method get",
        },
        {
          type: "doc",
          id: "api-reference/management/delete-oidc-sessions",
          label: "Delete all OIDC sessions for a user.",
          className: "api-method delete",
        },
        {
          type: "doc",
          id: "api-reference/management/delete-oidc-session",
          label: "Delete one OIDC session for a user.",
          className: "api-method delete",
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
          id: "api-reference/management/schemas/accountlist",
          label: "AccountList",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/asyncacceptedpayload",
          label: "AsyncAcceptedPayload",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/asyncacceptedresult",
          label: "AsyncAcceptedResult",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/asyncjobstatuspayload",
          label: "AsyncJobStatusPayload",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/asyncjobstatusresult",
          label: "AsyncJobStatusResult",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/attributemapping",
          label: "AttributeMapping",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/autherror",
          label: "AuthError",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/authrequest",
          label: "AuthRequest",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/authsuccess",
          label: "AuthSuccess",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/bruteforcebanentry",
          label: "BruteForceBanEntry",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/bruteforceblockedaccounts",
          label: "BruteForceBlockedAccounts",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/bruteforceblockedipaddresses",
          label: "BruteForceBlockedIPAddresses",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/bruteforcefilterrequest",
          label: "BruteForceFilterRequest",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/bruteforceflushpayload",
          label: "BruteForceFlushPayload",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/bruteforceflushrequest",
          label: "BruteForceFlushRequest",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/bruteforceflushresult",
          label: "BruteForceFlushResult",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/bruteforcelistresult",
          label: "BruteForceListResult",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/cacheflushpayload",
          label: "CacheFlushPayload",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/cacheflushrequest",
          label: "CacheFlushRequest",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/cacheflushresult",
          label: "CacheFlushResult",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/configloadresult",
          label: "ConfigLoadResult",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/errorresponse",
          label: "ErrorResponse",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/fielderror",
          label: "FieldError",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/fielderrorresponse",
          label: "FieldErrorResponse",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/oidcsessions",
          label: "OIDCSessions",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/recoverycodesresponse",
          label: "RecoveryCodesResponse",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/resultenvelope",
          label: "ResultEnvelope",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/statusmessage",
          label: "StatusMessage",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/totpregisterrequest",
          label: "TOTPRegisterRequest",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/totpsetupresponse",
          label: "TOTPSetupResponse",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/webauthnfinishrequest",
          label: "WebAuthnFinishRequest",
          className: "schema",
        },
        {
          type: "doc",
          id: "api-reference/management/schemas/webauthnoptions",
          label: "WebAuthnOptions",
          className: "schema",
        },
      ],
    },
  ],
};

export default sidebar.apisidebar;
