#!/usr/bin/env bash
set -euo pipefail
SRC=$1; PREFIX=$2; PAR=$3
if [[ ! -d "$SRC/libvpx" ]]; then
  git clone --depth=1 https://chromium.googlesource.com/webm/libvpx "$SRC/libvpx"
fi
cd "$SRC/libvpx"
./configure --prefix="$PREFIX" --disable-examples --disable-tools --disable-docs --enable-vp9-highbitdepth --enable-static --disable-shared
make -j"$PAR" && make install