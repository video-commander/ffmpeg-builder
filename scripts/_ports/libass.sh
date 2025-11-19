#!/usr/bin/env bash
set -euo pipefail
SRC=$1; PREFIX=$2; PAR=$3
if [[ ! -d "$SRC/libass" ]]; then
  git clone --depth=1 https://github.com/libass/libass "$SRC/libass"
fi
meson setup "$SRC/libass/build" "$SRC/libass" --prefix="$PREFIX" --buildtype=release -Ddefault_library=static \
  -Dfontconfig=disabled -Denca=disabled
meson compile -C "$SRC/libass/build" -j "$PAR" && meson install -C "$SRC/libass/build"