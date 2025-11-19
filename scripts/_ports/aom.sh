#!/usr/bin/env bash
set -euo pipefail
SRC=$1; PREFIX=$2; PAR=$3
if [[ ! -d "$SRC/aom" ]]; then
  git clone --depth=1 https://aomedia.googlesource.com/aom "$SRC/aom"
fi
mkdir -p "$SRC/aom/build" && cd "$SRC/aom/build"
cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=OFF -DENABLE_TESTS=OFF ..
ninja -j"$PAR" && ninja install