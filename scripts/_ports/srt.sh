#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

# Normalize to absolute paths
mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

# SRT version; allow "1.5.4" or "v1.5.4"
RAW_SRT_VERSION="${PORT_SRT_VERSION:-1.5.4}"
SRT_VERSION_NO_V="${RAW_SRT_VERSION#v}"    # strip leading 'v' if present
TAG="v${SRT_VERSION_NO_V}"                 # GitHub tag name always "vX.Y.Z"

TARBALL="${TAG}.tar.gz"                    # e.g. v1.5.4.tar.gz
URL="https://github.com/Haivision/srt/archive/refs/tags/${TARBALL}"

echo ">>> srt ${TAG}: prefix=$PREFIX"
echo ">>> srt: download URL: $URL"

# ---------------------------------------------------------------------
# Download tarball if missing
# ---------------------------------------------------------------------
if [[ ! -f "$SRC/$TARBALL" ]]; then
  echo ">>> srt: downloading $TARBALL"
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Validate archive
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

# ---------------------------------------------------------------------
# Extract once and detect top-level directory
# ---------------------------------------------------------------------
TOPDIR=$(tar -tf "$SRC/$TARBALL" | head -n1 | cut -d/ -f1)

if [[ -z "$TOPDIR" ]]; then
  echo "ERROR: failed to detect top-level directory inside $TARBALL" >&2
  exit 1
fi

if [[ ! -d "$SRC/$TOPDIR" ]]; then
  echo ">>> srt: extracting $TARBALL"
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

SRC_DIR="$SRC/$TOPDIR"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: srt source directory not found after extracting $TARBALL (expected $SRC_DIR)" >&2
  exit 1
fi

echo ">>> srt: using source dir: $SRC_DIR"

# ---------------------------------------------------------------------
# Configure & build with CMake + Ninja (static only, no apps)
# ---------------------------------------------------------------------
BUILD_DIR="$SRC_DIR/build-ffmpeg-builder"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DENABLE_SHARED=OFF \
  -DENABLE_STATIC=ON \
  -DENABLE_APPS=OFF \
  ..

ninja -j"$PAR"
ninja install

echo ">>> srt ${TAG}: done"
