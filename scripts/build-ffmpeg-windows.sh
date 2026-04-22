#!/usr/bin/env bash
set -euo pipefail
export PATH="/mingw64/bin:/usr/bin:${PATH:-}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PREFIX="$PWD/.build-cache/prefix"
SRC="$PWD/.build-cache/src"
mkdir -p "$PREFIX" "$SRC"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

PAR=$(nproc)

# Build codec ports from source as static libraries so ffmpeg.exe has no
# runtime DLL dependencies on codec libs.
pushd "$SCRIPT_DIR/_ports" >/dev/null
  ./x264.sh "$SRC" "$PREFIX" "$PAR"
  ./x265.sh "$SRC" "$PREFIX" "$PAR"
  ./aom.sh  "$SRC" "$PREFIX" "$PAR"
  ./vpx.sh  "$SRC" "$PREFIX" "$PAR"
  ./opus.sh "$SRC" "$PREFIX" "$PAR"
popd >/dev/null

# Install NVIDIA codec headers (header-only; NVENC/NVDEC load nvidia drivers at runtime)
if [[ ! -d "$SRC/nv-codec-headers" ]]; then
  git clone --depth=1 https://github.com/FFmpeg/nv-codec-headers "$SRC/nv-codec-headers"
fi
make -C "$SRC/nv-codec-headers" install PREFIX="$PREFIX"

# Install AMD AMF headers (header-only; AMF encoder loads AMD drivers at runtime)
AMF_TAG="v1.4.35"
AMF_DIR="$SRC/AMF-${AMF_TAG}"
if [[ ! -d "$AMF_DIR" ]]; then
  mkdir -p "$AMF_DIR"
  curl -sL "https://github.com/GPUOpen-LibrariesAndSDKs/AMF/archive/refs/tags/${AMF_TAG}.tar.gz" \
    | tar -xz -C "$SRC"
fi
mkdir -p "$PREFIX/include/AMF"
cp -r "$AMF_DIR/amf/public/include/." "$PREFIX/include/AMF/"

wget -q "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" -O "$SRC/ffmpeg.tar.gz"
mkdir -p "$SRC/ffmpeg" && tar -C "$SRC/ffmpeg" --strip-components=1 -xzf "$SRC/ffmpeg.tar.gz"
cd "$SRC/ffmpeg"

./configure \
  --prefix="$PREFIX" \
  --pkg-config=pkg-config \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$PREFIX/include" \
  --extra-ldflags="-L$PREFIX/lib -static -static-libgcc -static-libstdc++ -Wl,--start-group" \
  --extra-ldexeflags="-Wl,--end-group" \
  --target-os=mingw32 \
  --arch=x86_64 \
  --enable-gpl --enable-version3 \
  --enable-libx264 --enable-libx265 --enable-libaom --enable-libvpx --enable-libopus \
  --enable-d3d11va --enable-dxva2 --enable-mediafoundation \
  --enable-nvenc --enable-nvdec --enable-cuda-llvm \
  --enable-amf \
  --disable-doc --disable-debug --enable-stripping --enable-static --disable-shared \
  $( [[ "${ENABLE_NONFREE:-false}" == "true" ]] && echo --enable-nonfree )

make -j"$PAR"
make install

OUT_DIR="$PWD/../../out/windows-x86_64"
rm -rf "$OUT_DIR" && mkdir -p "$OUT_DIR/bin"
cp -av "$PREFIX/bin/ffmpeg.exe" "$OUT_DIR/bin/"
cp -av "$PREFIX/bin/ffprobe.exe" "$OUT_DIR/bin/" || true
