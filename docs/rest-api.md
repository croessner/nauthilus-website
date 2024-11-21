---
title: REST API
description: Nauthilus REST API
keywords: [REST, API]
sidebar_position: 7
---
<!-- TOC -->
  * [Backend channel](#backend-channel)
    * [Protocol endpoints](#protocol-endpoints)
      * [Protocol specific endpoints](#protocol-specific-endpoints)
    * [REST calls](#rest-calls)
  * [Frontend channel](#frontend-channel)
    * [HTTP basic authorization](#http-basic-authorization-)
    * [OAuth-2.0 OpenID-Connect](#oauth-20-openid-connect)
    * [Manage two-factor authentication requests](#manage-two-factor-authentication-requests)
    * [Other endpoints](#other-endpoints)
  * [Normal user authentication](#normal-user-authentication)
  * [Flush a user from Redis cache](#flush-a-user-from-redis-cache)
  * [Flush an IP address from Redis cache](#flush-an-ip-address-from-redis-cache)
  * [Get a list with all known IP addresses that have been blocked](#get-a-list-with-all-known-ip-addresses-that-have-been-blocked)
  * [Mode no-auth](#mode-no-auth)
  * [Mode list-accounts](#mode-list-accounts)
  * [Nginx](#nginx)
  * [saslauthd with http backend](#saslauthd-with-http-backend)
      * [/etc/saslauthd.conf](#etcsaslauthdconf)
      * [Running saslauthd](#running-saslauthd)
  * [JSON query endpoint](#json-query-endpoint)
<!-- TOC -->

The following is a set of tests which are used for developing. You can use them for your own set of tests.

## Backend channel

**Important!**: Make sure to hide the following endpoints to the public internet:

### Protocol endpoints

* /api/v1/auth/json<br/>A general purpose endpoint using JSON
* /api/v1/auth/header<br/>Designed to be used with any service that can deal with HTTP request and response headers

#### Protocol specific endpoints

* /api/v1/auth/nginx<br/>Designed to be used with Nginx
* /api/v1/auth/saslauthd<br/>Designed to be used with cyrus-saslauthd and its httpform backend.

### REST calls

* /api/v1/cache/flush
* /api/v1/bruteforce/flush

## Frontend channel

### HTTP basic authorization 

**Important!**: Please open this only if you really need it! It lacks the capability for two-factor authentication

* /api/v1/auth/basic

### OAuth-2.0 OpenID-Connect

The following endpoints may be open for public access:

* /login
* /login/post
* /consent
* /consent/post
* /logout
* /logout/post

### Manage two-factor authentication requests

The following endpoints may be open for public access:

* /2fa/v1/register

### Other endpoints

Nauthilus may call the notification page to display errors or other user information.

* /notify

A query parameter named **message** will be taken from the URL and displayed nicely in a template.

## Normal user authentication

```
POST http://127.0.0.1:8080/api/v1/auth/header
Accept: */*
Auth-Method: plain
Auth-User: testuser
Auth-Pass: testpassword
Auth-Protocol: imap
Auth-Login-Attempt: 0
Client-IP: 127.0.0.1
X-Client-Port: 12345
X-Client-Id: Test-Client
X-Local-IP: 127.0.80.80
X-Auth-Port: 143
Auth-SSL: success
Auth-SSL-Protocol: secured
###
```

Example output:

```
HTTP/1.1 200 OK
Auth-Status: OK
Auth-User: testaccount@example.test
X-Nauthilus-Session: 2HDQSPruG03RGBCtVuu52ZL18Ip
X-Nauthilus-Rnsmsdovecotfts: solr
X-Nauthilus-Rnsmsdovecotftssolrurl: url=http://127.0.0.1:8983/solr/dovecot
X-Nauthilus-Rnsmsmailpath: sdbox:~/sdbox
X-Nauthilus-Rnsmsoverquota: FALSE
X-Nauthilus-Rnsmsquota: 5242880
Date: Mon, 07 Nov 2022 10:32:54 GMT
Content-Length: 2
Content-Type: text/plain; charset=utf-8
OK
```

## Flush a user from Redis cache

```
DELETE http://127.0.0.1:8080/api/v1/cache/flush
Accept: */*
Content-Type: application/json

{"user": "testuser"}
###
```

Example output:

```
HTTP/1.1 200 OK
Content-Type: application/json
Date: Mon, 07 Nov 2022 10:47:31 GMT
Content-Length: 120

{
  "guid": "2HDSEmkavbN4Ih3K89gBBPAGwPy",
  "object": "cache",
  "operation": "flush",
  "result": {
    "user": "testuser",
    "status": "flushed"
  }
}
```

> Note:
>
> If you specify '*' (without the single quotes) as the **user** argument, then all users are flushed from the caches.

## Flush an IP address from a brute force bucket

```
DELETE http://127.0.0.1:8080/api/v1/bruteforce/flush
Accept: */*
Content-Type: application/json

{"ip_address": "x.x.x.x", "rule_name":  "testrule"}
###
```

Example output:

```
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Date: Wed, 22 Mar 2023 12:36:33 GMT
Content-Length: 144

{
  "guid": "2NMzAHKLwpSk6d20cJ4Zqj6hEAB",
  "object": "bruteforce",
  "operation": "flush",
  "result": {
    "ip_address": "x.x.x.x",
    "rule_name": "testrule",
    "status": "flushed"
  }
}
```

> Note:
>
> If you specify '*' (without the single quotes) as the **rule_name** argument, then all buckets an IP belongs to are
> flushed from the caches.

## Get a list with all known IP addresses that have been blocked

```
DELETE http://127.0.0.1:8080/api/v1/bruteforce/list
Accept: */*

###
```

Example output:

```
TTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Date: Mon, 27 Mar 2023 09:05:22 GMT
Content-Length: 123

{
  "guid": "2Nah6CvEP1ZK46u6M1GBl8ZuH01",
  "object": "bruteforce",
  "operation": "list",
  "result": {
    "ip_addresses": "ip_addresses": {
      "2a05:bec0:abcd:1::4711": "ua_1d_ipv6"
    },
    "error": "none"
  }
}
```

## Mode no-auth

```
POST http://127.0.0.1:8080/api/v1/auth/header?mode=no-auth
Accept: */*
Auth-Method: plain
Auth-User: testuser
Auth-Protocol: imap
Auth-Login-Attempt: 0
Client-IP: 127.0.0.1
X-Client-Port: 12345
X-Client-Id: Test-Client
X-Local-IP: 127.0.80.80
X-Auth-Port: 143
Auth-SSL: success
Auth-SSL-Protocol: secured
###
```

Example output:

```
HTTP/1.1 200 OK
Auth-Status: OK
Auth-User: testaccount@example.test
X-Nauthilus-Session: 2HDSiJqz9MrisZmLAt6iiobOuLQ
X-Nauthilus-Rnsmsdovecotfts: solr
X-Nauthilus-Rnsmsdovecotftssolrurl: url=http://127.0.0.1:8983/solr/dovecot
X-Nauthilus-Rnsmsmailpath: sdbox:~/sdbox
X-Nauthilus-Rnsmsoverquota: FALSE
X-Nauthilus-Rnsmsquota: 5242880
Date: Mon, 07 Nov 2022 10:51:26 GMT
Content-Length: 2
Content-Type: text/plain; charset=utf-8

OK
```

## Mode list-accounts

```
GET http://127.0.0.1:8080/api/v1/auth/header?mode=list-accounts
Accept: */*
###
```

The result is a list with all accounts - line by line. If you use "application/json" for **Accept**, the result will be a 
JSON list. If you speficy "application/x-www-form-urlencoded", the service returns a byte array with all accounts.

## Nginx

```
POST http://127.0.0.1:8080/api/v1/auth/nginx
Accept: */*
Auth-Method: plain
Auth-User: testuser
Auth-Pass: testpassword
Auth-Protocol: imap
Auth-Login-Attempt: 0
Client-IP: 127.0.0.1
X-Auth-Port: 143
Auth-SSL: success
Auth-SSL-Protocol: secured
###
```

Example output:

```
HTTP/1.1 200 OK
Auth-Port: 9931
Auth-Server: 127.0.0.1
Auth-Status: OK
Auth-User: testaccount@example.test
X-Nauthilus-Session: 2HDTGUWG6hNRLfHwafEzDkaZLEC
Date: Mon, 07 Nov 2022 10:55:58 GMT
Content-Length: 2
Content-Type: text/plain; charset=utf-8

OK
```

## saslauthd with http backend

To use this mode, you need to install saslauthd and configure it to use to http backend:

#### /etc/saslauthd.conf

```
httpform_host: 127.0.0.1
httpform_port: 9080
httpform_uri: /api/v1/auth/saslauthd
httpform_data: protocol=submission&port=587&method=plain&tls=success&security=starttls&user_agent=saslauthd/2.1.27&username=%u&realm=%r&password=%p
```

#### Running saslauthd

```
/usr/sbin/saslauthd -m /run/saslauthd -a httpform
```

Using this service prevents nauthilus from finding out the real remote client address. Consider using Dovecot with the
submission proxy service.

```
POST http://127.0.0.1:8080/api/v1/auth/saslauthd
Accept: */*
Content-Type: application/x-www-form-urlencoded

protocol=submission&port=587&method=plain&tls=success&security=starttls&user_agent=Test-Client&username=testuser&realm=&password=testpassword
###
```

Example output:

```
HTTP/1.1 200 OK
Auth-Status: OK
Auth-User: testaccount@example.test
X-Nauthilus-Session: 2HDTeoN5dIpcNRvOZt2FNMIrTq3
Date: Mon, 07 Nov 2022 10:59:11 GMT
Content-Length: 2
Content-Type: text/plain; charset=utf-8

OK
```

## JSON query endpoint

```
POST http://127.0.0.1:8080/api/v1/auth/json
Content-Type: application/json
```
```json
{
  "username": "exampleUser",  // Required: The identifier of the client/user sending the request
  "password": "examplePass",  // Optional: The authentication credential of the client/user sending the request
  "client_ip": "192.168.1.1",  // Optional: The IP address of the client/user making the request
  "client_port": "8080",  // Optional: The port number from which the client/user is sending the request
  "client_hostname": "client.example.com",  // Optional: The hostname of the client which is sending the request
  "client_id": "client123",  // Optional: The unique identifier of the client/user, usually assigned by the application
  "local_ip": "10.0.0.1",  // Optional: The IP address of the server or endpoint receiving the request
  "local_port": "443",  // Optional: The port number of the server or endpoint receiving the request
  "service": "loginService",  // Required: The specific service that the client/user is trying to access with the request
  "method": "LOGIN",  // Optional: The HTTP method used in the request (e.g., PLAIN, LOGIN, etc.)
  "auth_login_attempt": 1,  // Optional: A flag indicating if the request is an attempt to authenticate (login)
  "ssl": "on",  // Optional: Identfier, if TLS is used. Any non-empty value activates the usage of TLS for the transport
  "ssl_session_id": "abc123",  // Optional: The session ID of the SSL/TLS handshake
  "ssl_client_verify": "SUCCESS",  // Optional: The result of the client certificate verification
  "ssl_client_dn": "CN=Client,C=US",  // Optional: The distinguished name of the client certificate
  "ssl_client_cn": "ClientCN",  // Optional: The common name in the client certificate
  "ssl_issuer": "IssuerOrg",  // Optional: The issuer of the SSL/TLS certificate
  "ssl_client_notbefore": "2023-01-01T00:00:00Z",  // Optional: The start date of the client certificate validity
  "ssl_client_notafter": "2023-12-31T23:59:59Z",  // Optional: The end date of the client certificate validity
  "ssl_subject_dn": "CN=Client,C=US",  // Optional: The subject distinguished name of the SSL/TLS certificate
  "ssl_issuer_dn": "CN=Issuer,C=US",  // Optional: The issuer distinguished name of the SSL/TLS certificate
  "ssl_client_subject_dn": "CN=Client,C=US",  // Optional: The subject distinguished name of the client certificate
  "ssl_client_issuer_dn": "CN=Issuer,C=US",  // Optional: The issuer distinguished name of the client certificate
  "ssl_protocol": "TLSv1.2",  // Optional: The protocol of the SSL/TLS connection
  "ssl_cipher": "ECDHE-RSA-AES256-GCM-SHA384",  // Optional: The cipher suite used in the SSL/TLS connection
  "ssl_serial": "0123456789ABCDEF",  // Optional: The serial number of the SSL/TLS certificate
  "ssl_fingerprint": "AA:BB:CC:DD:EE:FF"  // Optional: The fingerprint of the SSL/TLS certificate
}
```

Example output:

```
HTTP/1.1 200 OK
Auth-Status: OK
Auth-User: testaccount@example.test
Content-Type: application/json
X-Nauthilus-Session: 2MNJnKgGpgGJ5rRuFGcTltWefrO
Date: Tue, 28 Feb 2023 16:37:51 GMT
Content-Length: 656

{
  "AccountField": "entryUUID",
  "TOTPSecretField": "",
  "Password": "***HASHED***",
  "Backend": "ldapPassDB",
  "Attributes": {
    ...
  }
```
