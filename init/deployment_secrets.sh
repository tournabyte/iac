#!/usr/bin/env bash

set -euo pipefail

# Set up secrets directory
SECRETS_DIR=$(git rev-parse --show-toplevel)/.env
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# Function to save a login ID
generate_login() {
  local name="$1"
  local login="$2"
  local permissions="${3:-600}"
  local file="${SECRETS_DIR}/${name}.txt"

  echo -n "$login" >"$file"
  chmod "$permissions" "$file"

  echo "Saved login: $file"
}

# Function to generate a secret
generate_secret_string() {
  local name="$1"
  local bytes="${2:-32}"
  local permissions="${3:-600}"
  local file="$SECRETS_DIR/${name}.txt"

  openssl rand -hex -out "$file" "$bytes"
  chmod "$permissions" "$file"

  echo "Created secret: $file"
}

# Function go generate a certificate
generate_certificate() {
  local name="$1"
  local key_file="$SECRETS_DIR/${name}_KEYCHAIN.txt"
  local crt_file="$SECRETS_DIR/${name}_CERTIFICATE.txt"

  openssl genrsa -out "$key_file" 4096
  chmod 400 "$key_file"

  openssl req -new -x509 \
    -key "$key_file" \
    -out "$crt_file" \
    -days 30 \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=*.tournabyte.com"
  chmod 400 "$crt_file"

  echo "Created certificate {key: $key_file, cert: $crt_file}"
}

echo "Generating secrets..."
generate_login "API_DB_USERNAME" "tbyte-user" 600
generate_secret_string "API_DB_PASSWORD" 128 400
generate_secret_string "API_S3_ACCESS_KEY" 128 400
generate_login "API_S3_ACCESS_ID" "minioadmin" 600
generate_certificate "API_TLS"
generate_secret_string "DBROOT_PASSWORD" 128 400
generate_login "DBROOT_USERNAME" "mongoadmin" 600
generate_secret_string "S3ROOT_PASSWORD" 128 400
generate_login "S3ROOT_USERNAME" "minioadmin" 600
generate_secret_string "DBSHARD_KEYFILE" 512 400
generate_secret_string JWT_SECRET_KEY 32 400
echo "Done."
