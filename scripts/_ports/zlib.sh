#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

ZLIB_VERSION="${PORT_ZLIB_VERSION:-1.3.1}"
TARBALL="zlib-${ZLIB_VERSION}.tar.gz"
URL="https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/${TARBALL}"

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
  "$SRC_DIR"

ninja -j"$PAR"
ninja install

# cmake names the static target libzlibstatic.a; rename to libz.a so the linker
# finds it when pkg-config returns -lz, and remove the shared lib to prevent the
# linker from preferring the DLL import lib over the static archive.
mv "$PREFIX/lib/libzlibstatic.a" "$PREFIX/lib/libz.a"
rm -f "$PREFIX/lib/libzlib.dll.a" "$PREFIX/bin/libzlib.dll"
