#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

# Normalize to absolute paths
mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

FRIBIDI_VERSION="${PORT_FRIBIDI_VERSION:-v1.0.13}"
TARBALL="fribidi-${FRIBIDI_VERSION}.tar.gz"
URL="https://github.com/fribidi/fribidi/archive/refs/tags/${FRIBIDI_VERSION}.tar.gz"

# Download and extract fribidi source code
if [[ ! -f "$SRC/$TARBALL" ]]; then
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Verify that the tarball is valid
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

# Extract the source if not already extracted
if ! find "$SRC" -maxdepth 1 -type d -name "fribidi-*${FRIBIDI_VERSION#v}*" | grep -q .; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

# Locate the source directory
CANDIDATES=(
  "$SRC/fribidi-${FRIBIDI_VERSION}"
  "$SRC/fribidi-${FRIBIDI_VERSION#v}"
)

SRC_DIR=""
for c in "${CANDIDATES[@]}"; do
  if [[ -d "$c" ]]; then
    SRC_DIR="$c"
    break
  fi
done

if [[ -z "$SRC_DIR" ]]; then
  SRC_DIR=$(find "$SRC" -maxdepth 1 -type d -name "fribidi-*${FRIBIDI_VERSION#v}*" | head -n1 || true)
fi

if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: fribidi source directory not found after extracting $TARBALL" >&2
  exit 1
fi
BUILD_DIR="$SRC_DIR/build-meson"
rm -rf "$BUILD_DIR"

# Configure, build, and install fribidi
meson setup "$BUILD_DIR" "$SRC_DIR" \
  --prefix "$PREFIX" \
  --libdir lib \
  --buildtype release \
  --default-library static \
  -Ddocs=false \
  -Dtests=false

ninja -C "$BUILD_DIR" -j"$PAR"
ninja -C "$BUILD_DIR" install
