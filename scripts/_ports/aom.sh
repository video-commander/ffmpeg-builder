#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

AOM_VERSION="${PORT_AOM_VERSION:-v3.9.0}"
SRC_DIR="$SRC/aom"
BUILD_DIR="$SRC_DIR/build"

mkdir -p "$SRC"

# Clone the AOM repository if the source directory does not already exist
if [[ ! -d "$SRC_DIR" ]]; then
  git clone --branch "$AOM_VERSION" --depth=1 https://aomedia.googlesource.com/aom "$SRC_DIR"
fi

# Create and enter the build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# On MinGW, aom's bundled libwebm uses uint32_t/uint64_t without including
# <cstdint>, which other toolchains pull in implicitly but MinGW does not.
EXTRA_CXX_FLAGS=""
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) EXTRA_CXX_FLAGS="-include cstdint" ;; esac

# Configure and build AOM
cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_TESTS=OFF \
  -DENABLE_DOCS=OFF \
  -DENABLE_EXAMPLES=OFF \
  -DAOM_TARGET_CPU=generic \
  ${EXTRA_CXX_FLAGS:+-DCMAKE_CXX_FLAGS="$EXTRA_CXX_FLAGS"} \
  ../

ninja -j"$PAR"
ninja install
