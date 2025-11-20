#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

VPX_VERSION="${PORT_VPX_VERSION:-v1.14.1}"
TARBALL="libvpx-${VPX_VERSION}.tar.gz"
URL="https://github.com/webmproject/libvpx/archive/refs/tags/${VPX_VERSION}.tar.gz"

echo ">>> libvpx ${VPX_VERSION}: prefix=$PREFIX"
echo ">>> libvpx: download URL: $URL"

mkdir -p "$SRC"

# ---------------------------------------------------------------------
# Download tarball if missing
# ---------------------------------------------------------------------
if [[ ! -f "$SRC/$TARBALL" ]]; then
  echo ">>> libvpx: downloading $TARBALL"
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
# Only extract if no libvpx-* dir for this version exists yet
if ! find "$SRC" -maxdepth 1 -type d -name "libvpx-*${VPX_VERSION#v}*" | grep -q .; then
  echo ">>> libvpx: extracting $TARBALL"
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

# Try a few common names:
CANDIDATES=(
  "$SRC/libvpx-${VPX_VERSION}"        # libvpx-v1.14.1
  "$SRC/libvpx-${VPX_VERSION#v}"      # libvpx-1.14.1
)

SRC_DIR=""

for c in "${CANDIDATES[@]}"; do
  if [[ -d "$c" ]]; then
    SRC_DIR="$c"
    break
  fi
done

# Fallback: best-effort glob
if [[ -z "$SRC_DIR" ]]; then
  SRC_DIR=$(find "$SRC" -maxdepth 1 -type d -name "libvpx-*${VPX_VERSION#v}*" | head -n1 || true)
fi

if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: libvpx source directory not found after extracting $TARBALL" >&2
  exit 1
fi

echo ">>> libvpx: using source dir: $SRC_DIR"

# ---------------------------------------------------------------------
# Configure & build
# ---------------------------------------------------------------------
cd "$SRC_DIR"

./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static \
  --disable-unit-tests \
  --disable-docs \
  --disable-examples \
  --enable-vp9-highbitdepth

make -j"$PAR"
make install
