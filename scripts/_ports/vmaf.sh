#!/usr/bin/env bash
set -euo pipefail
SRC=$1; PREFIX=$2; PAR=$3
if [[ ! -d "$SRC/vmaf" ]]; then
  git clone --depth=1 https://github.com/Netflix/vmaf "$SRC/vmaf"
fi
make -C "$SRC/vmaf/libvmaf" -j "$PAR" libvmaf.a
make -C "$SRC/vmaf/libvmaf" install PREFIX="$PREFIX"
# Models (optional, handy for runtime)
mkdir -p "$PREFIX/share/model/vmaf"
cp -av "$SRC/vmaf/model"/* "$PREFIX/share/model/vmaf/" || true