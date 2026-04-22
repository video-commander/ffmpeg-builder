#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

X265_VERSION="${PORT_X265_VERSION:-3.6}"
TARBALL="x265_${X265_VERSION}.tar.gz"
URL="https://bitbucket.org/multicoreware/x265_git/downloads/${TARBALL}"

mkdir -p "$SRC"

# Download source tarball if not already present
if [[ ! -f "$SRC/$TARBALL" ]]; then
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Verify tarball integrity
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    SIZE=$(stat -f%z "$SRC/$TARBALL" 2>/dev/null)
  else
    SIZE=$(stat -c%s "$SRC/$TARBALL" 2>/dev/null)
  fi
  echo "ERROR: $TARBALL is not a valid tar archive (size: $SIZE)" >&2
  exit 1
fi

# Extract source if not already done
if [[ ! -d "$SRC/x265_${X265_VERSION}" && ! -d "$SRC/x265-${X265_VERSION}" ]]; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

# Find source directory
if   [[ -d "$SRC/x265_${X265_VERSION}" ]]; then
  SRC_DIR="$SRC/x265_${X265_VERSION}"
elif [[ -d "$SRC/x265-${X265_VERSION}" ]]; then
  SRC_DIR="$SRC/x265-${X265_VERSION}"
else
  echo "ERROR: x265 source directory not found after extracting $TARBALL" >&2
  exit 1
fi

BUILD_DIR="$SRC_DIR/build"
CML="$SRC_DIR/source/CMakeLists.txt"

# Patch CMakeLists.txt to remove old CMake policy settings
if [[ -f "$CML" ]] && ! grep -q "VC_PATCHED_FOR_MODERN_CMAKE" "$CML"; then
  cp "$CML" "$CML.bak"

  {
    echo ""
    echo "# VC_PATCHED_FOR_MODERN_CMAKE"
  } >> "$CML"

  # BSD/macOS vs GNU sed
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' \
      -e 's/cmake_policy(SET CMP0025 OLD)//g' \
      -e 's/cmake_policy(SET CMP0054 OLD)//g' \
      "$CML"
  else
    sed -i \
      -e 's/cmake_policy(SET CMP0025 OLD)//g' \
      -e 's/cmake_policy(SET CMP0054 OLD)//g' \
      "$CML"
  fi
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure extra flags per platform
EXTRA_X265_FLAGS=()
case "$(uname -s)" in
  Darwin*)
    # Assembly causes linker issues with Xcode 26+
    EXTRA_X265_FLAGS+=(-DENABLE_ASSEMBLY=OFF)
    [[ "$(uname -m)" == "arm64" ]] && EXTRA_X265_FLAGS+=(-DENABLE_NEON=OFF)
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # cmake 4.x try-compile is broken on MSYS2/MINGW64; skip the check since
    # we know gcc works (x264 already compiled successfully before this step)
    EXTRA_X265_FLAGS+=(-DCMAKE_C_COMPILER_WORKS=1 -DCMAKE_CXX_COMPILER_WORKS=1)
    ;;
esac

# Configure and build
cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF \
  -DENABLE_CLI=OFF \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  ${EXTRA_X265_FLAGS[@]+"${EXTRA_X265_FLAGS[@]}"} \
  ../source

ninja -j"$PAR"
ninja install

# Create pkg-config file
PC_DIR="$PREFIX/lib/pkgconfig"
PC_FILE="$PC_DIR/x265.pc"
mkdir -p "$PC_DIR"

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
Version: ${X265_VERSION}
Libs: -L\${libdir} -lx265 -lm -lpthread ${CXX_LIB}
Cflags: -I\${includedir}
PC
