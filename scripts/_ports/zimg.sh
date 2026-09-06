#!/usr/bin/env bash
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/util.sh"

SRC="$1"
PREFIX="$2"
PAR="$3"

# zimg vendors graphengine as a git submodule, and GitHub's release tarballs
# omit submodule contents — a tarball build fails at autogen. Clone with
# --recursive instead.
ZIMG_VERSION="${PORT_ZIMG_VERSION:-release-3.0.6}"
SRC_DIR="$SRC/zimg"

mkdir -p "$SRC"

if [[ ! -d "$SRC_DIR" ]]; then
  git clone --branch "$ZIMG_VERSION" --depth=1 --recursive \
    https://github.com/sekrit-twc/zimg.git "$SRC_DIR"
fi

cd "$SRC_DIR"

./autogen.sh

./configure \
  --prefix="$PREFIX" \
  --enable-static \
  --disable-shared \
  --with-pic

make -j"$PAR"
make install

install_license "$PREFIX" "zimg" "$SRC_DIR"
