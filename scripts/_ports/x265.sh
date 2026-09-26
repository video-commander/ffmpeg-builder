#!/usr/bin/env bash
set -euo pipefail

# shared helpers (fetch_url: retries transient download failures)
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/util.sh"

SRC="$1"
PREFIX="$2"
PAR="$3"

X265_VERSION="${PORT_X265_VERSION:-4.2}"
TARBALL="x265_${X265_VERSION}.tar.gz"
URL="https://bitbucket.org/multicoreware/x265_git/downloads/${TARBALL}"

mkdir -p "$SRC"

# Download source tarball if not already present
if [[ ! -f "$SRC/$TARBALL" ]]; then
  fetch_url "$URL" "$SRC/$TARBALL"
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

# Configure extra flags for macOS (assembly causes linker issues with Xcode 26+)
EXTRA_X265_FLAGS=()
if [[ "$(uname -s)" == "Darwin" ]]; then
  EXTRA_X265_FLAGS+=(-DENABLE_ASSEMBLY=OFF)
  [[ "$(uname -m)" == "arm64" ]] && EXTRA_X265_FLAGS+=(-DENABLE_NEON=OFF)
fi

COMMON_FLAGS=(
  -G Ninja
  -DENABLE_SHARED=OFF
  -DENABLE_CLI=OFF
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  ${EXTRA_X265_FLAGS[@]+"${EXTRA_X265_FLAGS[@]}"}
)

# Multilib: the 10- and 12-bit builds are linked into the 8-bit one, so one
# libx265.a encodes all three depths and FFmpeg's libx265 offers the 10/12-bit
# pixel formats. An 8-bit-only libx265 silently downconverts 10-bit input.
# Same layout as x265's own build/linux/multilib.sh.
build_depth() {
  local dir="$1"; shift
  rm -rf "$dir"
  mkdir -p "$dir"
  (cd "$dir" && cmake "${COMMON_FLAGS[@]}" "$@" ../source && ninja -j"$PAR")
}

build_depth "$SRC_DIR/build-12bit" -DHIGH_BIT_DEPTH=ON -DMAIN12=ON -DEXPORT_C_API=OFF
build_depth "$SRC_DIR/build-10bit" -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF

BUILD_DIR="$SRC_DIR/build-8bit"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cp "$SRC_DIR/build-10bit/libx265.a" "$BUILD_DIR/libx265_main10.a"
cp "$SRC_DIR/build-12bit/libx265.a" "$BUILD_DIR/libx265_main12.a"
cd "$BUILD_DIR"
cmake "${COMMON_FLAGS[@]}" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DEXTRA_LIB="x265_main10.a;x265_main12.a" \
  -DEXTRA_LINK_FLAGS=-L. \
  -DLINKED_10BIT=ON \
  -DLINKED_12BIT=ON \
  ../source
ninja -j"$PAR"

ninja install

# Merge the three depths into the one archive FFmpeg links, replacing the
# 8-bit-only libx265.a that `ninja install` put in the prefix.
if [[ "$(uname -s)" == "Darwin" ]]; then
  libtool -static -o libx265_multilib.a libx265.a libx265_main10.a libx265_main12.a
else
  ar -M <<MRI
CREATE libx265_multilib.a
ADDLIB libx265.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
MRI
fi
cp libx265_multilib.a "$PREFIX/lib/libx265.a"

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

install_license "$PREFIX" "x265" "$SRC_DIR"
