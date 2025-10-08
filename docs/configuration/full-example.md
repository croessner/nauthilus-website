---
title: Full Configuration Example
description: Complete configuration example for Nauthilus
keywords: [Configuration, Example, Full]
sidebar_position: 11
---

# Full Configuration Example

This page provides a complete example of a Nauthilus configuration file. You can use this as a reference when configuring your own Nauthilus instance.

```yaml
server:
  # Basic server settings
  address: "[::]:9443"                  # Default: "127.0.0.1:9080"
  max_concurrent_requests: 200          # Default: 100
  max_password_history_entries: 10      # Default: 0
  http3: true                           # Default: false
  haproxy_v2: false                     # Default: false
  instance_name: nauthilus_demo         # Default: "nauthilus"

  # Disabled endpoints
  disabled_endpoints:
    auth_header: false                  # Default: false
    auth_json: false                    # Default: false
    auth_basic: false                   # Default: false
    auth_nginx: false                   # Default: false
    auth_saslauthd: false               # Default: false
    auth_jwt: false                     # Default: false
    custom_hooks: false                 # Default: false
    configuration: false                # Default: false (New in v1.7.11) 

  # TLS configuration
  tls:
    enabled: true                       # Default: false
    cert: /usr/local/etc/nauthilus/localhost.localdomain.pem
    key: /usr/local/etc/nauthilus/localhost.localdomain.key.pem
    ca_file: /usr/local/etc/nauthilus/ca.pem  # Default: "" (New in v1.7.11)
    min_tls_version: "TLS1.3"           # Default: "TLS1.2" (New in v1.7.11)
    skip_verify: false                  # Default: false (New in v1.7.11)
    http_client_skip_verify: true       # Default: false (Deprecated, use skip_verify instead)
    cipher_suites:                      # Default: [] (New in v1.7.11)
      - "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
      - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
      - "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"

  # HTTP client configuration
  http_client:
    max_connections_per_host: 10        # Default: 0 (no limit)
    max_idle_connections: 5             # Default: 0 (no limit)
    max_idle_connections_per_host: 1    # Default: 0 (no limit)
    idle_connection_timeout: 60s        # Default: 0 (no timeout)
    proxy: "http://proxy.example.com:8080" # Default: "" (New in v1.7.11)
    # TLS configuration for HTTP client
    tls:                                # New in v1.7.11
      skip_verify: false                # Default: false

  # Basic authentication
  basic_auth:
    enabled: true                       # Default: false
    username: nauthilus
    password: nauthilus

  # JWT authentication
  jwt_auth:
    enabled: true                       # Default: false
    secret_key: "your-secret-key-at-least-32-characters"
    token_expiry: 2h                    # Default: 1h
    refresh_token: true                 # Default: false
    refresh_token_expiry: 48h           # Default: 24h
    store_in_redis: true                # Default: false
    users:
      - username: admin
        password: "secure-password"
        roles:
          - admin
          - authenticated
      - username: user
        password: "another-secure-password"
        roles:
          - user
          - authenticated

  # Logging configuration
  log:
    json: false                         # Default: false
    color: true                         # Default: false
    level: debug                        # Default: "none"
    debug_modules:
      - auth
      - lua
      - feature
      - ldap
      - brute_force
      - rbl

  # Backend configuration
  backends:
    - cache
    - lua
    - ldap
    - ldap(pool1)
    - lua(backend1)

  # Features configuration
  features:
    - lua
    - tls_encryption
    - relay_domains
    - rbl
    - backend_server_monitoring

  # Brute force protocols
  brute_force_protocols:
    - imap
    - imaps
    - submission
    - smtp
    - smtps
    - ory-hydra
    - http

  # Ory Hydra configuration
  ory_hydra_admin_url: https://hydra.example.com:4445  # Default: "http://127.0.0.1:4445"

  # DNS configuration
  dns:
    resolver: 192.168.1.1               # Default: ""
    timeout: 3                          # Default: 5
    resolve_client_ip: false            # Default: false

  # Insights configuration
  insights:
    enable_pprof: true                  # Default: false
    enable_block_profile: true          # Default: false
    monitor_connections: true           # Default: false

  # Redis configuration
  redis:
    database_number: 2                  # Default: 0
    prefix: nt_                         # Default: ""
    password_nonce: "random-nonce-string" # Default: ""
    pool_size: 10                       # Default: 0
    idle_pool_size: 2                   # Default: 0
    positive_cache_ttl: 3600s           # Default: 3600s
    negative_cache_ttl: 7200s           # Default: 3600s

    # TLS configuration for Redis
    tls:                                # New in v1.7.11
      enabled: true                     # Default: false
      cert: /path/to/redis/cert.pem
      key: /path/to/redis/key.pem
      skip_verify: false                # Default: false

    # Master configuration
    master:
      address: 127.0.0.1:6379           # Default: "127.0.0.1:6379"
      username: redis_user              # Default: ""
      password: redis_password          # Default: ""

    # Replica configuration
    replica:
      addresses:
        - 10.10.10.10:6379
        - 10.10.10.11:6379

    # Sentinel configuration
    sentinels:
      master: mymaster
      addresses:
        - 127.0.0.1:26379
        - 127.0.0.1:26378
        - 127.0.0.1:26377
      username: sentinel_user           # Default: ""
      password: sentinel_password       # Default: ""

    # Cluster configuration
    cluster:
      addresses:
        - 127.0.0.1:6379
        - 127.0.0.1:6378
        - 127.0.0.1:6377
      username: cluster_user            # Default: ""
      password: cluster_password        # Default: ""
      route_by_latency: true            # Default: false
      route_randomly: true              # Default: false
      route_reads_to_replicas: true     # Default: false (New in v1.7.11)
      # read_only: true                 # Deprecated: Use route_reads_to_replicas instead
      max_redirects: 5                  # Default: 3
      read_timeout: 3s                  # Default: 0 (no timeout)
      write_timeout: 3s                 # Default: 0 (no timeout)

  # Master user configuration
  master_user:
    enabled: true                       # Default: false
    delimiter: "*"                      # Default: "*"

  # Frontend configuration
  frontend:
    enabled: true                       # Default: false
    csrf_secret: 32-byte-long-random-secret
    cookie_store_auth_key: 32-byte-long-random-secret
    cookie_store_encryption_key: 16-24-or-32-byte-long-random-secret

  # Deduplication configuration
  dedup:
    distributed_enabled: false         # Default: false. Enable Redis-based cross-instance dedup for backchannel auth (v1.9.12)

  # Prometheus timer configuration
  prometheus_timer:
    enabled: true                       # Default: false
    labels:
      - request
      - dns
      - backend
      - brute_force
      - feature
      - filter
      - action
      - post_action
      - account
      - store_totp

  # Compression configuration
  compression:
    enabled: true                       # Default: false
    level_gzip: 7                       # Default (gzip): 5; 'level' is deprecated since v1.9.9
    algorithms: ["br", "zstd", "gzip"]  # Order = preference
    level_zstd: 2                       # 0=Default,1=BestSpeed,2=BetterCompression,3=BestCompression
    level_brotli: 2                     # 0=Default,1=BestSpeed,2=BetterCompression,3=BestCompression (since v1.9.9)
    # content_types:                    # Deprecated since v1.9.2: no longer used, safe to remove
    #   - text/html
    #   - application/json
    min_length: 2048                    # Default: 1024

  # Keep alive configuration
  keep_alive:
    enabled: true                       # Default: false
    timeout: 60s                        # Default: 30s
    max_idle_connections: 200           # Default: 100
    max_idle_connections_per_host: 20   # Default: 10

  # Default HTTP request header
  default_http_request_header:
    username: "X-Auth-Username"
    password: "X-Auth-Password"
    password_encoded: "X-Auth-Password-Encoded"
    protocol: "X-Auth-Protocol"
    login_attempt: "X-Auth-Login-Attempt"
    auth_method: "X-Auth-Method"
    local_ip: "X-Auth-Local-IP"
    local_port: "X-Auth-Local-Port"
    client_ip: "X-Auth-Client-IP"
    client_port: "X-Auth-Client-Port"
    client_host: "X-Auth-Client-Host"
    client_id: "X-Auth-Client-ID"
    ssl: "X-Auth-SSL"
    ssl_session_id: "X-Auth-SSL-Session-ID"
    ssl_verify: "X-Auth-SSL-Verify"
    ssl_subject: "X-Auth-SSL-Subject"
    ssl_client_cn: "X-Auth-SSL-Client-CN"
    ssl_issuer: "X-Auth-SSL-Issuer"
    ssl_client_not_before: "X-Auth-SSL-Client-Not-Before"
    ssl_client_not_after: "X-Auth-SSL-Client-Not-After"
    ssl_subject_dn: "X-Auth-SSL-Subject-DN"
    ssl_issuer_dn: "X-Auth-SSL-Issuer-DN"
    ssl_client_subject_dn: "X-Auth-SSL-Client-Subject-DN"
    ssl_client_issuer_dn: "X-Auth-SSL-Client-Issuer-DN"
    ssl_cipher: "X-Auth-SSL-Cipher"
    ssl_protocol: "X-Auth-SSL-Protocol"
    ssl_serial: "X-Auth-SSL-Serial"
    ssl_fingerprint: "X-Auth-SSL-Fingerprint"
    oidc_cid: "X-OIDC-CID"

realtime_blackhole_lists:
  # Threshold for RBL checks
  threshold: 10                         # Default: 0

  # RBL lists configuration
  lists:
    - name: SpamRats AuthBL             # Required
      rbl: auth.spamrats.com            # Required
      ipv4: true                        # Default: false
      ipv6: true                        # Default: false
      return_code: 127.0.0.43           # Required
      weight: 10                        # Required
      allow_failure: false              # Default: false

    - name: AbusiX AuthBL
      rbl: YOUR-API-KEY.authbl.mail.abusix.zone
      ipv4: true
      ipv6: true
      return_code: 127.0.0.4
      weight: 10
      allow_failure: true

  # IP whitelist for RBL checks
  ip_whitelist:                         # Default: empty list
    - 127.0.0.0/8
    - ::1
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
    - fd00::/8
    - 169.254.0.0/16
    - fe80::/10

cleartext_networks:                      # Default: empty list
  - 127.0.0.0/8
  - ::1
  - 192.168.0.200
  - 172.16.0.0/12

relay_domains:
  static:                               # Default: empty list
    - domain1.tld
    - domain2.tld
    - domain3.tld

brute_force:
  # IP whitelist for brute force protection
  ip_whitelist:                         # Default: empty list
    - 127.0.0.0/8
    - ::1
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/8
    - fd00::/8
    - 169.254.0.0/16
    - fe80::/10

  # Learning configuration
  learning:                             # Default: empty list
    - realtime_blackhole_lists
    - lua

  # Toleration settings
  tolerate_percent: 20                  # Default: 0
  tolerate_ttl: 48h                     # Default: 24h

  # Adaptive toleration settings (v1.7.7)
  adaptive_toleration: true             # Default: false
  min_tolerate_percent: 10              # Default: 10
  max_tolerate_percent: 50              # Default: 50
  scale_factor: 1.0                     # Default: 1.0

  # Custom tolerations
  custom_tolerations:                   # Default: empty list
    - ip_address: 192.168.1.0/24
      tolerate_percent: 30
      tolerate_ttl: 72h
      # Per-IP adaptive toleration settings (v1.7.7)
      adaptive_toleration: true
      min_tolerate_percent: 15
      max_tolerate_percent: 60
      scale_factor: 1.2
    - ip_address: 10.0.0.5
      tolerate_percent: 50
      tolerate_ttl: 24h
      # Explicitly disable adaptive toleration for this IP
      adaptive_toleration: false

  # Reduce PW_HIST writes for already‑blocked requests (v1.9.4)
  pw_history_for_known_accounts: true   # Default: false

  # IPv6 ip_scoping for RWP and Tolerations (v1.9.4)
  ip_scoping:
    rwp_ipv6_cidr: 64                   # Default: 0 (disabled)
    tolerations_ipv6_cidr: 64           # Default: 0 (disabled)

  # Cold-start grace for known accounts without negative PW history (v1.9.10)
  cold_start_grace_enabled: true        # Default: false
  cold_start_grace_ttl: 120s            # Default: 120s

  # Repeating-wrong-password allowance (tolerate up to N unique wrong password hashes within a window) (v1.9.12)
  rwp_allowed_unique_hashes: 5          # Default: 3
  rwp_window: 30m                       # Default: 15m

  # Neural network configuration
  neural_network:
    max_training_records: 20000         # Default: 10000
    hidden_neurons: 12                  # Default: 10
    activation_function: "tanh"         # Default: "sigmoid"
    static_weight: 0.5                  # Default: 0.4
    ml_weight: 0.5                      # Default: 0.6
    threshold: 0.8                      # Default: 0.7
    learning_rate: 0.005                # Default: 0.01

  # Brute force buckets
  buckets:                              # Default: empty list
    - name: b_1min_ipv4_32              # Required
      period: 60                        # Required
      cidr: 32                          # Required
      ipv4: true                        # Default: false
      failed_requests: 10               # Required

    - name: b_1min_ipv6_128
      period: 60
      cidr: 128
      ipv6: true
      failed_requests: 10

    - name: b_1h_ipv4_24
      period: 3600
      cidr: 24
      ipv4: true
      failed_requests: 15

    - name: b_1h_ipv6_64
      period: 3600
      cidr: 64
      ipv6: true
      failed_requests: 15

    - name: b_1d_ipv4_24
      period: 86400
      cidr: 24
      ipv4: true
      failed_requests: 25

    - name: b_1d_ipv6_64
      period: 86400
      cidr: 64
      ipv6: true
      failed_requests: 25

    - name: b_1w_ipv4_24
      period: 604800
      cidr: 24
      ipv4: true
      failed_requests: 40

    - name: b_1w_ipv6_64
      period: 604800
      cidr: 64
      ipv6: true
      failed_requests: 40

    # Example of a protocol-specific bucket (available from version 1.7.5)
    - name: b_1h_imap_ipv4_24
      period: 3600
      cidr: 24
      ipv4: true
      failed_requests: 5
      filter_by_protocol:
        - imap
        - imaps

    # Example of an OIDC Client ID-specific bucket (available from version 1.7.5)
    - name: b_1h_oidc_client_ipv4_24
      period: 3600
      cidr: 24
      ipv4: true
      failed_requests: 3
      filter_by_oidc_cid:
        - my-oidc-client-id
        - another-client-id

oauth2:
  # Custom scopes configuration
  custom_scopes:                        # Default: empty list
    - name: dovecot                     # Required
      description: Some description that will be seen on the consent page  # Required
      description_de: "Deutsche Beschreibung"  # Optional
      description_fr: "Description française"  # Optional
      claims:                           # Required
        - name: dovecot_user            # Required
          type: string                  # Required (string, boolean, integer, float)

        - name: dovecot_mailbox_home
          type: string

        - name: dovecot_mailbox_path
          type: string

        - name: dovecot_acl_groups
          type: string

  # OAuth2 clients configuration
  clients:                              # Default: empty list
    - name: Testing                     # Required
      client_id: SOME-CLIENT-ID         # Required
      skip_consent: false               # Default: false
      skip_totp: false                  # Default: false
      subject: entryUUID                # Required
      claims:                           # Required
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


# LDAP configuration
ldap:
  # Main LDAP configuration
  config:
    number_of_workers: 10               # Default: 10
    lookup_pool_size: 8                 # Default: 10
    lookup_idle_pool_size: 2            # Default: 2
    auth_pool_size: 8                   # Default: 10
    auth_idle_pool_size: 2              # Default: 2
    connect_abort_timeout: 10s          # Default: 10s

    server_uri: ldap://some.server:389/ # Required
    bind_dn: cn=admin,dc=example,dc=com # Optional
    bind_pw: secret                     # Optional
    starttls: true                      # Default: false
    tls_skip_verify: true               # Default: false
    sasl_external: true                 # Default: false
    pool_only: false                    # Default: false

    # Required if sasl_external is true
    tls_ca_cert: /path/to/cacert.pem
    tls_client_cert: /path/to/client/cert.pem
    tls_client_key: /path/to/client/key.pem

  # Optional LDAP pools
  optional_ldap_pools:
    pool1:
      lookup_pool_size: 5
      lookup_idle_pool_size: 1
      auth_pool_size: 5
      auth_idle_pool_size: 1
      server_uri: ldap://ldap1.example.com:389/
      starttls: true
      tls_skip_verify: false
    pool2:
      lookup_pool_size: 3
      lookup_idle_pool_size: 1
      auth_pool_size: 3
      auth_idle_pool_size: 1
      server_uri: ldap://ldap2.example.com:389/
      starttls: true
      tls_skip_verify: false

  # LDAP search configurations
  search:
    - protocol: http                    # Required
      cache_name: http                  # Optional
      pool_name: pool1                  # Optional
      base_dn: ou=people,ou=it,dc=example,dc=com  # Required
      filter:                           # Required
        user: |                         # Required
          (|
            (uniqueIdentifier=%L{user})
            (rnsMSRecipientAddress=%L{user})
          )
      mapping:                          # Required
        account_field: rnsMSDovecotUser # Required
      attribute: rnsMSDovecotUser       # Required

    - protocol:                         # Can be a single protocol or a list
        - imap
        - pop3
        - lmtp
        - sieve
        - doveadm
        - indexer-worker
        - default
      cache_name: dovecot
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
        list_accounts: |                # Optional
            (&
              (objectClass=rnsMSDovecotAccount)
              (rnsMSEnableDovecot=TRUE)
              (!
                (rnsMSDovecotMaster=TRUE)
              )
            )
        webauthn_credentials: |         # Optional
            (&
              (objectClass=rns2FAWebAuthn)
              (entryUUID=%{user_id})
            )
      mapping:
        account_field: rnsMSDovecotUser
        totp_secret_field: rns2FATOTPSecret  # Optional
        totp_recovery_field: rns2FATOTPRecoveryCode  # Optional
        display_name_field: cn          # Optional
        credential_object: rns2FAWebAuthn  # Optional
        credential_id_field: rns2FAWebAuthnCredID  # Optional
        public_key_field: rns2FAWebAuthnPubKey  # Optional
        unique_user_id_field: entryUUID  # Optional
        aaguid_field: rns2FAWebAuthnAAGUID  # Optional
        sign_count_field: rns2FAWebAuthnSignCount  # Optional
      attribute:                        # Can be a single attribute or a list
        - uid
        - rnsMSQuota
        - rnsMSOverQuota
        - rnsMSMailboxHome
        - rnsMSMailPath
        - rnsMSDovecotFTS
        - rnsMSDovecotFTSSolrUrl
        - rnsMSACLGroups
        - rnsMSDovecotUser

    - protocol:
        - smtp
        - submission
      cache_name: submission
      base_dn: ou=people,ou=it,dc=example,dc=com
      filter:
        user: |
            (&
              (objectClass=rnsMSPostfixAccount)
              (|
                (uniqueIdentifier=%L{user})
                (rnsMSRecipientAddress=%L{user})
              )
            )
      mapping:
        account_field: rnsMSDovecotUser
      attribute:
        - uid
        - rnsMSQuota
        - rnsMSOverQuota
        - rnsMSMailboxHome
        - rnsMSMailPath
        - rnsMSDovecotFTS
        - rnsMSDovecotFTSSolrUrl
        - rnsMSACLGroups
        - rnsMSDovecotUser

    - protocol:
        - ory-hydra
      cache_name: oauth
      base_dn: ou=people,ou=it,dc=example,dc=com
      filter:
        user: |
            (&
              (objectClass=inetOrgPerson)
              (|
                (entryUUID=%{user})
                (uid=%{user})
                (uniqueIdentifier=%L{user})
                (rnsMSRecipientAddress=%L{user})
              )
            )
      mapping:
        account_field: uid
        totp_secret_field: rns2FATOTPSecret
      attribute:
        - entryUUID
        - uid
        - cn;x-hidden
        - mail;x-hidden
        - givenName;x-hidden
        - sn;x-hidden
        - uniqueIdentifier
        - rnsMSDovecotUser
        - rnsMSMailboxHome
        - rnsMSMailPath
        - rnsMSACLGroups
        - rnsMSEnableDovecot
        - organizationalStatus
        - labeledURI;x-hidden

lua:
  # Lua features configuration
  features:                             # Default: empty list
    - name: demo                        # Required
      script_path: ./server/lua-plugins.d/features/demo.lua  # Required
    - name: comm
      script_path: ./server/lua-plugins.d/features/comm.lua

  # Lua filters configuration
  filters:                              # Default: empty list
    - name: geoip-policyd              # Required
      script_path: /some/path/to/lua/script.lua  # Required

  # Lua actions configuration
  actions:                              # Default: empty list
    - type: brute_force                 # Required
      name: brute_force                 # Required
      script_path: ./server/lua-plugins.d/actions/bruteforce.lua  # Required
    - type: post
      name: demoe
      script_path: ./server/lua-plugins.d/actions/demo.lua
    - type: post
      name: haveibeenpwnd
      script_path: ./server/lua-plugins.d/actions/haveibeenpwnd.lua
    - type: post
      name: telegram
      script_path: ./server/lua-plugins.d/actions/telegram.lua

  # Lua custom hooks configuration
  custom_hooks:                         # Default: empty list
    - http_location: "status"           # Required
      http_method: "GET"                # Required
      script_path: "/etc/nauthilus/lua-plugins.d/hooks/status_check.lua"  # Required
      roles: ["admin", "monitoring"]    # Optional
    - http_location: "user-info"
      http_method: "GET"
      script_path: "/etc/nauthilus/lua-plugins.d/hooks/user_info.lua"
      roles: ["user_info"]

  # Lua backend configuration
  config:
    script_path: ./server/lua-plugins.d/backend/backend.lua  # Required
    init_script_path: ./server/lua-plugins.d/init/init.lua  # Optional, single init script
    init_script_paths:  # Optional, list of init scripts (v1.7.7)
      - ./server/lua-plugins.d/init/init.lua
      - ./server/lua-plugins.d/init/init_neural.lua
    package_path: /usr/local/etc/nauthilus/lualib/?.lua  # Optional
    number_of_workers: 10               # Default: 10

  # Optional Lua backends
  optional_lua_backends:
    backend1:
      number_of_workers: 5
    backend2:
      number_of_workers: 3

  # Lua search configuration
  search:                               # Default: empty list
    - protocol:                         # Required
        - imap
        - pop3
        - lmtp
        - sieve
        - doveadm
        - indexer-worker
        - default
      cache_name: dovecot               # Optional
      backend_name: backend1            # Optional

    - protocol:
        - smtp
        - submission
      cache_name: submission

    - protocol: ory-hydra
      cache_name: oidc

backend_server_monitoring:
  # Backend servers configuration
  backend_servers:                      # Default: empty list
    - protocol: imap                    # Required (smtp, lmtp, pop3, imap, sieve, http)
      host: 192.168.0.2                 # Required
      port: 993                         # Required
      deep_check: true                  # Default: false
      test_username: some_unique_test_user  # Optional, required if deep_check is true
      test_password: some_password      # Optional, required if deep_check is true
      tls: true                         # Default: false
      tls_skip_verify: true             # Default: false
      haproxy_v2: true                  # Default: false
```

## Customizing Your Configuration

When adapting this example for your own use:

1. **Security Settings**: Replace all placeholder secrets and passwords with strong, unique values
2. **Server Addresses**: Update all server addresses, ports, and URIs to match your environment
3. **File Paths**: Ensure all file paths point to valid locations in your system
4. **LDAP Configuration**: Adjust the LDAP filters and attributes to match your directory structure
5. **Lua Scripts**: Verify that all referenced Lua scripts exist at the specified paths

Remember that not all sections are required. You can omit sections that aren't relevant to your deployment.
