#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

# Normalize to absolute paths
mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

HARFBUZZ_VERSION="${PORT_HARFBUZZ_VERSION:-8.3.1}"
TARBALL="harfbuzz-${HARFBUZZ_VERSION}.tar.gz"
URL="https://github.com/harfbuzz/harfbuzz/archive/refs/tags/${HARFBUZZ_VERSION}.tar.gz"

echo ">>> harfbuzz ${HARFBUZZ_VERSION}: prefix=$PREFIX"
echo ">>> harfbuzz: download URL: $URL"

# ---------------------------------------------------------------------
# Download tarball if missing
# ---------------------------------------------------------------------
if [[ ! -f "$SRC/$TARBALL" ]]; then
  echo ">>> harfbuzz: downloading $TARBALL"
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Validate archive
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

# ---------------------------------------------------------------------
# Extract once
# ---------------------------------------------------------------------
if ! find "$SRC" -maxdepth 1 -type d -name "harfbuzz-*${HARFBUZZ_VERSION}*" | grep -q .; then
  echo ">>> harfbuzz: extracting $TARBALL"
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

# Try a few common names
CANDIDATES=(
  "$SRC/harfbuzz-${HARFBUZZ_VERSION}"
)

SRC_DIR=""

for c in "${CANDIDATES[@]}"; do
  if [[ -d "$c" ]]; then
    SRC_DIR="$c"
    break
  fi
done

# Fallback: glob
if [[ -z "$SRC_DIR" ]]; then
  SRC_DIR=$(find "$SRC" -maxdepth 1 -type d -name "harfbuzz-*${HARFBUZZ_VERSION}*" | head -n1 || true)
fi

if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: harfbuzz source directory not found after extracting $TARBALL" >&2
  exit 1
fi

echo ">>> harfbuzz: using source dir: $SRC_DIR"

# ---------------------------------------------------------------------
# Configure & build (CMake)
# ---------------------------------------------------------------------
BUILD_DIR="$SRC_DIR/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_SHARED_LIBS=OFF \
  -DHB_BUILD_UTILS=OFF \
  -DHB_BUILD_TESTS=OFF \
  ..

ninja -j"$PAR"
ninja install

echo ">>> harfbuzz ${HARFBUZZ_VERSION}: done"
