---
title: DNS
description: DNS lookup functions
keywords: [Lua]
sidebar_position: 14
---
# DNS

The DNS module provides functions for performing DNS lookups.

```lua
dynamic_loader("nauthilus_dns")
local nauthilus_dns = require("nauthilus_dns")
```

## nauthilus\_dns.resolve

Performs a DNS record lookup for the specified domain and record type.

### Syntax

```lua
local result, error = nauthilus_dns.resolve(domain, record_type)
```

### Parameters

- `domain` (string): The domain name to look up
- `record_type` (string, optional): The type of DNS record to look up. Defaults to "A" if not specified. Supported values:
  - **A**: IPv4 address records
  - **AAAA**: IPv6 address records
  - **MX**: Mail exchange records
  - **NS**: Name server records
  - **TXT**: Text records
  - **CNAME**: Canonical name records
  - **PTR**: Pointer records (reverse DNS)

### Returns

- `result` (table/string): The lookup result, which varies based on the record type:
  - For **A**, **AAAA**, **NS**, **TXT**, and **PTR**: A table of strings
  - For **MX**: A table of objects with `host` and `pref` (preference) fields
  - For **CNAME**: A string containing the canonical name
- `error` (string): An error message if the lookup fails

### Example

```lua
dynamic_loader("nauthilus_dns")
local nauthilus_dns = require("nauthilus_dns")

-- Look up A records
local a_records, err = nauthilus_dns.resolve("example.com", "A")
if err then
  print("Error:", err)
else
  for i, ip in ipairs(a_records) do
    print("IP address:", ip)
  end
end

-- Look up MX records
local mx_records, err = nauthilus_dns.resolve("example.com", "MX")
if err then
  print("Error:", err)
else
  for i, mx in ipairs(mx_records) do
    print("Mail server:", mx.host, "Preference:", mx.pref)
  end
end

-- Look up CNAME record
local cname, err = nauthilus_dns.resolve("www.example.com", "CNAME")
if err then
  print("Error:", err)
else
  print("Canonical name:", cname)
end
```

::::warning
DNS lookups are blocking operations and may time out based on the server's DNS timeout configuration.
::::