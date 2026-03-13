#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

VPX_VERSION="${PORT_VPX_VERSION:-v1.16.0}"
TARBALL="libvpx-${VPX_VERSION}.tar.gz"
URL="https://github.com/webmproject/libvpx/archive/refs/tags/${VPX_VERSION}.tar.gz"

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
if ! find "$SRC" -maxdepth 1 -type d -name "libvpx-*${VPX_VERSION#v}*" | grep -q .; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

# Locate the source directory
CANDIDATES=(
  "$SRC/libvpx-${VPX_VERSION}"
  "$SRC/libvpx-${VPX_VERSION#v}"
)

# Find the correct source directory
SRC_DIR=""
for c in "${CANDIDATES[@]}"; do
  if [[ -d "$c" ]]; then
    SRC_DIR="$c"
    break
  fi
done

if [[ -z "$SRC_DIR" ]]; then
  SRC_DIR=$(find "$SRC" -maxdepth 1 -type d -name "libvpx-*${VPX_VERSION#v}*" | head -n1 || true)
fi

if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: libvpx source directory not found after extracting $TARBALL" >&2
  exit 1
fi
cd "$SRC_DIR"

# Determine the libvpx target — its configure script doesn't auto-detect arm64-darwin
VPX_TARGET_FLAG=()
if [[ "$(uname)" == "Darwin" ]]; then
  DARWIN_VER=$(uname -r | cut -d. -f1)
  ARCH=$(uname -m)
  VPX_TARGET_FLAG=("--target=${ARCH}-darwin${DARWIN_VER}-gcc")
fi

# Configure, build, and install libvpx
./configure \
  "${VPX_TARGET_FLAG[@]}" \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static \
  --disable-unit-tests \
  --disable-docs \
  --disable-examples \
  --enable-vp9-highbitdepth

make -j"$PAR"
make install
