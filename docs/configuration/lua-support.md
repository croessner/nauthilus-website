---
title: Lua support
description: Documentation of Lua support built into Nauthilus
keywords: [Lua]
sidebar_position: 5
---
# Lua Support

Nauthilus has Lua 5.1 support in all areas of the service. To understand the interfaces, you must first get an idea of
what happens with an incoming authentication request.

<!-- TOC -->
* [Lua Support](#lua-support)
  * [Authentication workflow](#authentication-workflow)
  * [Additional things to know](#additional-things-to-know)
  * [Configuration](#configuration)
  * [Lua components](#lua-components)
    * [Actions](#actions)
    * [Features](#features)
    * [Lua backend](#lua-backend)
    * [Filters](#filters)
    * [Post actions](#post-actions)
  * [Required functions and constants](#required-functions-and-constants)
    * [Features](#features-1)
      * [Constants for the returned result](#constants-for-the-returned-result)
      * [Request fields](#request-fields)
    * [Actions (including post)](#actions-including-post)
      * [Constants for the returned result](#constants-for-the-returned-result-1)
    * [Request fields](#request-fields-1)
<!-- TOC -->

## Authentication workflow

An incoming authentication request first enters the **brute\_force** check. After that it continues with the **features** 
pipeline. After that has past, it continues to process the request in a **password backend**. When the final result for the 
request was obtained, it passes **filters**. 

Filters may change the backend result in one or the other way (accepting a formely rejected message or vice versa). This 
is especially useful for other remote services that can influence the authentication process. 

After all this has finished, it is possible to do some **post actions**, which are run independent 
from all other steps in the whole pipeline and therefor can not influence the final result anymore. 

In the following sequence diagram you can see the processing of the request in more detail.

```mermaid
sequenceDiagram
    actor User
    participant Request
    participant Brute force check
    participant Features
    participant Actions
    participant Backend
    participant Filters
    participant Finished
    User->>Request: Wants to authenticate
    activate Request
    Note over Request,Filters:A Lua context is created: All scripts can manipulate this context with set, get and delete operations.  
    Request->>Brute force check:Does user triger a brute froce rule?
    activate Brute force check
    alt Brute force attack detected
    activate Actions
    Brute force check->>Actions:Do some actions
    loop Action pipeline
    Actions->>Actions: Run all action one after another
    end
    Actions->>Finished:Request was rejected
    deactivate Actions
    else No brute force attack detected
    Brute force check->>Features:Request continues
    deactivate Brute force check
    end
    activate Features
    loop Features pipeline
    Features->>Features:Run all features one after another
    end
    alt Some featured was triggered
    activate Actions
    Features->>Actions:Do some actions
    loop Action pipeline
      Actions->>Actions:Run all action one after another
    end
    Actions->>Finished:Request was rejected
    deactivate Actions
    else No featured triggered
    Features->>Backend:Do the main authentication process
    deactivate Features
    end
    activate Backend
    Backend->>Filters:Give pre-result to the filters
    deactivate Backend
    activate Filters
    Filters->>Finished:The result is accept or reject 
    Filters-->>Actions:Post actions run in background, while the request was already processed
    deactivate Filters
    deactivate Request
    activate Actions
    loop Post action pipeline
    Actions->>Actions:Run all action one after another
    end
    deactivate Actions
```
## Additional things to know

When an incoming authentication request is started, a Lua context is created.

All parts of a request share that common request context. Lua scripts can set arbitrary data in the context and read/delete
things from there. 

Lua scripts can modify the final log line by adding key-value pairs from each script.

## Configuration

For the configuration please have a look for the [configuration file](configuration-file.md) document.

## Lua components

Each component does provide a set of global functions, constants, ... and requires a well defined response from each request.

Every Lua script that has been configured, is pre-compiled and kept in memory for future use. To make script changes, you
must reload the service.

### Actions

Whenever a brute froce attack is recognized, **action**s may be called. The request will wait until all requests have 
finished. Actions are processed by a central action worker. No results are returned to the regular request, so actions
in general do there own logging!

Also **features** may call actions, if they were triggered. The request is waiting to finish all actions by the worker 
process.

### Features

Besides the well known features geoip, rbl, tls\_encryption and relay\_domains, a new feature has been integrated: lua. This
feature is processed before all other features (in fact, you might replace all these features with pure Lua...). Lua
features are run one after another. As soon as a feature has triggered, the request will reject the authentication process.
Furthermore, Lua features can set a flag to bypass all built-in features.

### Lua backend

A new backend has been implemented. It can be used for all features that Nauthilus currently supports: Checking passwords,
running different modes (no-auth, list-accounts), adding TOTP...

The backend can accept a request or reject it. It has full access to all meta information that are delivered from the
incoming request.

### Filters

There may exist remote services that may be contacted after the main backend authentication proccess returned its first  
result. Think of something like GeoIP service or some IP white/blacklisting. Even a request that might had authenticated
correctly may be rejected to a policy violation from such a service. Therefor filters have the power to override the
result from a backend.

:::info
Filters never affect caching! This is important, because otherwise valid credentials might result in storing them in the
negative password cache or vice versa for invalid credentials.
:::

### Post actions

Post actions are actions, which run after the request hast come to its final result. Its main purpose is to start some
automated things like doing statistics stuff, sending messages to operators or anything else that does not require fast
instant processing.

As an example have a look at the telegram script. Lua scripts in earlier stages of the process may provide some 
information by using the Lua context. The telegram script may pick up these information and decide to send out some 
notifications to an operator channel.

## Required functions and constants

Every Lua script must provide a pre-defined Lua function with a request parameter. Concerning the actual script, there is
a requried return statement.

Nauthilus will look for these functions and parses the results.

### Features

A Lua feature script must provide the following function:

```lua
function nauthilus_call_feature(request)
    return trigger, skip_flag, failure_info -- See details below
end
```

:::important
It must return three values: The trigger state, a flag that indicates, if other features shall be skipped and a third value
which is an indicator for errors that occurred in the script itself.
:::

#### Constants for the returned result

| Constant                        | Meaning                                                         | Value | Category      |
|---------------------------------|-----------------------------------------------------------------|-------|---------------|
| nauthilus.FEATURE\_TRIGGER\_NO  | The feature has not been triggered                              | 0     | trigger       |
| nauthilus.FEATURE\_TRIGGER\_YES | The feature has been triggered and the request must be rejected | 1     | trigger       |
| nauthilus.FEATURES\_ABORT\_NO   | Process other built-in features                                 | 0     | skip\_flag    |
| nauthilus.FEATURES\_ABORT\_YES  | After finishing the script, skip all other built-in features    | 1     | skip\_flag    |
| nauthilus.FEATURE\_RESULT\_OK   | The script finished without errors                              | 0     | failure\_info |
| nauthilus.FEATURE\_RESULT\_FAIL | Something went wrong while executing the script                 | 1     | failure\_info |

#### Request fields

The following request fields are supported

| Name                     | Type   | Precense | Additional info             |
|--------------------------|--------|----------|-----------------------------|
| debug                    | bool   | always   | -                           |
| session                  | string | always   | -                           |
| client\_ip               | string | always   | -                           |
| client\_port             | string | always   | -                           |
| username                 | string | always   | -                           |
| password                 | string | always   | -                           |
| protocol                 | string | always   | -                           |
| client\_id               | string | maybe    | -                           |
| local\_ip                | string | always   | -                           |
| local\_port              | string | always   | -                           |
| user\_agent              | string | maybe    | -                           |
| ssl                      | string | maybe    | %[ssl\_fc]                  |
| ssl\_session\_id         | string | maybe    | %[ssl\_fc\_session\_id,hex] |
| ssl\_client\_verify      | string | maybe    | %[ssl\_c\_verify]           |
| ssl\_client\_dn          | string | maybe    | %\{+Q\}[ssl\_c\_s\_dn]      |
| ssl\_client\_cn          | string | maybe    | %\{+Q\}[ssl\_c\_s\_dn(cn)]  |
| ssl\_issuer              | string | maybe    | %\{+Q\}[ssl\_c\_i\_dn]      |
| ssl\_client\_not\_before | string | maybe    | %\{+Q\}[ssl\_c\_notbefore]  |
| ssl\_client\_not\_after  | string | maybe    | %\{+Q\}[ssl\_c\_notafter]   |
| ssl\_subject\_dn         | string | maybe    | %\{+Q\}[ssl\_c\_s\_dn]      |
| ssl\_issuer\_dn          | string | maybe    | %\{+Q\}[ssl\_c\_i\_dn]      |
| ssl\_client\_subject\_dn | string | maybe    | %\{+Q\}[ssl\_c\_s\_dn]      |
| ssl\_client\_issuer\_dn  | string | maybe    | %\{+Q\}[ssl\_c\_i\_dn]      |
| ssl\_protocol            | string | maybe    | %[ssl\_fc\_protocol]        |
| ssl\_cipher              | string | maybe    | %[ssl\_fc\_cipher]          |

It is always a good idea to check the value of a request field, before trusting it.

### Actions (including post)

A Lua action script must provide the following function:

```lua
function nauthilus_call_action(request)
    return action_result -- See details below
end
```

:::important
Actions must return the script status constant.
:::

#### Constants for the returned result

| Constant                       | Meaning                            | Value | Category       |
|--------------------------------|------------------------------------|-------|----------------|
| nauthilus.ACTION\_RESULT\_OK   | The script finished without errors | 0     | action\_result |
| nauthilus.ACTION\_RESULT\_FAIL | The script finished with errors    | 1     | action\_result |

### Request fields

The following request fields are supported

| Name                  | Type   | Precense | Additional info                                       |
|-----------------------|--------|----------|-------------------------------------------------------|
| debug                 | bool   | always   | -                                                     |
| repeating             | bool   | maybe    | Brute force flag to indicate a repeating attack       |
| user\_found           | bool   | maybe    | Post actions                                          |
| authenticated         | bool   | maybe    | Post actions                                          |
| no\_auth              | bool   | always   | -                                                     |
| brute\_force\_counter | uint   | maybe    | Bucket counter for a triggered brute froce rule       |
| session               | string | always   | -                                                     |
| client\_ip            | string | always   | -                                                     |
| client\_port          | string | always   | -                                                     |
| client\_net           | string | maybe    | IP network for a triggered brute force rule           |
| client\_hostname      | string | maybe    | May exist, if DNS resolver option is turned on        |
| client\_id            | string | maybe    | -                                                     |
| local\_ip             | string | always   | -                                                     |
| local\_port           | string | always   | -                                                     |
| username              | string | always   | -                                                     |
| account               | string | maybe    | Post actions and if no master user was used           |
| unique\_user\_id      | string | maybe    | Post actions with OIDC                                |
| display\_name         | string | maybe    | Post actions with OIDC                                |
| password              | string | always   | -                                                     |
| protocol              | string | always   | -                                                     |
| brute\_force\_name    | string | maybe    | The name of a brute force bucket that matched         |
| feature\_name         | string | maybe    | If a feature triggered, this value is set to its name |

### Lua Backend

The Lua backend script must provide the following function:

```lua
function nauthilus_backend_verify_password(request)
  return backend_result, backend_result_object -- See details below
end
```

:::important
The backend must return the result status constant and a backend result object
:::

#### Constants for the returned result

| Constant                        | Meaning                            | Value | Category        |
|---------------------------------|------------------------------------|-------|-----------------|
| nauthilus.BACKEND\_RESULT\_OK   | The script finished without errors | 0     | backend\_result |
| nauthilus.BACKEND\_RESULT\_FAIL | The script finished with errors    | 1     | backend\_result |

### Request fields

The following request fields are supported

| Name                     | Type   | Precense | Additional info                                                |
|--------------------------|--------|----------|----------------------------------------------------------------|
| debug                    | bool   | always   | -                                                              |
| no\_auth                 | bool   | always   | -                                                              |
| session                  | string | always   | -                                                              |
| client\_ip               | string | always   | -                                                              |
| client\_port             | string | always   | -                                                              |
| username                 | string | always   | -                                                              |
| password                 | string | always   | -                                                              |
| protocol                 | string | always   | -                                                              |
| client\_id               | string | maybe    | -                                                              |
| local\_ip                | string | always   | -                                                              |
| local\_port              | string | always   | -                                                              |
| user\_agent              | string | maybe    | -                                                              |
| service                  | string | always   | Part of the HTTP request uri: /api/v1/\<category\>/\<service\> |
| protocol                 | string | always   | Value from the HTTP request **Auth-Protocol** header           | 
| ssl                      | string | maybe    | %[ssl\_fc]                                                     |
| ssl\_session\_id         | string | maybe    | %[ssl\_fc\_session\_id,hex]                                    |
| ssl\_client\_verify      | string | maybe    | %[ssl\_c\_verify]                                              |
| ssl\_client\_dn          | string | maybe    | %\{+Q\}[ssl\_c\_s\_dn]                                         |
| ssl\_client\_cn          | string | maybe    | %\{+Q\}[ssl\_c\_s\_dn(cn)]                                     |
| ssl\_issuer              | string | maybe    | %\{+Q\}[ssl\_c\_i\_dn]                                         |
| ssl\_client\_not\_before | string | maybe    | %\{+Q\}[ssl\_c\_notbefore]                                     |
| ssl\_client\_not\_after  | string | maybe    | %\{+Q\}[ssl\_c\_notafter]                                      |
| ssl\_subject\_dn         | string | maybe    | %\{+Q\}[ssl\_c\_s\_dn]                                         |
| ssl\_issuer\_dn          | string | maybe    | %\{+Q\}[ssl\_c\_i\_dn]                                         |
| ssl\_client\_subject\_dn | string | maybe    | %\{+Q\}[ssl\_c\_s\_dn]                                         |
| ssl\_client\_issuer\_dn  | string | maybe    | %\{+Q\}[ssl\_c\_i\_dn]                                         |
| ssl\_protocol            | string | maybe    | %[ssl\_fc\_protocol]                                           |
| ssl\_cipher              | string | maybe    | %[ssl\_fc\_cipher]                                             |

WIP...