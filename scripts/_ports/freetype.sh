#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

# Normalize to absolute paths
mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

FREETYPE_VERSION="${PORT_FREETYPE_VERSION:-VER-2-13-2}"
TARBALL="freetype-${FREETYPE_VERSION}.tar.gz"
URL="https://github.com/freetype/freetype/archive/refs/tags/${FREETYPE_VERSION}.tar.gz"

# Download and extract freetype source code
if [[ ! -f "$SRC/$TARBALL" ]]; then
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Verify that the tarball is valid
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

# Extract the source if not already extracted
if ! find "$SRC" -maxdepth 1 -type d -name "freetype-*${FREETYPE_VERSION#VER-}*" | grep -q .; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

# Locate the source directory
CANDIDATES=(
  "$SRC/freetype-${FREETYPE_VERSION}"
  "$SRC/freetype-${FREETYPE_VERSION#VER-}"
)

SRC_DIR=""
for c in "${CANDIDATES[@]}"; do
  if [[ -d "$c" ]]; then
    SRC_DIR="$c"
    break
  fi
done

if [[ -z "$SRC_DIR" ]]; then
  SRC_DIR=$(find "$SRC" -maxdepth 1 -type d -name "freetype-*${FREETYPE_VERSION#VER-}*" | head -n1 || true)
fi

if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: freetype source directory not found after extracting $TARBALL" >&2
  exit 1
fi
BUILD_DIR="$SRC_DIR/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure, build, and install freetype
cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_SHARED_LIBS=OFF \
  -DFT_DISABLE_PNG=ON \
  -DFT_DISABLE_BZIP2=ON \
  -DFT_DISABLE_BROTLI=ON \
  -DFT_DISABLE_HARFBUZZ=ON \
  ..

ninja -j"$PAR"
ninja install
