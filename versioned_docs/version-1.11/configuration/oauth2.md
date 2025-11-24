---
title: OAuth2 Configuration
description: Configuration for OAuth2/OpenID Connect in Nauthilus
keywords: [Configuration, OAuth2, OpenID Connect]
sidebar_position: 10
---

# OAuth2 Configuration

Nauthilus currently supports Ory Hydra to deal as authentication backend for OAuth2/OpenID Connect.

There are two sections that define the behavior of Nauthilus when it comes to the point of building the ID token.

## Configuration Flow

The first step is to create a new Ory Hydra client for your application. Here is an example:

```shell
hydra create oauth2-client \
    --endpoint https://ORY-HYDRA-ADMIN:4445 \
    --format json \
    --name "Some name for your application" \
    --secret SomeSecretPasswordForYourClient \
    --grant-type authorization_code,refresh_token \
    --response-type token,code,id_token \
    --token-endpoint-auth-method client_secret_post \
    --scope openid,offline,profile,email,dovecot \
    --redirect-uri https://your-redirect-url-that-MUST-exactly-match \
    --policy-uri https://link-to-a-policy-website/ \
    --tos-uri https://link-to-a-terms-of-service-website/ \
    --client-uri https://link-to-a-page-that-describes-the-application/
```

Some of these parameters are optional like --policy-uri, --tos-uri and --client-uri, but if they were found, Nauthilus
will render them in the page templates.

Next step is to add a section to Nauthilus, where you tell the server what data from the authentication backends are used
to build the ID- and access token. The most important field is the **subject** field.

:::warning
Make sure to pick a subject that is realy unique to identify your user inside your company. Furthermore, make sure to
stay with the subject accross all your applications defined in Nauthilus, as it will for sure have unwanted behavior if
mixing it!
:::

Besides the subject, Nauthilus can send arbitrary data to Ory Hydra upon an accepted consent request that will be sent
out to the remote client as claims. You need to define a mapping in Nauthilus that maps the LDAP attributes to claim
names.

If a user was authenticated on the login page, the server will have LDAP results that will be taken with this
mapping. Therefor it is important to tell each backend, which data needs to be retrieved. Data will be cached on Redis.
If you modify applications and require more fields/results from the underlying backends, you must clear the Redis
objects or wait for an expiration.

The LDAP backend section will tell you more about this later on this page.

After you have refreshed Nauthilus, you can configure your web application, Dovecot or whatever with the new settings.

## About Scopes and Claims

Nauthilus is aware of the following built-in scopes:

* profile
* address
* email
* phone

The OpenID 1.0 core spec associates several claims to each of these scopes:

For the scope **profile**

* name
* given_name
* family_name
* middle_name
* nickname
* preferred_username
* website
* profile
* picture
* gender
* birthdate
* zoneinfo
* locale
* updated_at

For the scope **address**

* address

Nauthilus does return addresses only as **formatted** JSON onject.

For the scope **email**

* email
* email_verified

For the scope **phone**

* phone_number
* phone_number_verfied

Each of these claims can be mapped in the oauth2 section.

Nauthilus does also support a **groups** claim, which is a list of strings, each containing a group membership value.

## User Defined Scopes and Claims

If the default scopes and claims are not enough for your application, you can define your own sets yourself. This has
some current limitations! By defining claims, you must tell Nauthilus a type for each value. Currently supported types
include:

| Type    | Name    | Size | Example            |
|---------|---------|:----:|--------------------|
| String  | string  |  -   | custom_claim_foo   |
| Boolean | boolean |  -   | true / false       |
| Integer | integer |  64  | -45366473          |
| Float   | float   |  64  | 3.1415             |

Numers are signed. It may happen that the communication between Nauthilus and Ory Hydra will modify integers by using
their exponential form. This is a known issue and can not be fixed at the moment. If this happens, try using a string
instead and let the final application convert it into its representing value.

## Configuration Options

### oauth2::clients

This section defines your OAuth2 clients, containing a name, the client_id, the subject and the claim mapping.

```yaml
oauth2:
  clients:
    - name: Testing
      client_id: THIS-IS-THE-CLIENT-ID-FROM-ORY-HYDRA
      skip_consent: false
      skip_totp: false
      subject: entryUUID
      claims:
        name: cn
        given_name: givenName
        family_name: sn
        nickname: uniqueIdentifier
        preferred_username: uniqueIdentifier
        email: mail
```

Your LDAP backend does return results for attributes. The example is a mapping for OpenLDAP.

As you can see in the example, there is no need to deliver all possible claims. Which claims are required is dependent
to your consuming application.

:::note
Make sure to list claims for which you have defined the matching scopes! If you define an email mapping whithout the
matching scope, your user seeing the consent page will not be able to accept the scope and therefor the claim will not
be available!
:::

:::note
If you configure Nauthilus to deal with a service hosted at your companies site, you may want to skip the consent 
page. Do so by setting **skip_consent** to **true**.
:::

:::note
Some applications provide their own second factor implementation. If you want to prevent duplicated second factor
authentication, you can skip TOTP for a client, by adding **skip_totp** with a value of **true**.
:::

### oauth2::custom_scopes

This section allows you to define custom scopes and there claim definition as described earlier on this page. It lists
objects like the following:

```yaml
oauth2:
  custom_scopes:
    - name: dovecot
      description: Some description
      description_de: Optional German description
      description_fr: Optional French description
      claims:
        - name: dovecot_user
          type: string

        - name: dovecot_mailbox_home
          type: string

        - name: dovecot_mailbox_path
          type: string

        - name: dovecot_acl_groups
          type: string
```

:::note
Claims are not updated after first delivery! So do not send data that may change dynamically!
:::

The **description** field will be used in the consent.html template to give the user more information about this 
scope. You can add descriptions with an underscore followed by a lower case country code, do translate the 
description into other languages. The default is English and taken from the **description** key.

Supported languages:

* en
* de
* fr

## Example Configuration

```yaml
oauth2:
  custom_scopes:
    - name: dovecot
      description: Some description that will be seen on the consent page
      claims:
        - name: dovecot_user
          type: string

        - name: dovecot_mailbox_home
          type: string

        - name: dovecot_mailbox_path
          type: string

        - name: dovecot_acl_groups
          type: string

  clients:
    - name: Testing
      client_id: SOME-CLIENT-ID
      subject: entryUUID
      claims:
        name: cn
        given_name: givenName
        family_name: sn
        nickname: uniqueIdentifier
        preferred_username: uniqueIdentifier
        email: mail
        groups: organizationalStatus
        dovecot_user: rnsMSDovecotUser
        dovecot_mailbox_home: rnsMSMailboxHome
        dovecot_mailbox_path: rnsMSMailPath
        dovecot_acl_groups: rnsMSACLGroups
```