#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

OPUS_VERSION="${PORT_OPUS_VERSION:-v1.5.1}"
TARBALL="opus-${OPUS_VERSION}.tar.gz"
URL="https://github.com/xiph/opus/archive/refs/tags/${OPUS_VERSION}.tar.gz"

mkdir -p "$SRC"

# Download the source tarball if not already present
if [[ ! -f "$SRC/$TARBALL" ]]; then
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Verify that the tarball is a valid archive
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

# Extract the source if not already extracted
if ! find "$SRC" -maxdepth 1 -type d -name "opus-*${OPUS_VERSION#v}*" | grep -q .; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

CANDIDATES=(
  "$SRC/opus-${OPUS_VERSION}"
  "$SRC/opus-${OPUS_VERSION#v}"
)

SRC_DIR=""
for c in "${CANDIDATES[@]}"; do
  if [[ -d "$c" ]]; then
    SRC_DIR="$c"
    break
  fi
done

if [[ -z "$SRC_DIR" ]]; then
  SRC_DIR=$(find "$SRC" -maxdepth 1 -type d -name "opus-*${OPUS_VERSION#v}*" | head -n1 || true)
fi

if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: opus source directory not found after extracting $TARBALL" >&2
  exit 1
fi
cd "$SRC_DIR"

# Prepare the build system
if [[ -x "./autogen.sh" ]]; then
  ./autogen.sh
fi

# Configure, build, and install opus
./configure \
  --prefix="$PREFIX" \
  --enable-static \
  --disable-shared \
  --disable-doc \
  --with-pic

make -j"$PAR"
make install
