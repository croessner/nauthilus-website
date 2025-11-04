---
title: Mail
description: SMTP and LMTP related functions
keywords: [Lua]
sidebar_position: 7
---
# Mail

SMTP/LMTP related functions

```lua
dynamic_loader("nauthilus_mail")
local nauthilus_mail = require("nauthilus_mail")
```

## nauthilus\_mail.send\_mail

Sends an email using SMTP or LMTP protocol.

### Syntax

```lua
local error = nauthilus_mail.send_mail(mail_params)
```

### Parameters

- `mail_params` (table): A Lua table containing the email parameters:
  - `username` (string, optional): Username for authentication
  - `password` (string, optional): Password for authentication
  - `from` (string): The sender including an optional canonical name
  - `to` (table): A table of recipients
  - `server` (string): The address of the mail server
  - `port` (number): The port number of the mail server
  - `helo_name` (string): The HELO/LHLO name
  - `subject` (string): The subject of the message
  - `body` (string): The body of the message
  - `tls` (boolean): Should the connection be secured aka SMTPS?
  - `starttls` (boolean): Use starttls command
  - `lmtp` (boolean): Do we send with LMTP (true) or SMTP (false)?

### Returns

- `error` (string): An error message if sending fails, nil if successful

### Example

```lua
dynamic_loader("nauthilus_mail")
local nauthilus_mail = require("nauthilus_mail")

dynamic_loader("nauthilus_gll_template")
local template = require("template")

local smtp_message = [[
Hallo,

Username: {{username}}
Account: {{account}}

...
]]

local tmpl_data = {
  username = request.username, -- Might come from the request object of the calling function
  account = request.account, -- Might come from the request object of the calling function
}

local mustache, err_tmpl = template.choose("mustache")

local err_email = nauthilus_mail.send_mail({
                    lmtp = true,
                    server = "10.0.0.24",
                    port = 24,
                    helo_name = "localhost.localdomain",
                    from = '"Sicherheitshinweis" <abuse@example.test>',
                    to = { request.account }, -- Might come from the request object of the calling function
                    subject = "Some subject",
                    body = mustache:render(smtp_message, tmpl_data),
                })
```
