#!/usr/bin/env sh
# Creates a self-signed TLS certificate for 127.0.0.1 and localhost in ./tls. The Policy API accepts Basic
# credentials only over TLS, so Nauthilus serves HTTPS in this recipe. Run once before docker compose up.
set -eu
cd "$(dirname "$0")"
mkdir -p tls

if [ ! -f tls/server.key ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
        -keyout tls/server.key -out tls/server.crt \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null
    # Nauthilus runs as user 65532 in the container and must be able to read the key.
    chmod 0644 tls/server.key tls/server.crt
fi

echo "TLS certificate: $(pwd)/tls/server.crt"
