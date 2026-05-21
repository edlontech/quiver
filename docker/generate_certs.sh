#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CERTS_DIR="$ROOT/certs"
WWW_DIR="$ROOT/docker/www"

mkdir -p "$CERTS_DIR"
mkdir -p "$WWW_DIR"

if [[ ! -f "$CERTS_DIR/cert.pem" || ! -f "$CERTS_DIR/priv.key" ]]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -keyout "$CERTS_DIR/priv.key" -out "$CERTS_DIR/cert.pem" \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
  chmod 600 "$CERTS_DIR/priv.key"
  echo "wrote $CERTS_DIR/cert.pem and $CERTS_DIR/priv.key"
else
  echo "$CERTS_DIR already populated"
fi

if [[ ! -f "$WWW_DIR/large.bin" ]]; then
  head -c 1048576 /dev/urandom > "$WWW_DIR/large.bin"
  echo "wrote $WWW_DIR/large.bin (1 MiB)"
else
  echo "$WWW_DIR/large.bin already present"
fi
