#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

# Normalize to absolute paths
mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

RAW_VMAF_VERSION="${PORT_VMAF_VERSION:-3.0.0}"
VMAF_VERSION_NO_V="${RAW_VMAF_VERSION#v}"
TAG="v${VMAF_VERSION_NO_V}"

# Download and extract VMAF source code
TARBALL="${TAG}.tar.gz"
URL="https://github.com/Netflix/vmaf/archive/refs/tags/${TARBALL}"

if [[ ! -f "$SRC/$TARBALL" ]]; then
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Verify that the tarball is valid
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

# Extract the tarball if the source directory does not already exist
TOPDIR=$(tar -tf "$SRC/$TARBALL" | head -n1 | cut -d/ -f1)
if [[ -z "$TOPDIR" ]]; then
  echo "ERROR: failed to detect top-level directory inside $TARBALL" >&2
  exit 1
fi

# Extract the tarball if the source directory does not already exist
if [[ ! -d "$SRC/$TOPDIR" ]]; then
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

SRC_DIR="$SRC/$TOPDIR"
if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: vmaf source directory not found after extracting $TARBALL (expected $SRC_DIR)" >&2
  exit 1
fi
LIBVMAF_SRC="$SRC_DIR/libvmaf"

if [[ ! -d "$LIBVMAF_SRC" ]]; then
  echo "ERROR: $LIBVMAF_SRC does not exist (libvmaf source dir not found)" >&2
  exit 1
fi

BUILD_DIR="$LIBVMAF_SRC/build-ffmpeg-builder"
rm -rf "$BUILD_DIR"

# Configure, build, and install libvmaf
meson setup "$BUILD_DIR" "$LIBVMAF_SRC" \
  --prefix "$PREFIX" \
  --libdir lib \
  --buildtype release \
  --default-library=static

ninja -C "$BUILD_DIR" -j"$PAR"
ninja -C "$BUILD_DIR" install

PC_DIR="$PREFIX/lib/pkgconfig"
PC_FILE="$PC_DIR/libvmaf.pc"
mkdir -p "$PC_DIR"

CXX_LIB="-lstdc++"
case "$(uname -s)" in
  Darwin) CXX_LIB="-lc++" ;;
esac

# Create the pkg-config file for libvmaf
cat > "$PC_FILE" <<PC
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libvmaf
Description: VMAF perceptual video quality assessment library
Version: ${VMAF_VERSION_NO_V}

Libs: -L\${libdir} -lvmaf -lm ${CXX_LIB}
Cflags: -I\${includedir} -I\${includedir}/libvmaf
PC
