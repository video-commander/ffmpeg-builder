#!/usr/bin/env bash
set -euo pipefail
export PATH="/mingw64/bin:/usr/bin:${PATH:-}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PREFIX="$PWD/.build-cache/prefix"
SRC="$PWD/.build-cache/src"
mkdir -p "$PREFIX" "$SRC"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

PAR=$(nproc)

# Ensure meson is available (required by vmaf and fribidi ports)
if ! command -v meson >/dev/null 2>&1; then
  pip3 install --user meson || true
  export PATH="$HOME/.local/bin:$PATH"
fi

# Build all codec/library ports from source as static libraries,
# mirroring the macOS build-ffmpeg.sh feature set.
pushd "$SCRIPT_DIR/_ports" >/dev/null
  # Foundation libs first (others depend on these)
  ./zlib.sh     "$SRC" "$PREFIX" "$PAR"
  ./libiconv.sh "$SRC" "$PREFIX" "$PAR"
  ./xz.sh       "$SRC" "$PREFIX" "$PAR"
  # Codec and feature libraries
  ./x264.sh     "$SRC" "$PREFIX" "$PAR"
  ./x265.sh     "$SRC" "$PREFIX" "$PAR"
  ./aom.sh      "$SRC" "$PREFIX" "$PAR"
  ./svtav1.sh   "$SRC" "$PREFIX" "$PAR"
  ./vpx.sh      "$SRC" "$PREFIX" "$PAR"
  ./opus.sh     "$SRC" "$PREFIX" "$PAR"
  ./openssl.sh  "$SRC" "$PREFIX" "$PAR"
  ./srt.sh      "$SRC" "$PREFIX" "$PAR"
  ./vmaf.sh     "$SRC" "$PREFIX" "$PAR"
  ./freetype.sh "$SRC" "$PREFIX" "$PAR"
  ./fribidi.sh  "$SRC" "$PREFIX" "$PAR"
  ./harfbuzz.sh "$SRC" "$PREFIX" "$PAR"
  ./libass.sh   "$SRC" "$PREFIX" "$PAR"
popd >/dev/null

# Install NVIDIA codec headers (header-only; NVENC/NVDEC load nvidia drivers at runtime)
if [[ ! -d "$SRC/nv-codec-headers" ]]; then
  git clone --depth=1 https://github.com/FFmpeg/nv-codec-headers "$SRC/nv-codec-headers"
fi
make -C "$SRC/nv-codec-headers" install PREFIX="$PREFIX"

# Install AMD AMF headers (header-only; AMF encoder loads AMD drivers at runtime)
if [[ ! -d "$SRC/AMF" ]]; then
  git clone --depth=1 https://github.com/GPUOpen-LibrariesAndSDKs/AMF "$SRC/AMF"
fi
mkdir -p "$PREFIX/include/AMF"
cp -r "$SRC/AMF/amf/public/include/." "$PREFIX/include/AMF/"

wget -q "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" -O "$SRC/ffmpeg.tar.gz"
mkdir -p "$SRC/ffmpeg" && tar -C "$SRC/ffmpeg" --strip-components=1 -xzf "$SRC/ffmpeg.tar.gz"
cd "$SRC/ffmpeg"

./configure \
  --prefix="$PREFIX" \
  --pkg-config=pkg-config \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$PREFIX/include" \
  --extra-ldflags="-L$PREFIX/lib -static-libgcc -static-libstdc++ -Wl,-Bstatic -Wl,--start-group" \
  --extra-ldexeflags="-Wl,--end-group -Wl,-Bdynamic" \
  --extra-libs="-lm" \
  --target-os=mingw32 \
  --arch=x86_64 \
  --enable-gpl --enable-version3 \
  --enable-openssl \
  --enable-zlib --enable-lzma --enable-iconv \
  --disable-bzlib \
  --disable-w32threads --enable-pthreads \
  --enable-libx264 --enable-libx265 --enable-libaom --enable-libsvtav1 \
  --enable-libvpx --enable-libopus \
  --enable-libsrt --enable-libvmaf --enable-libass \
  --enable-d3d11va --enable-dxva2 --enable-mediafoundation \
  --enable-nvenc --enable-nvdec \
  --enable-amf \
  --disable-doc --disable-debug --enable-stripping --enable-static --disable-shared \
  $( [[ "${ENABLE_NONFREE:-false}" == "true" ]] && echo --enable-nonfree )

make -j"$PAR"
make install

OUT_DIR="$PWD/../../out/windows-x86_64"
rm -rf "$OUT_DIR" && mkdir -p "$OUT_DIR/bin"
cp -av "$PREFIX/bin/ffmpeg.exe" "$OUT_DIR/bin/"
cp -av "$PREFIX/bin/ffprobe.exe" "$OUT_DIR/bin/" || true
