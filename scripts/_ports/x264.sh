#!/usr/bin/env bash
set -euo pipefail
SRC=$1; PREFIX=$2; PAR=$3
if [[ ! -d "$SRC/x264" ]]; then
  git clone --depth=1 https://code.videolan.org/videolan/x264.git "$SRC/x264"
fi
cd "$SRC/x264"
./configure --prefix="$PREFIX" --enable-static --disable-opencl
make -j"$PAR"
make install