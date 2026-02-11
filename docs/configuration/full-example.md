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
    configuration: false                # Default: false 

  # HTTP middlewares
  # Omit a key to keep it enabled; set to false to disable.
  middlewares:
    logging: true                       # Default: true
    limit: true                         # Default: true
    recovery: true                      # Default: true
    trusted_proxies: true               # Default: true
    request_decompression: true         # Default: true
    response_compression: true          # Default: true
    metrics: true                       # Default: true

  # TLS configuration
  tls:
    enabled: true                       # Default: false
    cert: /usr/local/etc/nauthilus/localhost.localdomain.pem
    key: /usr/local/etc/nauthilus/localhost.localdomain.key.pem
    ca_file: /usr/local/etc/nauthilus/ca.pem  # Default: ""
    min_tls_version: "TLS1.3"           # Default: "TLS1.2"
    skip_verify: false                  # Default: false
    cipher_suites:                      # Default: []
      - "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
      - "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
      - "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"

  # HTTP client configuration
  http_client:
    max_connections_per_host: 10        # Default: 0 (no limit)
    max_idle_connections: 5             # Default: 0 (no limit)
    max_idle_connections_per_host: 1    # Default: 0 (no limit)
    idle_connection_timeout: 60s        # Default: 0 (no timeout)
    proxy: "http://proxy.example.com:8080" # Default: ""
    # TLS configuration for HTTP client
    tls:                
      skip_verify: false                # Default: false

  # Basic authentication
  basic_auth:
    enabled: true                       # Default: false
    username: nauthilus
    password: nauthilus

  # OIDC Bearer authentication for backchannel API
  oidc_auth:
    enabled: true                       # Default: false

  # Timeouts
  timeouts:
    redis_read: 1s          # Timeout for Redis read operations (GET/HGET). Default: 1s
    redis_write: 2s         # Timeout for Redis write operations (SET/HSET). Default: 2s
    ldap_search: 3s         # Timeout for LDAP search operations. Default: 3s
    ldap_bind: 3s           # Timeout for LDAP bind/auth operations. Default: 3s
    ldap_modify: 5s         # Timeout for LDAP modify operations. Default: 5s
    lua_backend: 5s         # Timeout for Lua backend operations. Default: 5s

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
    - name: lua
      when_no_auth: true
    - tls_encryption
    - relay_domains
    - rbl
    - brute_force
    - backend_server_monitoring

  # Brute force protocols
  brute_force_protocols:
    - imap
    - imaps
    - submission
    - smtp
    - smtps
    - oidc
    - saml
    - http


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
    # Connection and timeout tuning
    pool_timeout: 150ms                 # Default: 80ms (1ms–30s)
    dial_timeout: 500ms                 # Default: 200ms (1ms–60s)
    read_timeout: 250ms                 # Default: 100ms (1ms–60s)
    write_timeout: 250ms                # Default: 100ms (1ms–60s)
    pool_fifo: true                     # Default: true
    conn_max_idle_time: 2m              # Default: 90s (0s–24h)
    max_retries: 2                      # Default: 1 (0 disables retries)
    positive_cache_ttl: 3600s           # Default: 3600s
    negative_cache_ttl: 7200s           # Default: 3600s
    encryption_secret: long-random-secret # Required for Lua redis_encrypt/decrypt (min. 16 chars, no spaces; internally derived to a 32-byte key)

    # Client Tracking
    client_tracking:
      enabled: true                     # Default: false
      bcast: false                      # Default: false
      noloop: true                      # Default: false
      opt_in: false                     # Default: false
      opt_out: true                     # Default: false
      prefixes: ["nt_", "sess:"]       # Default: []

    # In‑process account name cache
    account_local_cache:
      enabled: true                     # Default: false
      ttl: 90s                          # Default: 60s
      shards: 64                        # Default: 32 (1–1024)
      cleanup_interval: 5m              # Default: 10m
      max_items: 100000                 # Default: 0 (unlimited)

    # Client‑side command batching
    batching:
      enabled: true                     # Default: false
      max_batch_size: 32                # Default: 16 (2–1024)
      max_wait: 3ms                     # Default: 2ms (0–200ms)
      queue_capacity: 12000             # Default: 8192
      skip_commands: ["blpop", "brpop", "subscribe"] # Default: []
      pipeline_timeout: 5s              # Default: 5s

    # TLS configuration for Redis
    tls:                
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
      route_reads_to_replicas: true     # Default: false
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
    encryption_secret: 16-byte-or-longer-random-secret
    html_static_content_path: static/templates
    language_resources: server/resources
    languages: ["en", "de"]             # Default: ["en", "de", "fr", "es", "it", "pt", "ru", "zh", "hi", "fa", "ar", "ja"]
    default_language: en
    totp_issuer: nauthilus.me
    totp_skew: 1

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
    level_gzip: 7                       # Default (gzip): 5
    algorithms: ["br", "zstd", "gzip"]  # Order = preference
    level_zstd: 2                       # 0=Default,1=BestSpeed,2=BetterCompression,3=BestCompression
    level_brotli: 2                     # 0=Default,1=BestSpeed,2=BetterCompression,3=BestCompression
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
      rbl: auth.spamrats.com.           # Required (allows trailing dot to avoid search domains)
      ipv4: true                        # Default: false
      ipv6: true                        # Default: false
      return_code: 127.0.0.43           # Required
      weight: 10                        # Required
      allow_failure: false              # Default: false

    - name: AbusiX AuthBL
      rbl: YOUR-API-KEY.authbl.mail.abusix.zone.
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
  # Optional per-user soft whitelist for tolerations (username: [CIDR, ...])
  soft_whitelist: {}

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

  # Adaptive toleration settings
  adaptive_toleration: true             # Default: false
  min_tolerate_percent: 10              # Default: 10
  max_tolerate_percent: 50              # Default: 50
  scale_factor: 1.0                     # Default: 1.0

  # Custom tolerations
  custom_tolerations:                   # Default: empty list
    - ip_address: 192.168.1.0/24
      tolerate_percent: 30
      tolerate_ttl: 72h
      # Per-IP adaptive toleration settings
      adaptive_toleration: true
      min_tolerate_percent: 15
      max_tolerate_percent: 60
      scale_factor: 1.2
    - ip_address: 10.0.0.5
      tolerate_percent: 50
      tolerate_ttl: 24h
      # Explicitly disable adaptive toleration for this IP
      adaptive_toleration: false

  # Reduce PW_HIST writes for already‑blocked requests
  pw_history_for_known_accounts: true   # Default: false

  # IPv6 ip_scoping for RWP and Tolerations
  ip_scoping:
    rwp_ipv6_cidr: 64                   # Default: 0 (disabled)
    tolerations_ipv6_cidr: 64           # Default: 0 (disabled)

  # Cold-start grace for known accounts without negative PW history
  cold_start_grace_enabled: true        # Default: false
  cold_start_grace_ttl: 120s            # Default: 120s

  # Repeating-wrong-password allowance (tolerate up to N unique wrong password hashes within a window)
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

# Identity Provider configuration (Native OIDC and SAML2)
idp:
  # OpenID Connect configuration
  oidc:
    enabled: true
    issuer: https://nauthilus.example.com
    auto_key_rotation: true
    key_rotation_interval: 168h
    key_max_age: 720h
    access_token_type: jwt              # jwt or opaque
    default_access_token_lifetime: 1h
    default_refresh_token_lifetime: 30d
    custom_scopes:
      - name: my_custom_scope
        description: "A custom scope for my application"
        claims:
          - name: custom_claim_1
            type: string
          - name: custom_claim_2
            type: string
    # Device Code Flow (RFC 8628)
    device_code_expiry: 600s              # Default: 600s
    device_code_polling_interval: 5       # Default: 5
    device_code_user_code_length: 8       # Default: 8
    clients:
      - name: "My Application"
        client_id: my-client
        client_secret: client-secret
        redirect_uris:
          - https://app.example.com/callback
        scopes:
          - openid
          - profile
          - email
        grant_types:
          - authorization_code
        id_token_claims:
          mappings:
            - claim: email
              attribute: mail
            - claim: name
              attribute: cn
            - claim: groups
              attribute: memberOf

  # SAML 2.0 configuration
  saml2:
    enabled: true
    entity_id: https://nauthilus.example.com/idp/saml/metadata
    cert_file: /etc/nauthilus/saml.crt
    key_file: /etc/nauthilus/saml.key
    service_providers:
      - name: "Example App"
        entity_id: https://app.example.com/saml/metadata
        acs_url: https://app.example.com/saml/acs
        allowed_attributes: ["mail", "cn", "uid", "memberOf"]
        allow_mfa_manage: true

  # WebAuthn settings
  webauthn:
    rp_display_name: "Nauthilus IdP"
    rp_id: nauthilus.example.com
    rp_origins:
      - https://nauthilus.example.com


# LDAP configuration
ldap:
  # Main LDAP configuration
  config:
    number_of_workers: 10               # Default: 10
    lookup_pool_size: 8                 # Default: 10
    lookup_idle_pool_size: 2            # Default: 2
    auth_pool_size: 8                   # Default: 10
    auth_idle_pool_size: 2              # Default: 2
    # Queue limits per pool (0 = unlimited)
    lookup_queue_length: 0              # Default: 0
    auth_queue_length: 0                # Default: 0

    # Connection/token acquisition guard
    connect_abort_timeout: 10s          # Default: 10s

    # Operation-specific timeouts
    search_timeout: 0s                  # Default: 0 (lib default)
    bind_timeout: 0s                    # Default: 0 (lib default)
    modify_timeout: 0s                  # Default: 0 (lib default)

    # Search guardrails
    search_size_limit: 0                # Default: 0 (server default)
    search_time_limit: 0s               # Default: 0 (server default)

    # Retry/backoff on transient network errors
    retry_max: 2                        # Default: 2
    retry_base: 200ms                   # Default: 200ms
    retry_max_backoff: 2s               # Default: 2s

    # Circuit breaker per target
    cb_failure_threshold: 5             # Default: 5
    cb_cooldown: 30s                    # Default: 30s
    cb_half_open_max: 1                 # Default: 1

    # Health checks
    health_check_interval: 10s          # Default: 10s
    health_check_timeout: 1.5s          # Default: 1.5s

    # Request/result shaping & caches
    dn_cache_ttl: 60s                   # Default: 0s (disabled)
    membership_cache_ttl: 120s          # Default: 0s (disabled)
    negative_cache_ttl: 20s             # Default: 20s
    cache_max_entries: 5000             # Default: 5000
    cache_impl: ttl                     # Default: ttl (ttl|lru)
    include_raw_result: false           # Default: false

    # Optional auth rate limiting per pool
    auth_rate_limit_per_second: 0       # Default: 0 (disabled)
    auth_rate_limit_burst: 0            # Default: 0 (disabled)

    server_uri:
      - ldap://some.server:389/         # Required
    bind_dn: cn=admin,dc=example,dc=com # Optional
    bind_pw: secret                     # Optional
    encryption_secret: long-random-secret # Required if encrypted fields are used (min. 16 chars, no spaces; internally derived to a 32-byte key)
    starttls: true                      # Default: false
    tls_skip_verify: true               # Default: false
    sasl_external: true                 # Default: false
    lookup_pool_only: false             # Default: false

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
      # Per-pool queue limits (0 = unlimited)
      lookup_queue_length: 100
      auth_queue_length: 100
      # Per-pool timeouts and guardrails
      search_timeout: 2s  
      bind_timeout: 1s    
      modify_timeout: 2s  
      search_size_limit: 500
      search_time_limit: 3s 
      # Retry/backoff & breaker
      retry_max: 2        
      retry_base: 200ms   
      retry_max_backoff: 2s 
      cb_failure_threshold: 5 
      cb_cooldown: 30s    
      cb_half_open_max: 1 
      # Health checks
      health_check_interval: 10s        
      health_check_timeout: 1.5s        
      # Cache settings (optional)
      negative_cache_ttl: 20s 
      cache_impl: ttl     
      include_raw_result: false         
      # Per-pool auth rate limit (optional)
      auth_rate_limit_per_second: 0     
      auth_rate_limit_burst: 0
      server_uri:
        - ldap://ldap1.example.com:389/
      starttls: true
      tls_skip_verify: false
    pool2:
      lookup_pool_size: 3
      lookup_idle_pool_size: 1
      auth_pool_size: 3
      auth_idle_pool_size: 1
      lookup_queue_length: 50 
      auth_queue_length: 50 
      server_uri:
        - ldap://ldap2.example.com:389/
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
        - oidc
        - saml
      cache_name: oidc
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
      when_no_auth: false
    - name: comm
      script_path: ./server/lua-plugins.d/features/comm.lua
      when_no_auth: true

  # Lua filters configuration
  filters:                              # Default: empty list
    # Lua Filter execution flags
    # Each filter can declare in which auth state it should run:
    # - when_authenticated: true|false   # run when request.authenticated == true
    # - when_unauthenticated: true|false # run when request.authenticated == false
    # - when_no_auth: true|false         # run when request.no_auth == true (passwordless flows)
    # Defaults when all three are omitted or all set to false: when_authenticated=true, when_unauthenticated=true, when_no_auth=false.
    # Note: Local/in-memory cache hits set authenticated=true; filters configured for authenticated will run for cache hits as well.

    - name: geoip
      script_path: ./server/lua-plugins.d/filters/geoip.lua
      when_authenticated: true        
      when_unauthenticated: false     
      when_no_auth: false 

    - name: monitoring                  # Dovecot/Director routing
      script_path: ./server/lua-plugins.d/filters/monitoring.lua
      when_authenticated: true        
      when_unauthenticated: false     
      when_no_auth: false 

    - name: account_centric_monitoring  # Telemetry/metrics, should also run on failed logins
      script_path: ./server/lua-plugins.d/filters/account_centric_monitoring.lua
      when_authenticated: true        
      when_unauthenticated: true      
      when_no_auth: false 

    - name: soft_delay                  # Gentle per-account delay to slow down attacks
      script_path: ./server/lua-plugins.d/filters/soft_delay.lua
      when_authenticated: true        
      when_unauthenticated: true      
      when_no_auth: false 

    - name: account_protection_mode     # Progressive protection with optional enforcement
      script_path: ./server/lua-plugins.d/filters/account_protection_mode.lua
      when_authenticated: true        
      when_unauthenticated: true      
      when_no_auth: true

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
      scopes: ["admin", "monitoring"]   # Optional
    - http_location: "user-info"
      http_method: "GET"
      script_path: "/etc/nauthilus/lua-plugins.d/hooks/user_info.lua"
      scopes: ["user_info"]

  # Lua backend configuration
  config:
    script_path: ./server/lua-plugins.d/backend/backend.lua  # Required
    init_script_path: ./server/lua-plugins.d/init/init.lua  # Optional, single init script
    init_script_paths:  # Optional, list of init scripts
      - ./server/lua-plugins.d/init/init.lua
    package_path: /usr/local/etc/nauthilus/lualib/?.lua  # Optional
    backend_number_of_workers: 10       # Default: 10 (Lua backend workers)
    action_number_of_workers: 10        # Default: 10 (Lua Action workers)
    feature_vm_pool_size: 10            # (VM pool size for Lua features)
    filter_vm_pool_size: 10             # (VM pool size for Lua filters)
    hook_vm_pool_size: 10               # (VM pool size for Lua hooks)
    ip_scoping_v6_cidr: 64              # (IPv6 scoping for Lua features; 0 disables)
    ip_scoping_v4_cidr: 24              # (IPv4 scoping for Lua features; 0 disables)

  # Optional Lua backends
  optional_lua_backends:
    backend1:
      backend_number_of_workers: 5
    backend2:
      backend_number_of_workers: 3

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

    - protocol:
        - oidc
        - saml
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
