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

RAW_LAME_VERSION="${PORT_LAME_VERSION:-4.0}"
LAME_VERSION="${RAW_LAME_VERSION#v}"
TARBALL="lame-${LAME_VERSION}.tar.gz"
# SourceForge keeps releases under lame/<major.minor>/, which for 3.100 and 4.0
# alike is the full version string.
URL="https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/${TARBALL}"

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
  echo "ERROR: lame source directory not found after extracting $TARBALL (expected $SRC_DIR)" >&2
  exit 1
fi

cd "$SRC_DIR"

# --disable-frontend drops the lame CLI, which pulls in libsndfile and termcap.
# FFmpeg links libmp3lame only.
./configure \
  --prefix="$PREFIX" \
  --enable-static \
  --disable-shared \
  --disable-frontend \
  --disable-gtktest \
  --with-pic

make -j"$PAR"
make install
