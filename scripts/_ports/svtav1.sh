#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

SVTAV1_VERSION="${PORT_SVTAV1_VERSION:-v2.2.1}"
SRC_DIR="$SRC/SVT-AV1"
BUILD_DIR="$SRC_DIR/build"

mkdir -p "$SRC"

if [[ ! -d "$SRC_DIR" ]]; then
  git clone --branch "$SVTAV1_VERSION" --depth=1 https://gitlab.com/AOMediaCodec/SVT-AV1.git "$SRC_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_APPS=OFF \
  ../

ninja -j"$PAR"
ninja install
