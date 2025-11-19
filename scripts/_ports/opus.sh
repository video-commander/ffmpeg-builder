#!/usr/bin/env bash
set -euo pipefail
SRC=$1; PREFIX=$2; PAR=$3
if [[ ! -d "$SRC/opus" ]]; then
  curl -L https://downloads.xiph.org/releases/opus/opus-1.5.1.tar.gz -o "$SRC/opus.tar.gz"
  tar -C "$SRC" -xzf "$SRC/opus.tar.gz"
  mv "$SRC/opus-1.5.1" "$SRC/opus"
fi
cd "$SRC/opus"
./configure --prefix="$PREFIX" --disable-shared --enable-static
make -j"$PAR" && make install