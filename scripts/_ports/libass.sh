#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

# Normalize to absolute paths
mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

LIBASS_VERSION="${PORT_LIBASS_VERSION:-0.17.3}"
TARBALL="libass-${LIBASS_VERSION}.tar.gz"
URL="https://github.com/libass/libass/archive/refs/tags/${LIBASS_VERSION}.tar.gz"

# Download and extract libass source code
if [[ ! -f "$SRC/$TARBALL" ]]; then
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Verify that the tarball is valid
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

# Extract the source if not already extracted
if ! find "$SRC" -maxdepth 1 -type d -name "libass-*${LIBASS_VERSION}*" | grep -q .; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

# Locate the source directory
SRC_DIR="$SRC/libass-${LIBASS_VERSION}"
if [[ ! -d "$SRC_DIR" ]]; then
  SRC_DIR=$(find "$SRC" -maxdepth 1 -type d -name "libass-*${LIBASS_VERSION}*" | head -n1 || true)
fi

if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: libass source directory not found after extracting $TARBALL" >&2
  exit 1
fi
cd "$SRC_DIR"

if [[ -x "./autogen.sh" ]]; then
  ./autogen.sh
fi

# Configure, build, and install libass
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static \
  --with-pic \
  --disable-fontconfig \
  --disable-require-system-font-provider

make -j"$PAR"
make install
