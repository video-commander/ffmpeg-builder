#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

XZ_VERSION="${PORT_XZ_VERSION:-5.6.3}"
TARBALL="xz-${XZ_VERSION}.tar.gz"
URL="https://github.com/tukaani-project/xz/releases/download/v${XZ_VERSION}/${TARBALL}"

if [[ ! -f "$SRC/$TARBALL" ]]; then
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

TOPDIR=$(tar -tf "$SRC/$TARBALL" | head -n1 | cut -d/ -f1 || true)
if [[ -z "$TOPDIR" ]]; then
  echo "ERROR: failed to detect top-level directory inside $TARBALL" >&2
  exit 1
fi

if [[ ! -d "$SRC/$TOPDIR" ]]; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

SRC_DIR="$SRC/$TOPDIR"
BUILD_DIR="$SRC_DIR/build-ffmpeg-builder"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF \
  -DCREATE_XZ_SYMLINKS=OFF \
  -DCREATE_LZMA_SYMLINKS=OFF \
  "$SRC_DIR"

ninja -j"$PAR"
ninja install
