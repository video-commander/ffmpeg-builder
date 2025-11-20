#!/usr/bin/env bash
set -euo pipefail

SRC="$1"
PREFIX="$2"
PAR="$3"

# Normalize to absolute paths
mkdir -p "$SRC" "$PREFIX"
SRC="$(cd "$SRC" && pwd)"
PREFIX="$(cd "$PREFIX" && pwd)"

# VMAF version; allow "3.0.0" or "v3.0.0"
RAW_VMAF_VERSION="${PORT_VMAF_VERSION:-3.0.0}"
VMAF_VERSION_NO_V="${RAW_VMAF_VERSION#v}"   # 3.0.0
TAG="v${VMAF_VERSION_NO_V}"                # v3.0.0

TARBALL="${TAG}.tar.gz"
URL="https://github.com/Netflix/vmaf/archive/refs/tags/${TARBALL}"

echo ">>> vmaf ${TAG}: prefix=$PREFIX"
echo ">>> vmaf: download URL: $URL"

# ---------------------------------------------------------------------
# Download tarball if missing
# ---------------------------------------------------------------------
if [[ ! -f "$SRC/$TARBALL" ]]; then
  echo ">>> vmaf: downloading $TARBALL"
  curl -L "$URL" -o "$SRC/$TARBALL"
fi

# Validate archive
if ! tar -tf "$SRC/$TARBALL" >/dev/null 2>&1; then
  echo "ERROR: $TARBALL is not a valid tar archive" >&2
  exit 1
fi

# ---------------------------------------------------------------------
# Extract once and detect top-level directory
# ---------------------------------------------------------------------
TOPDIR=$(tar -tf "$SRC/$TARBALL" | head -n1 | cut -d/ -f1)

if [[ -z "$TOPDIR" ]]; then
  echo "ERROR: failed to detect top-level directory inside $TARBALL" >&2
  exit 1
fi

if [[ ! -d "$SRC/$TOPDIR" ]]; then
  echo ">>> vmaf: extracting $TARBALL"
  tar -xf "$SRC/$TARBALL" -C "$SRC"
fi

SRC_DIR="$SRC/$TOPDIR"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: vmaf source directory not found after extracting $TARBALL (expected $SRC_DIR)" >&2
  exit 1
fi

echo ">>> vmaf: using source dir: $SRC_DIR"

# ---------------------------------------------------------------------
# Build libvmaf with Meson (static only)
# ---------------------------------------------------------------------
LIBVMAF_SRC="$SRC_DIR/libvmaf"

if [[ ! -d "$LIBVMAF_SRC" ]]; then
  echo "ERROR: $LIBVMAF_SRC does not exist (libvmaf source dir not found)" >&2
  exit 1
fi

BUILD_DIR="$LIBVMAF_SRC/build-ffmpeg-builder"
rm -rf "$BUILD_DIR"

echo ">>> vmaf: configuring Meson build in $BUILD_DIR"

meson setup "$BUILD_DIR" "$LIBVMAF_SRC" \
  --prefix "$PREFIX" \
  --libdir lib \
  --buildtype release \
  --default-library=static

echo ">>> vmaf: building libvmaf..."
ninja -C "$BUILD_DIR" -j"$PAR"

echo ">>> vmaf: installing libvmaf..."
ninja -C "$BUILD_DIR" install

# ---------------------------------------------------------------------
# Synthetic libvmaf.pc for FFmpeg (static-friendly, with C++ stdlib)
# ---------------------------------------------------------------------
PC_DIR="$PREFIX/lib/pkgconfig"
PC_FILE="$PC_DIR/libvmaf.pc"

mkdir -p "$PC_DIR"

# Pick the right C++ stdlib flag for the host
CXX_LIB="-lstdc++"
case "$(uname -s)" in
  Darwin) CXX_LIB="-lc++" ;;
esac

cat > "$PC_FILE" <<PC
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libvmaf
Description: VMAF perceptual video quality assessment library
Version: ${VMAF_VERSION_NO_V}

# Add math + C++ runtime so FFmpeg's static link test passes
Libs: -L\${libdir} -lvmaf -lm ${CXX_LIB}
Cflags: -I\${includedir} -I\${includedir}/libvmaf
PC

echo ">>> vmaf ${TAG}: synthetic libvmaf.pc written to $PC_FILE"
echo ">>> vmaf ${TAG}: done"
