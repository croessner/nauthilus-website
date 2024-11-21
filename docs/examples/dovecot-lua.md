---
title: Dovecot Lua
description: Intergation of Nauthilus in a Dovecot Lua backend
keywords: [Dovecot, Lua]
sidebar_position: 1
---
# Dovecot Lua integration

With some Lua glue in Dovecot, it is possible to connect the service directly to Nauthilus. Starting with Dovecot 2.319
there exists a HTTP client which can be used to communicate seamlessly with nauthilus.

<!-- TOC -->
* [Dovecot Lua integration](#dovecot-lua-integration)
  * [Nauthilus modes](#nauthilus-modes)
      * [?mode=no-auth](#modeno-auth)
      * [?mode=list-accounts](#modelist-accounts)
<!-- TOC -->

Here is a real life example on how to achieve this. The mail system is using LDAP. The latter uses a custom schema,
which you can find [here](https://gitlab.roessner-net.de/croessner/openldap-schema/-/tree/main/mail). Upon successful
login, some extra fields are returned for the userdb backend.

Nauthilus is TLS encrypted and requires HTTP basic authentication. The credentials are read from a file. You can create
one like this:

```shell
echo -n "username:password" | base64 > http-auth.secret
chmod 640 http-auth.secret
chown root:vmail http-auth.secret
```

The Lua code (requires lua-cjson support):

```lua
--
-- START settings
--

local http_debug = false;
local http_basicauthfile = "/etc/dovecot/http-auth.secret"
local http_uri = "https://login.example.com/api/v1/auth/json"
local http_access_denied = "Account not enabled"

--
-- END settings
--

local json = require('cjson')

local PASSDB = "passdb"
local USERDB = "userdb"

-- HTTP defaults
local http_basicauthpassword
local http_client = dovecot.http.client{
  timeout = 300;
  max_attempts = 3;
  debug = http_debug;
  user_agent = "Dovecot/2.3";
}

local function init_http()
  -- Read Nauthilus password
  local file = assert (io.open(http_basicauthfile))

  http_basicauthpassword = file:read("*all")

  file:close()
end

local function query_db(request, password, dbtype)
  local remote_ip = request.remote_ip
  local remote_port = request.remote_port
  local local_ip = request.local_ip
  local local_port = request.local_port
  local client_id = request.client_id
  local qs_noauth = ""
  local extra_fields = {}

  local function add_extra_field(pf, key, value)
    if value ~= nil and value:len()>0 then
      extra_fields[pf .. key] = value
    end
  end

  if dbtype == USERDB then
    qs_noauth = "?mode=no-auth"
  end
  local auth_request = http_client:request {
    url = http_uri .. qs_noauth;
    method = "POST";
  }

  -- Basic Authorization
  auth_request:add_header("Authorization", "Basic " .. http_basicauthpassword)

  -- Set CT
  auth_request:add_header("Content-Type", "application/json")

  if remote_ip == nil then
    remote_ip = "127.0.0.1"
  end
  if remote_port == nil then
    remote_port = "0"
  end
  if local_ip == nil then
    local_ip = "127.0.0.1"
  end
  if local_port == nil then
    local_port = "0"
  end
  if client_id == nil then
    client_id = ""
  end

  if dbtype == PASSDB then
    -- Master user: change passdb-query to userdb-query
    if request.auth_user:lower() ~= request.user:lower() then
      add_extra_field("", "user", request.user)

      local userdb_status = query_db(request, "", USERDB)

      if userdb_status == dovecot.auth.USERDB_RESULT_USER_UNKNOWN then
        return dovecot.auth.PASSDB_RESULT_USER_UNKNOWN, ""
      elseif userdb_status == dovecot.auth.USERDB_RESULT_INTERNAL_FAILURE then
        return dovecot.auth.PASSDB_RESULT_INTERNAL_FAILURE, ""
      else
        return dovecot.auth.PASSDB_RESULT_OK, extra_fields
      end
    end
  end

  local req = {}

  req.username = request.user
  req.password = password
  req.client_ip = remote_ip
  req.client_port = remote_port
  req.client_id = client_id
  req.local_ip = local_ip
  req.local_port = local_port
  req.service = request.service
  req.method = request.mech:lower()

  if request.secured == "TLS" or request.secured == "secured" then
    req.ssl = "1"
    req.ssl_protocol = request.secured

    if request.cert ~= "" then
      req.ssl_client_verify = "1"
    end
  end

  if request.session ~= nil then
    auth_request:add_header("X-Dovecot-Session", request.session)
  end

  auth_request:set_payload(json.encode(req))

  -- Send
  local auth_response = auth_request:submit()

  -- Response
  local auth_status_code = auth_response:status()
  local auth_status_message = auth_response:header("Auth-Status")

  local dovecot_account = auth_response:header("Auth-User")
  local nauthilus_session = auth_response:header("X-Nauthilus-Session")

  dovecot.i_info("request=" .. dbtype .. " auth_status_code=" .. tostring(auth_status_code) .. " auth_status_message=<" .. auth_status_message .. "> nauthilus_session=" .. nauthilus_session)

  -- Handle valid logins
  if auth_status_code == 200 then
    local resp = json.decode(auth_response:payload())
    local pf = ""

    if dovecot_account and dovecot_account ~= "" then
      add_extra_field("", "user", dovecot_account)
    end

    if dbtype == PASSDB then
      pf = "userdb_"
    end

    if resp and    resp.attributes then
      if resp.attributes.rnsMSQuota then
        add_extra_field(pf, "quota_rule=*:bytes", resp.attributes.rnsMSQuota[1])
      end

      if resp.attributes.rnsMSOverQuota then
        add_extra_field(pf, "quota_over_flag", resp.attributes.rnsMSOverQuota[1])
      end

      if resp.attributes.rnsMSMailPath then
        add_extra_field(pf, "mail", resp.attributes.rnsMSMailPath[1])
      end

      if resp.attributes["ACL-Groups"] then
        add_extra_field(pf, "acl_groups", resp.attributes["ACL-Groups"][1])
      end
    end

    if request.session then
      if dbtype == PASSDB then
        if resp and resp.attributes then
          local proxy_host
          local master_user

          if resp.attributes["Proxy-Host"] then
            proxy_host =    resp.attributes["Proxy-Host"][1]
          end

          if resp.attributes.rnsMSDovecotMaster then
            master_user = resp.attributes.rnsMSDovecotMaster[1]
          end

          -- Master users must not be proxied
          if master_user and master_user == "" then
            if proxy_host and    proxy_host ~= "" then
              extra_fields.proxy_maybe = "y"
              extra_fields.proxy_timeout = "120"
              extra_fields.host = proxy_host
            end
          end
        end
      end
    end

    if dbtype == PASSDB then
      return dovecot.auth.PASSDB_RESULT_OK, extra_fields
    else
      return dovecot.auth.USERDB_RESULT_OK, extra_fields
    end
  end

  -- Handle failed logins
  if auth_status_code == 403 then
    if dbtype == PASSDB then
      if auth_status_message == http_access_denied then
        return dovecot.auth.PASSDB_RESULT_USER_DISABLED, auth_status_message
      end

      return dovecot.auth.PASSDB_RESULT_PASSWORD_MISMATCH, auth_status_message
    else
      return dovecot.auth.USERDB_RESULT_USER_UNKNOWN, auth_status_message
    end
  end

  -- Unable to communicate with Nauthilus (implies status codes 50X)
  if dbtype == PASSDB then
    return dovecot.auth.PASSDB_RESULT_INTERNAL_FAILURE, ""
  else
    return dovecot.auth.USERDB_RESULT_INTERNAL_FAILURE, ""
  end
end

function auth_userdb_lookup(request)
  return query_db(request, "", USERDB)
end

-- {{{
function auth_passdb_lookup(request)
  _ = request

  return dovecot.auth.PASSDB_RESULT_OK, "nopassword=y"
end
-- }}}

function auth_password_verify(request, password)
  return query_db(request, password, PASSDB)
end

function script_init()
  init_http()

  return 0
end

function script_deinit()
end

function auth_userdb_iterate()
  local user_accounts = {}

  local list_request = http_client:request {
    url = http_uri .. "?mode=list-accounts";
    method = "GET";
  }

  -- Basic Authorization
  list_request:add_header("Authorization", "Basic " .. http_basicauthpassword)

  -- Set CT
  list_request:add_header("Accept", "application/json")

  local list_response = list_request:submit()
  local resp_status = list_response:status()

  if resp_status == 200 then
    user_accounts = json.decode(list_response:payload())
  end

  return user_accounts
end

```

Look at the code especially to the response headers. Nauthilus is delivering all extra fields by prefixing HTTP headers
with X-Nauthilus- and the name of an extra field. The result itself is JSON. Most of the time, you will use values from the
**attributes** list. In the example above, you can see my current working configuration with OpenLDAP and my own schema.

## Nauthilus modes

As Dovecot needs three different things like passdb, userdb and iterator, nauthilus was made compatible to deal with
these requirements. By adding a query string to the HTTP request, nauthilus knows what to deliver. See the description
at the endpoint page.

#### ?mode=no-auth

This mode is used for the userdb lookup. It fetches a user and its extra fields. In this mode, no authentication is done
at all.

#### ?mode=list-accounts

This mode returns the full list of known accounts.
