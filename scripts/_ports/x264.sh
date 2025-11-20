#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

X264_VERSION="${PORT_X264_VERSION:-stable}"

SRC_DIR="$SRC/x264"

mkdir -p "$SRC"

if [[ ! -d "$SRC_DIR" ]]; then
  git clone https://code.videolan.org/videolan/x264.git "$SRC_DIR"
fi

cd "$SRC_DIR"
git fetch --tags

if [[ "$X264_VERSION" != "stable" ]]; then
  git checkout "$X264_VERSION"
fi

./configure \
  --prefix="$PREFIX" \
  --enable-static \
  --enable-pic \
  --disable-opencl \
  --disable-cli \
  --host="$(uname -m)-apple-darwin"

make -j"$PAR"
make install
