---
title: Macros
description: Macro definitions for queries in Nauthilus
keywords: [Configuration, Macros, Queries]
sidebar_position: 3
---

# Macros

As LDAP queries have to deal with usernames or other information, it may be required to define several macros
inside the queries, which must be replaced by Nauthilus.

The main implementation is adopted from Dovecot, but only a subset of all possible macros is currently provided.

## Macro Form

The general form is as follows:

```
%Modifiers{long variables}
```

## Modifiers

Modifiers are optional. Currently, the following modifiers are known:

| Modifier | Meaning                         |
|:--------:|---------------------------------|
|    L     | Treat all characters lower case |
|    U     | Treat all characters upper case |
|    R     | Reverse a string                |
|    T     | Trim a string                   |

> Note:
>
> Do not combine **L** and **U** at the same time for one macro, as this causes unpredictable results!

## Long Variables

The following macro names are known and described in the following table:

| Variable name | Meaning                                                                                    |
|---------------|--------------------------------------------------------------------------------------------|
| user          | Full username, i.e. localpart@domain.tld                                                   |
| username      | The local part of \{user\}, if user has a domain part, else user and username are the same |
| domain        | The domain part of \{user\}. Empty string, if \{user\} did not contain a domain part       |
| service       | The service name, i.e. imap, pop3, lmtp                                                    |
| local\_ip     | Local IP address                                                                           |
| local\_port   | Local port                                                                                 |
| remote\_ip    | Remote client IP address                                                                   |
| remote\_port  | Remote client port                                                                         |
| totp\_secret  | This macros gets replaced when adding or removing a TOTP secret to a user account.         |

## Macro Example

Lower case form of a username (full email, if user string contains a '@' character).

```
%L{user}
```

## Usage in LDAP Filters

Macros are commonly used in LDAP filters to dynamically insert user information:

```yaml
ldap:
  search:
    - protocol: imap
      base_dn: ou=people,ou=it,dc=example,dc=com
      filter:
        user: |
          (&
            (objectClass=rnsMSDovecotAccount)
            (|
              (uniqueIdentifier=%L{user})
              (rnsMSRecipientAddress=%L{user})
            )
          )
```

In this example, `%L{user}` will be replaced with the lowercase version of the username provided during authentication.