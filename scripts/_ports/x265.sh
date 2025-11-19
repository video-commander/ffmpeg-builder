#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

SRC_DIR="$SRC/x265"
BUILD_DIR="$SRC_DIR/build"

echo ">>> Building x265 into $PREFIX"

# Clone x265 if needed
if [[ ! -d "$SRC_DIR" ]]; then
  git clone --depth=1 https://github.com/videolan/x265.git "$SRC_DIR"
fi

CML="$SRC_DIR/source/CMakeLists.txt"

# ---------------------------------------------------------------------
# Patch for modern CMake (macOS runner uses newer CMake versions)
# ---------------------------------------------------------------------
if [[ -f "$CML" ]]; then
  if ! grep -q "VC_PATCHED_FOR_MODERN_CMAKE" "$CML"; then
    echo "[patch] Fixing x265 CMakeLists for modern CMake..."
    cp "$CML" "$CML.bak"

    {
      echo ""
      echo "# VC_PATCHED_FOR_MODERN_CMAKE"
      echo "# Remove old cmake_policy settings that break new CMake"
    } >> "$CML"

    # macOS sed requires ''
    sed -i '' \
      -e 's/cmake_policy(SET CMP0025 OLD)//g' \
      -e 's/cmake_policy(SET CMP0054 OLD)//g' \
      "$CML"
  fi
else
  echo "ERROR: x265 CMakeLists.txt missing: $CML" >&2
  exit 1
fi

# ---------------------------------------------------------------------
# Build directory
# ---------------------------------------------------------------------
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo ">>> Configuring x265 with CMake..."

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF \
  -DENABLE_CLI=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  ../source

echo ">>> Building x265..."
ninja -j"$PAR"

echo ">>> Installing x265..."
ninja install

PC_DIR="$PREFIX/lib/pkgconfig"
PC_FILE="$PC_DIR/x265.pc"

mkdir -p "$PC_DIR"

if [[ ! -f "$PC_FILE" ]]; then
  echo "[info] No x265.pc installed by upstream — generating it"

  X265_VERSION="0"
  if [[ -f "$PREFIX/include/x265.h" ]]; then
    v=$(grep -E 'X265_BUILD|X265_VERSION' "$PREFIX/include/x265.h" | head -n1 || true)
    if [[ -n "$v" ]]; then
      X265_VERSION=$(echo "$v" | tr -cd '0-9.')
      [[ -z "$X265_VERSION" ]] && X265_VERSION="0"
    fi
  fi

  # Choose appropriate C++ runtime lib
  case "$(uname -s)" in
    Darwin*) CXX_LIB="-lc++" ;;
    *)       CXX_LIB="-lstdc++" ;;
  esac

  cat > "$PC_FILE" <<PC
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: x265
Description: H.265/HEVC video encoder
Version: $X265_VERSION
Libs: -L\${libdir} -lx265 -lm -lpthread $CXX_LIB
Cflags: -I\${includedir}
PC

  echo "[generated] $PC_FILE"
else
  echo "[ok] Using existing pkg-config file: $PC_FILE"
fi
