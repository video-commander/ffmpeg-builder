#!/usr/bin/env bash
set -euo pipefail

# shared helpers (fetch_url: retries transient download failures)
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/util.sh"

SRC="$1"
PREFIX="$2"
PAR="$3"

# Normalize to absolute paths
mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

RAW_DAV1D_VERSION="${PORT_DAV1D_VERSION:-1.5.4}"
DAV1D_VERSION="${RAW_DAV1D_VERSION#v}"
TARBALL="dav1d-${DAV1D_VERSION}.tar.gz"
URL="https://github.com/videolan/dav1d/archive/refs/tags/${DAV1D_VERSION}.tar.gz"

if [[ ! -f "$SRC/$TARBALL" ]]; then
  fetch_url "$URL" "$SRC/$TARBALL"
fi

# Verify that the tarball is valid
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

TOPDIR=$(tar -tf "$SRC/$TARBALL" | head -n1 | cut -d/ -f1)
if [[ -z "$TOPDIR" ]]; then
  echo "ERROR: failed to detect top-level directory inside $TARBALL" >&2
  exit 1
fi

if [[ ! -d "$SRC/$TOPDIR" ]]; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

SRC_DIR="$SRC/$TOPDIR"
if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: dav1d source directory not found after extracting $TARBALL (expected $SRC_DIR)" >&2
  exit 1
fi

BUILD_DIR="$SRC_DIR/build-meson"
rm -rf "$BUILD_DIR"

# enable_tools builds the dav1d CLI, which the FFmpeg link does not use.
meson setup "$BUILD_DIR" "$SRC_DIR" \
  --prefix "$PREFIX" \
  --libdir lib \
  --buildtype release \
  --default-library static \
  -Denable_tools=false \
  -Denable_tests=false

ninja -C "$BUILD_DIR" -j"$PAR"
ninja -C "$BUILD_DIR" install

install_license "$PREFIX" "dav1d" "$SRC_DIR"
