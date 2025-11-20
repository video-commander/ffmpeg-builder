#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

# Normalize to absolute paths
mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

LIBASS_VERSION="${PORT_LIBASS_VERSION:-0.17.3}"
TARBALL="libass-${LIBASS_VERSION}.tar.gz"
URL="https://github.com/libass/libass/archive/refs/tags/${LIBASS_VERSION}.tar.gz"

echo ">>> libass ${LIBASS_VERSION}: prefix=$PREFIX"
echo ">>> libass: download URL: $URL"

# ---------------------------------------------------------------------
# Download tarball if missing
# ---------------------------------------------------------------------
if [[ ! -f "$SRC/$TARBALL" ]]; then
  echo ">>> libass: downloading $TARBALL"
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
if ! find "$SRC" -maxdepth 1 -type d -name "libass-*${LIBASS_VERSION}*" | grep -q .; then
  echo ">>> libass: extracting $TARBALL"
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

# Determine source dir
CANDIDATES=(
  "$SRC/libass-${LIBASS_VERSION}"
)

SRC_DIR=""
for c in "${CANDIDATES[@]}"; do
  if [[ -d "$c" ]]; then
    SRC_DIR="$c"
    break
  fi
done

if [[ -z "$SRC_DIR" ]]; then
  SRC_DIR=$(find "$SRC" -maxdepth 1 -type d -name "libass-*${LIBASS_VERSION}*" | head -n1 || true)
fi

if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: libass source directory not found after extracting $TARBALL" >&2
  exit 1
fi

echo ">>> libass: using source dir: $SRC_DIR"

# ---------------------------------------------------------------------
# Configure & build (Autotools)
# ---------------------------------------------------------------------
cd "$SRC_DIR"

# Some tarballs already have configure; some need autogen.sh
if [[ -x "./autogen.sh" ]]; then
  ./autogen.sh
fi

# Build static libass, but WITHOUT fontconfig/system font provider
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
./configure \
  --prefix="$PREFIX" \
  --disable-shared \
  --enable-static \
  --with-pic \
  --disable-fontconfig \
  --disable-require-system-font-provider

make -j"$PAR"
make install

echo ">>> libass ${LIBASS_VERSION}: done"
