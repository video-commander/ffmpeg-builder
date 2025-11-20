#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

# Version comes from env/profile, default 3.6
X265_VERSION="${PORT_X265_VERSION:-3.6}"

TARBALL="x265_${X265_VERSION}.tar.gz"
URL="https://bitbucket.org/multicoreware/x265_git/downloads/${TARBALL}"

echo ">>> x265 ${X265_VERSION}: prefix=$PREFIX"
echo ">>> x265: download URL: $URL"

mkdir -p "$SRC"

# ---------------------------------------------------------------------
# Download and extract release tarball from Bitbucket
# ---------------------------------------------------------------------
if [[ ! -f "$SRC/$TARBALL" ]]; then
  echo ">>> downloading $TARBALL"
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Extract once
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive (size: $(stat -f%z "$SRC/$TARBALL" 2>/dev/null || stat -c%s "$SRC/$TARBALL"))" >&2
  exit 1
fi

# Only extract if we don't already have a source dir
if [[ ! -d "$SRC/x265_${X265_VERSION}" && ! -d "$SRC/x265-${X265_VERSION}" ]]; then
  echo ">>> extracting $TARBALL"
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

# Handle both possible directory names
if   [[ -d "$SRC/x265_${X265_VERSION}" ]]; then
  SRC_DIR="$SRC/x265_${X265_VERSION}"
elif [[ -d "$SRC/x265-${X265_VERSION}" ]]; then
  SRC_DIR="$SRC/x265-${X265_VERSION}"
else
  echo "ERROR: x265 source directory not found after extracting $TARBALL" >&2
  exit 1
fi

BUILD_DIR="$SRC_DIR/build"

echo ">>> x265: using source dir: $SRC_DIR"

CML="$SRC_DIR/source/CMakeLists.txt"

# ---------------------------------------------------------------------
# Patch CMakeLists for modern CMake (remove OLD policies once)
# ---------------------------------------------------------------------
if [[ -f "$CML" ]] && ! grep -q "VC_PATCHED_FOR_MODERN_CMAKE" "$CML"; then
  echo ">>> patching x265 CMakeLists for modern CMake"
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

# ---------------------------------------------------------------------
# Configure & build (CLI enabled so install rules run)
# ---------------------------------------------------------------------
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Extra flags for problematic platforms
EXTRA_X265_FLAGS=()

# On macOS arm64, disable ASM/NEON to avoid unresolved NEON symbols
if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]; then
  echo ">>> x265: disabling assembly on macOS arm64 (NEON primitives cause link issues)"
  EXTRA_X265_FLAGS+=(
    -DENABLE_ASSEMBLY=OFF
    -DENABLE_NEON=OFF
  )
fi

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF \
  -DENABLE_CLI=ON \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  "${EXTRA_X265_FLAGS[@]}" \
  ../source

ninja -j"$PAR"
ninja install

# Remove CLI – we only want the library in the toolchain
rm -f "$PREFIX/bin/x265" || true

# ---------------------------------------------------------------------
# Generate deterministic pkg-config with real version
# ---------------------------------------------------------------------
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

echo ">>> x265 ${X265_VERSION}: pkg-config generated at $PC_FILE"
echo ">>> x265 ${X265_VERSION}: done"
