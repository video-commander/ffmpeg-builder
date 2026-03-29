Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$env:MSYSTEM = "MINGW64"
& "C:\msys64\usr\bin\bash.exe" -lc @"
set -euo pipefail
PREFIX="`$PWD/.build-cache/prefix"
SRC="`$PWD/.build-cache/src"
mkdir -p "`$PREFIX" "`$SRC"
export PKG_CONFIG_PATH="`$PREFIX/lib/pkgconfig"

wget -q https://ffmpeg.org/releases/ffmpeg-$($env:FFMPEG_VERSION).tar.gz -O `$SRC/ffmpeg.tar.gz
mkdir -p `$SRC/ffmpeg && tar -C `$SRC/ffmpeg --strip-components=1 -xzf `$SRC/ffmpeg.tar.gz
cd `$SRC/ffmpeg

./configure \
  --prefix="`$PREFIX" \
  --pkg-config=pkg-config \
  --pkg-config-flags="--static" \
  --target-os=mingw32 \
  --arch=x86_64 \
  --enable-gpl --enable-version3 \
  --enable-libx264 --enable-libx265 --enable-libaom --enable-libvpx --enable-libopus \
  --disable-doc --disable-debug --enable-stripping --enable-static --disable-shared \
  --extra-ldflags="-Wl,--start-group" --extra-ldexeflags="-Wl,--end-group" \
  `$( [[ "$($env:ENABLE_NONFREE)" == "true" ]] && echo --enable-nonfree )

make -j`$(nproc)
make install

OUT_DIR="`$PWD/../../out/windows-x86_64"
rm -rf "`$OUT_DIR" && mkdir -p "`$OUT_DIR/bin"
cp -av "`$PREFIX/bin/ffmpeg.exe" "`$OUT_DIR/bin/"
cp -av "`$PREFIX/bin/ffprobe.exe" "`$OUT_DIR/bin/" || true
"@
