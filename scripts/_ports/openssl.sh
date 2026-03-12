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

./config \
  --prefix="$PREFIX" \
  --openssldir="$PREFIX/ssl" \
  no-shared \
  no-tests \
  -j"$PAR"

make -j"$PAR"
make install_sw
