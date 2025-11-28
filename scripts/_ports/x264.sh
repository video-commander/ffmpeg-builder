#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

X264_VERSION="${PORT_X264_VERSION:-stable}"

SRC_DIR="$SRC/x264"

mkdir -p "$SRC"

# Clone the x264 repository if the source directory does not already exist
if [[ ! -d "$SRC_DIR" ]]; then
  git clone https://code.videolan.org/videolan/x264.git "$SRC_DIR"
fi

cd "$SRC_DIR"
git fetch --tags

# Checkout the specified version
if [[ "$X264_VERSION" != "stable" ]]; then
  git checkout "$X264_VERSION"
fi

# Configure, build, and install x264
HOST_FLAG=()
if [[ "$(uname -s)" == "Darwin" ]]; then
  HOST_FLAG+=(--host="$(uname -m)-apple-darwin")
fi
./configure \
  --prefix="$PREFIX" \
  --enable-static \
  --enable-pic \
  --disable-opencl \
  --disable-cli \
  "${HOST_FLAG[@]}"

make -j"$PAR"
make install
