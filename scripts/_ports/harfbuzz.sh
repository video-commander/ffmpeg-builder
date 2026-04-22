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

# Download and extract harfbuzz source code
if [[ ! -f "$SRC/$TARBALL" ]]; then
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Verify that the tarball is valid
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

# Extract the source if not already extracted.
# || true: harfbuzz tarball contains a README symlink that fails on Windows
# (symlink creation requires elevated privileges); the actual source files
# are extracted successfully and that's all we need.
if ! find "$SRC" -maxdepth 1 -type d -name "harfbuzz-*${HARFBUZZ_VERSION}*" | grep -q .; then
  tar -xf "$SRC/$TARBALL" -C "$SRC" || true
fi

# Locate the source directory
SRC_DIR="$SRC/harfbuzz-${HARFBUZZ_VERSION}"
if [[ ! -d "$SRC_DIR" ]]; then
  SRC_DIR=$(find "$SRC" -maxdepth 1 -type d -name "harfbuzz-*${HARFBUZZ_VERSION}*" | head -n1 || true)
fi

if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: harfbuzz source directory not found after extracting $TARBALL" >&2
  exit 1
fi
BUILD_DIR="$SRC_DIR/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure, build, and install harfbuzz
cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_SHARED_LIBS=OFF \
  -DHB_BUILD_UTILS=OFF \
  -DHB_BUILD_TESTS=OFF \
  ..

ninja -j"$PAR"
ninja install
