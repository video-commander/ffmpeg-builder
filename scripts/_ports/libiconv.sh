#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

LIBICONV_VERSION="${PORT_LIBICONV_VERSION:-1.17}"
TARBALL="libiconv-${LIBICONV_VERSION}.tar.gz"
URL="https://ftp.gnu.org/pub/gnu/libiconv/${TARBALL}"

if [[ ! -f "$SRC/$TARBALL" ]]; then
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

TOPDIR=$(tar -tf "$SRC/$TARBALL" | head -n1 | cut -d/ -f1 || true)
if [[ -z "$TOPDIR" ]]; then
  echo "ERROR: failed to detect top-level directory inside $TARBALL" >&2
  exit 1
fi

if [[ ! -d "$SRC/$TOPDIR" ]]; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

BUILD_DIR="$SRC/$TOPDIR/build-ffmpeg-builder"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# canonical_zos.h uses (int)(long)& casts that trigger -Wpointer-to-int-cast as
# an error on GCC 15; suppress the warning so the build doesn't fail.
CFLAGS="-Wno-pointer-to-int-cast" \
"$SRC/$TOPDIR/configure" \
  --prefix="$PREFIX" \
  --enable-extra-encodings \
  --disable-shared \
  --enable-static

make -j"$PAR"
make install
