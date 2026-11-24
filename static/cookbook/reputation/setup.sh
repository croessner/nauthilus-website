#!/usr/bin/env sh
# Creates the key material of the "Learning IP reputation" recipe in ./secrets. Run once before docker compose up.
#   reputation-subject.key, reputation-manifest.key  32 random bytes each; the reputation plugin stores subjects
#                                                    (IP addresses, networks, accounts) only as HMAC tags of them
#   oidc-signing.key                                 RSA key the built-in identity provider signs tokens with
set -eu
cd "$(dirname "$0")"
mkdir -p secrets

for name in reputation-subject reputation-manifest; do
    [ -f "secrets/$name.key" ] || openssl rand -out "secrets/$name.key" 32
done

[ -f secrets/oidc-signing.key ] || openssl genrsa -out secrets/oidc-signing.key 2048 2>/dev/null

# Nauthilus runs as user 65532 in the container and must be able to read the demo keys.
chmod 0644 secrets/*.key
echo "Key material: $(pwd)/secrets"
