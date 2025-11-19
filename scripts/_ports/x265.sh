#!/usr/bin/env bash
set -euo pipefail

SRC=$1
PREFIX=$2
PAR=$3

if [[ ! -d "$SRC/x265" ]]; then
  git clone --depth=1 https://github.com/videolan/x265.git "$SRC/x265"
fi

CML="$SRC/x265/source/CMakeLists.txt"

# Optional patch – harmless even if we keep it
if [[ -f "$CML" ]]; then
  if ! grep -q "VC_PATCHED_FOR_MODERN_CMAKE" "$CML"; then
    echo "Patching x265 CMakeLists.txt for modern CMake..."
    cp "$CML" "$CML.bak"

    printf "\n# VC_PATCHED_FOR_MODERN_CMAKE\n" >> "$CML"

    sed -i '' \
      -e 's/cmake_policy(SET CMP0025 OLD)//g' \
      -e 's/cmake_policy(SET CMP0054 OLD)//g' \
      "$CML"
  fi
else
  echo "ERROR: Cannot find x265 CMakeLists at $CML" >&2
  exit 1
fi

# Out-of-source build: CMakeLists.txt lives in source/
mkdir -p "$SRC/x265/build"
cd "$SRC/x265/build"

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF \
  -DENABLE_CLI=ON \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  ../source

ninja -j"$PAR"
ninja install
