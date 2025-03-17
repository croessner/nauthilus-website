---
title: Mail
description: SMTP and LMTP related functions
keywords: [Lua]
sidebar_position: 7
---

<!-- TOC -->
* [Mail](#mail)
  * [nauthilus\_mail.send\_mail](#nauthilus_mailsend_mail)
<!-- TOC -->

# Mail

SMTP/LMTP related functions

```lua
dynamic_loader("nauthilus_mail")
local nauthilus_mail = require("nauthilus_mail")
```

## nauthilus\_mail.send\_mail

Send an email using SMTP or LMTP

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

The table expects the following keys:

| Name      | Description                                            |
|-----------|--------------------------------------------------------|
| username  | Username for authentication (optional)                 |
| password  | Password for authentication (optional)                 |
| from      | The sender including an optional canonical name        |
| to        | A table of recipients                                  |
| server    | The address of the mail server                         |
| port      | The port number of the mail server                     |
| helo_name | The HELO/LHLO name                                     |
| subject   | The subject of the message                             |
| body      | The body of the message                                |
| tls       | Should the connection be secured aka SMTPS? true/false |
| starttls  | Use starttls command true/false                        |
| lmtp      | Do we send with LMTP (true) or SMTP (false)?           |
