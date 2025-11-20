#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

OPUS_VERSION="${PORT_OPUS_VERSION:-v1.5.1}"
TARBALL="opus-${OPUS_VERSION}.tar.gz"
URL="https://github.com/xiph/opus/archive/refs/tags/${OPUS_VERSION}.tar.gz"

echo ">>> opus ${OPUS_VERSION}: prefix=$PREFIX"
echo ">>> opus: download URL: $URL"

mkdir -p "$SRC"

# ---------------------------------------------------------------------
# Download tarball if missing
# ---------------------------------------------------------------------
if [[ ! -f "$SRC/$TARBALL" ]]; then
  echo ">>> opus: downloading $TARBALL"
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
# Only extract if no opus-* dir for this version exists yet
if ! find "$SRC" -maxdepth 1 -type d -name "opus-*${OPUS_VERSION#v}*" | grep -q .; then
  echo ">>> opus: extracting $TARBALL"
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

# Try a few common names:
CANDIDATES=(
  "$SRC/opus-${OPUS_VERSION}"       # opus-v1.5.1
  "$SRC/opus-${OPUS_VERSION#v}"     # opus-1.5.1
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
  SRC_DIR=$(find "$SRC" -maxdepth 1 -type d -name "opus-*${OPUS_VERSION#v}*" | head -n1 || true)
fi

if [[ -z "$SRC_DIR" || ! -d "$SRC_DIR" ]]; then
  echo "ERROR: opus source directory not found after extracting $TARBALL" >&2
  exit 1
fi

echo ">>> opus: using source dir: $SRC_DIR"

# ---------------------------------------------------------------------
# Configure & build
# ---------------------------------------------------------------------
cd "$SRC_DIR"

# Some tarballs already have configure, some need autogen
if [[ -x "./autogen.sh" ]]; then
  ./autogen.sh
fi

./configure \
  --prefix="$PREFIX" \
  --enable-static \
  --disable-shared \
  --disable-doc \
  --with-pic

make -j"$PAR"
make install
