#!/usr/bin/env bash
set -euo pipefail
SRC=$1; PREFIX=$2; PAR=$3
if [[ ! -d "$SRC/freetype" ]]; then
  git clone --depth=1 https://github.com/freetype/freetype "$SRC/freetype"
fi
mkdir -p "$SRC/freetype/build" && cd "$SRC/freetype/build"
cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DFT_DISABLE_ZLIB=OFF -DFT_DISABLE_BZIP2=ON ..
ninja -j"$PAR" && ninja install