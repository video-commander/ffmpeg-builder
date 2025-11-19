#!/usr/bin/env bash
set -euo pipefail

SRC=$1
PREFIX=$2
PAR=$3

SVT_TAG=${SVT_TAG:-v2.2.1}  # pick a 2.x tag compatible with FFmpeg 7.1

if [[ ! -d "$SRC/SVT-AV1" ]]; then
  git clone --branch "$SVT_TAG" --depth 1 \
    https://gitlab.com/AOMediaCodec/SVT-AV1.git \
    "$SRC/SVT-AV1"
else
  cd "$SRC/SVT-AV1"
  git fetch --tags
  git checkout "$SVT_TAG"
fi

# Sanity check
if [[ ! -f "$SRC/SVT-AV1/CMakeLists.txt" ]]; then
  echo "ERROR: No CMakeLists.txt found in $SRC/SVT-AV1" >&2
  exit 1
fi

mkdir -p "$SRC/SVT-AV1/build"
cd "$SRC/SVT-AV1/build"

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_APPS=OFF \
  ..  # repo root

ninja -j"$PAR"
ninja install
