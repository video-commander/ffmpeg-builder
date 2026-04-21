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

wget -q "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" -O "$SRC/ffmpeg.tar.gz"
mkdir -p "$SRC/ffmpeg" && tar -C "$SRC/ffmpeg" --strip-components=1 -xzf "$SRC/ffmpeg.tar.gz"
cd "$SRC/ffmpeg"

./configure \
  --prefix="$PREFIX" \
  --pkg-config=pkg-config \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$PREFIX/include" \
  --extra-ldflags="-L$PREFIX/lib -Wl,--start-group" \
  --extra-ldexeflags="-Wl,--end-group" \
  --target-os=mingw32 \
  --arch=x86_64 \
  --enable-gpl --enable-version3 \
  --enable-libx264 --enable-libx265 --enable-libaom --enable-libvpx --enable-libopus \
  --disable-doc --disable-debug --enable-stripping --enable-static --disable-shared \
  $( [[ "${ENABLE_NONFREE:-false}" == "true" ]] && echo --enable-nonfree )

make -j"$PAR"
make install

OUT_DIR="$PWD/../../out/windows-x86_64"
rm -rf "$OUT_DIR" && mkdir -p "$OUT_DIR/bin"
cp -av "$PREFIX/bin/ffmpeg.exe" "$OUT_DIR/bin/"
cp -av "$PREFIX/bin/ffprobe.exe" "$OUT_DIR/bin/" || true
