Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PROFILE_FILE = $env:PROFILE
if (-not $PROFILE_FILE) { $PROFILE_FILE = 'profiles/desktop-default.yml' }
$FFMPEG_VERSION = if ($env:FFMPEG_VERSION) { $env:FFMPEG_VERSION } else { (yq '.ffmpeg.version' $PROFILE_FILE) }
$ENABLE_NONFREE = if ($env:ENABLE_NONFREE) { $env:ENABLE_NONFREE } else { (yq '.ffmpeg.nonfree' $PROFILE_FILE) }

# Delegate to MSYS2 environment
& C:\msys64\usr\bin\bash -lc @"
set -euo pipefail
PREFIX="`$PWD/.build-cache/prefix"
SRC="`$PWD/.build-cache/src"
mkdir -p "`$PREFIX" "`$SRC"
export PKG_CONFIG_PATH="`$PREFIX/lib/pkgconfig"

# For Windows, prefer using mingw prebuilt libs to keep CI time reasonable
# (x264/x265/aom/svt-av1/opus/vpx are available via pacman)
pacman -Sy --noconfirm --needed \
  mingw-w64-x86_64-ffmpeg \
  mingw-w64-x86_64-x264 mingw-w64-x86_64-x265 \
  mingw-w64-x86_64-aom mingw-w64-x86_64-svt-av1 \
  mingw-w64-x86_64-opus mingw-w64-x86_64-libvpx

# Rebuild FFmpeg from source to control flags (links to mingw libs)
wget -q https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.gz -O `$SRC/ffmpeg.tar.gz
mkdir -p `$SRC/ffmpeg && tar -C `$SRC/ffmpeg --strip-components=1 -xzf `$SRC/ffmpeg.tar.gz
cd `$SRC/ffmpeg

./configure \
  --prefix="`$PREFIX" \
  --pkg-config=pkg-config \
  --pkg-config-flags="--static" \
  --target-os=mingw32 \
  --arch=x86_64 \
  --enable-gpl --enable-version3 \
  --enable-libx264 --enable-libx265 --enable-libaom --enable-libsvtav1 --enable-libvpx --enable-libopus \
  --disable-doc --disable-debug --enable-stripping --enable-static --disable-shared \
  `$( [[ "$ENABLE_NONFREE" == "true" || "$ENABLE_NONFREE" == "1" ]] && echo --enable-nonfree )

make -j`$(nproc)
make install

OUT_DIR="`$PWD/../../out/windows-x86_64"
rm -rf "`$OUT_DIR" && mkdir -p "`$OUT_DIR/bin" "`$OUT_DIR/LICENSES"
cp -av "`$PREFIX/bin/ffmpeg.exe" "`$OUT_DIR/bin/"
cp -av "`$PREFIX/bin/ffprobe.exe" "`$OUT_DIR/bin/" || true
"@
