#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

OPENSSL_VERSION="${PORT_OPENSSL_VERSION:-3.3.2}"
TARBALL="openssl-${OPENSSL_VERSION}.tar.gz"
URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/${TARBALL}"

if [[ ! -f "$SRC/$TARBALL" ]]; then
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

TOPDIR=$(tar -tf "$SRC/$TARBALL" | head -n1 | cut -d/ -f1)
if [[ ! -d "$SRC/$TOPDIR" ]]; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

cd "$SRC/$TOPDIR"

# openssldir is baked into libcrypto and is what SSL_CTX_set_default_verify_paths()
# resolves at runtime on the *user's* machine, not ours — so it must not point into
# the build tree. FFmpeg 9.0 turned on TLS peer verification by default, so a dead
# CA path here breaks every https/tls/rtmps input in the shipped binary.
# /etc/ssl covers macOS (cert.pem) and Linux (certs/); SSL_CERT_FILE still overrides.
# install_sw skips installing into openssldir, so nothing is written to /etc.
./config \
  --prefix="$PREFIX" \
  --openssldir=/etc/ssl \
  no-shared \
  no-tests

make -j"$PAR"
make install_sw
