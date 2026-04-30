---
title: Full Configuration Example
description: Complete current config-v2 reference for Nauthilus
keywords: [Configuration, Example, Full, v2]
sidebar_position: 11
---

# Full Configuration Example

This page mirrors the current config-v2 reference structure.

For the canonical defaults from a running binary, use:

```bash
nauthilus -d
```

For only the changed values of a concrete file, use:

```bash
nauthilus -n --config /etc/nauthilus/nauthilus.yml
```

## Current Reference Example

```yaml
runtime:
  instance_name: "nauthilus"

  process:
    run_as_user: "nauthilus"
    run_as_group: "nauthilus"
    chroot: "/var/empty"

  servers:
    http:
      address: "0.0.0.0:8080"
      http3: false
      haproxy_v2: false
      trusted_proxies:
        - "127.0.0.1"
        - "::1"

      tls:
        enabled: false
        skip_verify: false
        min_tls_version: "TLS1.2"
        cert: ""
        key: ""
        ca_file: ""

      disabled_endpoints: {}

      middlewares:
        logging: true
        limit: true
        recovery: true
        trusted_proxies: true
        request_decompression: true
        response_compression: true
        metrics: true
        rate: true

      compression:
        enabled: false

      keep_alive:
        enabled: true
        timeout: 30s
        max_idle_connections: 100
        max_idle_connections_per_host: 10

      rate_limit:
        per_second: 0
        burst: 0

    grpc:
      auth:
        enabled: false
        address: "127.0.0.1:9444"

        tls:
          enabled: false
          cert: ""
          key: ""
          client_ca: ""
          min_tls_version: "TLS1.2"
          require_client_cert: false

  timeouts:
    redis_read: 1s
    redis_write: 2s
    ldap_search: 3s
    ldap_bind: 3s
    ldap_modify: 5s
    lua_backend: 5s
    lua_script: 30s

  clients:
    http:
      max_connections_per_host: 0
      max_idle_connections: 0
      max_idle_connections_per_host: 0
      idle_connection_timeout: 0s
      proxy: ""

      tls:
        skip_verify: false
        min_tls_version: "TLS1.2"
        cert: ""
        key: ""
        ca_file: ""
        cipher_suites: []

    dns:
      resolver: ""
      timeout: 5s
      resolve_client_ip: false

observability:
  log:
    json: false
    color: true
    level: "info"
    add_source: false
    debug_modules: []

  profiles:
    pprof:
      enabled: false
    block:
      enabled: false

  tracing:
    enabled: false
    exporter: "none"
    endpoint: ""
    sampler_ratio: 0.1
    service_name: "nauthilus"
    propagators:
      - "tracecontext"
      - "baggage"
    enable_redis: false
    log_export_results: false

    tls:
      enabled: false
      skip_verify: false
      min_tls_version: "TLS1.2"
      cert: ""
      key: ""
      ca_file: ""

  metrics:
    monitor_connections: false

    prometheus_timer:
      enabled: false
      labels: []

storage:
  redis:
    protocol: 2
    database_number: 0
    prefix: "nt:"
    password_nonce: ""
    encryption_secret: ""
    pool_size: 128
    idle_pool_size: 32
    positive_cache_ttl: 1h
    negative_cache_ttl: 2h

    primary:
      address: "127.0.0.1:6379"
      username: ""
      password: ""

    replica:
      address: ""
      addresses: []

    sentinels:
      master: ""
      addresses: []
      username: ""
      password: ""

    cluster:
      addresses: []
      username: ""
      password: ""
      route_by_latency: false
      route_randomly: false
      route_reads_to_replicas: false
      max_redirects: 0

    tls:
      enabled: false
      skip_verify: false
      min_tls_version: "TLS1.2"
      cert: ""
      key: ""
      ca_file: ""

    pool_timeout: 1s
    dial_timeout: 5s
    read_timeout: 1s
    write_timeout: 1s
    pool_fifo: true
    conn_max_idle_time: 90s
    max_retries: 1
    identity_enabled: false
    maint_notifications_enabled: false

    account_local_cache:
      enabled: false
      ttl: 1m
      shards: 32
      cleanup_interval: 5m
      max_items: 10000

    batching:
      enabled: false
      max_batch_size: 16
      max_wait: 2ms
      queue_capacity: 8192
      skip_commands: []
      pipeline_timeout: 5s

    client_tracking:
      enabled: false
      bcast: false
      noloop: false
      opt_in: false
      opt_out: false
      prefixes: []

auth:
  request:
    headers:
      username: "Auth-User"
      password: "Auth-Pass"
      password_encoded: "X-Auth-Password-Encoded"
      protocol: "Auth-Protocol"
      login_attempt: "Auth-Login-Attempt"
      auth_method: "Auth-Method"
      local_ip: "X-Local-IP"
      local_port: "X-Auth-Port"
      client_ip: "Client-IP"
      client_port: "X-Client-Port"
      client_host: ""
      client_id: "X-Client-ID"
      oidc_cid: "X-OIDC-CID"
      ssl: "X-SSL"
      ssl_session_id: "X-SSL-Session-ID"
      ssl_verify: "X-SSL-Client-Verify"
      ssl_subject: "X-SSL-Client-DN"
      ssl_client_cn: "X-SSL-Client-CN"
      ssl_issuer: "X-SSL-Issuer"
      ssl_client_not_before: "X-SSL-Client-NotBefore"
      ssl_client_not_after: "X-SSL-Client-NotAfter"
      ssl_subject_dn: "X-SSL-Subject-DN"
      ssl_issuer_dn: "X-SSL-Issuer-DN"
      ssl_client_subject_dn: "X-SSL-Client-Subject-DN"
      ssl_client_issuer_dn: "X-SSL-Client-Issuer-DN"
      ssl_cipher: "X-SSL-Cipher"
      ssl_protocol: "X-SSL-Protocol"
      ssl_serial: "Auth-SSL-Serial"
      ssl_fingerprint: "Auth-SSL-Fingerprint"

  backchannel:
    basic_auth:
      enabled: false
      username: ""
      password: ""

    oidc_bearer:
      enabled: false

  pipeline:
    max_concurrent_requests: 100
    max_login_attempts: 15
    wait_delay: 0
    local_cache_ttl: 30s

    password_history:
      max_entries: 1000

    master_user:
      enabled: false
      delimiter: "*"

  upstreams:
    imap:
      address: "127.0.0.1"
      port: 143
    pop3:
      address: "127.0.0.1"
      port: 110
    smtp:
      address: "127.0.0.1"
      port: 25

  backends:
    order:
      - "cache"
      - "ldap"

    ldap:
      default:
        lookup_pool_only: false
        number_of_workers: 16
        lookup_pool_size: 16
        lookup_idle_pool_size: 4
        auth_pool_size: 16
        auth_idle_pool_size: 4
        server_uri:
          - "ldapi:///"

      pools: {}
      search: []

    lua:
      backend:
        default:
          package_path: ""
        named_backends: {}
        search: []

      actions: []
      controls: []
      filters: []
      hooks: []

  controls:
    enabled: []

    tls_encryption:
      allow_cleartext_networks: []

    rbl:
      threshold: 0
      lists: []
      ip_allowlist: []

    relay_domains:
      static: []
      allowlist: {}

    brute_force:
      protocols: []
      ip_allowlist: []
      buckets: []
      learning: []
      custom_tolerations: []

      ip_scoping:
        rwp_ipv6_cidr: 128
        tolerations_ipv6_cidr: 128

      tolerate_ttl: 30m
      rwp_window: 15m
      rwp_allowed_unique_hashes: 3
      tolerate_percent: 0
      min_tolerate_percent: 10
      max_tolerate_percent: 50
      scale_factor: 1.0
      adaptive_toleration: false
      pw_history_for_known_accounts: false

    lua:
      actions: []
      controls: []
      filters: []
      hooks: []

  services:
    enabled: []

    backend_health_checks:
      connect_timeout: 5s
      tls_timeout: 5s
      deep_timeout: 5s
      connect_interval: 10s
      deep_interval: 10s
      failure_threshold: 1
      recovery_threshold: 1
      targets: []

identity:
  session:
    remember_me_ttl: 0s

  frontend:
    enabled: false
    encryption_secret: ""

    assets:
      html_static_content_path: ""
      language_resources: ""

    localization:
      languages: []
      default_language: "en"

    links:
      terms_of_service_url: ""
      privacy_policy_url: ""
      password_forgotten_url: ""

    security_headers:
      enabled: true

  mfa:
    totp:
      issuer: "Nauthilus"
      skew: 1

    webauthn:
      rp_display_name: "Nauthilus"
      rp_id: "localhost"
      rp_origins:
        - "https://localhost"
      authenticator_attachment: ""
      resident_key: "discouraged"
      user_verification: "preferred"

  oidc:
    enabled: false
    issuer: ""
    signing_keys: []
    clients: []
    custom_scopes: []
    scopes_supported: []
    response_types_supported: []
    subject_types_supported: []
    id_token_signing_alg_values_supported: []
    token_endpoint_auth_methods_supported: []
    code_challenge_methods_supported: []
    claims_supported: []
    access_token_type: "jwt"

    consent:
      ttl: 0s
      mode: "all_or_nothing"

    tokens:
      default_access_token_lifetime: 1h
      default_refresh_token_lifetime: 720h
      revoke_refresh_token: true
      token_endpoint_allow_get: false

    logout:
      front_channel_supported: true
      front_channel_session_supported: false
      back_channel_supported: true
      back_channel_session_supported: false

    device_flow:
      code_expiry: 10m
      polling_interval: 5
      user_code_length: 8

  saml:
    enabled: false
    entity_id: ""
    cert: ""
    cert_file: ""
    key: ""
    key_file: ""
    signature_method: ""
    default_expire_time: 1h
    name_id_format: ""
    service_providers: []

    slo:
      enabled: true
      front_channel_enabled: true
      back_channel_enabled: false
      request_timeout: 3s
      max_participants: 64
      back_channel_max_retries: 1
```
