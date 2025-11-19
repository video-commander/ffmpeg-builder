#!/usr/bin/env bash
set -euo pipefail
SRC=$1; PREFIX=$2; PAR=$3
if [[ ! -d "$SRC/fdk-aac" ]]; then
  git clone --depth=1 https://github.com/mstorsjo/fdk-aac "$SRC/fdk-aac"
fi
cd "$SRC/fdk-aac"
autoreconf -fiv
./configure --prefix="$PREFIX" --disable-shared --enable-static
make -j"$PAR" && make install