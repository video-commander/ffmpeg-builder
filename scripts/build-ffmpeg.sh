#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
. "$SCRIPT_DIR/util.sh"
. "$SCRIPT_DIR/common.sh"

# Resolve profile path to absolute
PROFILE_PATH=${PROFILE:-profiles/default.yml}
if [[ "$PROFILE_PATH" = /* ]]; then
  PROFILE_FILE="$PROFILE_PATH"
else
  PROFILE_FILE="$ROOT_DIR/$PROFILE_PATH"
fi

FFMPEG_VERSION=${FFMPEG_VERSION:-$(yq '.ffmpeg.version' "$PROFILE_FILE")}
ENABLE_NONFREE=${ENABLE_NONFREE:-$(yq '.ffmpeg.nonfree' "$PROFILE_FILE")}
PARALLEL=${PARALLEL:-$(yq '.system.parallel' "$PROFILE_FILE")}

# Resolve per-port versions (with env override + profile fallback)
PORT_X264_VERSION=$(port_version x264 "stable")
PORT_X265_VERSION=$(port_version x265 "4.2")
PORT_AOM_VERSION=$(port_version aom "v3.15.0")
PORT_SVTAV1_VERSION=$(port_version svtav1 "v4.2.0")
PORT_VPX_VERSION=$(port_version vpx "v1.17.0")
PORT_OPUS_VERSION=$(port_version opus "v1.5.2")
# OpenSSL 3.5 is the current LTS line. 4.x is released but is not what FFmpeg
# 9.x is tested against upstream.
PORT_OPENSSL_VERSION=$(port_version openssl "3.5.8")
PORT_SRT_VERSION=$(port_version srt "v1.5.7")
PORT_VMAF_VERSION=$(port_version vmaf "v3.2.0")
PORT_LIBASS_VERSION=$(port_version libass "0.17.5")
PORT_FREETYPE_VERSION=$(port_version freetype "VER-2-14-3")
PORT_FRIBIDI_VERSION=$(port_version fribidi "v1.0.16")
PORT_HARFBUZZ_VERSION=$(port_version harfbuzz "14.4.0")
PORT_ZIMG_VERSION=$(port_version zimg "release-3.0.6")
PORT_DAV1D_VERSION=$(port_version dav1d "1.5.4")
PORT_LAME_VERSION=$(port_version lame "4.0")

export PORT_X264_VERSION PORT_X265_VERSION PORT_AOM_VERSION \
       PORT_SVTAV1_VERSION PORT_VPX_VERSION PORT_OPUS_VERSION \
       PORT_OPENSSL_VERSION PORT_SRT_VERSION PORT_VMAF_VERSION PORT_LIBASS_VERSION \
       PORT_FREETYPE_VERSION PORT_FRIBIDI_VERSION PORT_HARFBUZZ_VERSION \
       PORT_ZIMG_VERSION PORT_DAV1D_VERSION PORT_LAME_VERSION


# -------------------------------------------------------------
PREFIX="$PWD/.build-cache/prefix"
SRC="$PWD/.build-cache/src"
mkdir -p "$PREFIX" "$SRC"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export PATH="$PREFIX/bin:$PATH"
export CCACHE_DIR=${CCACHE_DIR:-$PWD/.ccache}

# Resolve codec toggles with env override > profile
get_toggle(){
  local key=$1
  # Uppercase key (posix-safe)
  local upper
  upper=$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')
  local env="ENABLE_${upper}"
  if [[ -n "${!env-}" ]]; then
    echo "${!env}"
  else
    yq ".codecs.$key" "$PROFILE_FILE"
  fi
}

# Materialize all toggles as ENABLE_*
for k in x264 x265 aom svtav1 vpx opus fdk_aac ass vmaf srt zimg dav1d lame; do
  upper=$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')
  eval "ENABLE_${upper}=$(get_toggle "$k")"
done

log "Building FFmpeg $FFMPEG_VERSION (nonfree=$ENABLE_NONFREE) with prefix=$PREFIX"

# Tooling for meson (libass/harfbuzz/fribidi)
if ! command -v meson >/dev/null; then
  pip3 install --user meson ninja || true
  export PATH="$HOME/.local/bin:$PATH"
fi

# Build libraries
pushd "$SCRIPT_DIR/_ports" >/dev/null
  [[ "$ENABLE_X264"   =~ ^(true|1)$ ]] && ./x264.sh "$SRC" "$PREFIX" "$PARALLEL"
  [[ "$ENABLE_X265"   =~ ^(true|1)$ ]] && ./x265.sh "$SRC" "$PREFIX" "$PARALLEL"
  [[ "$ENABLE_AOM"    =~ ^(true|1)$ ]] && ./aom.sh  "$SRC" "$PREFIX" "$PARALLEL"
  [[ "$ENABLE_SVTAV1" =~ ^(true|1)$ ]] && ./svtav1.sh "$SRC" "$PREFIX" "$PARALLEL"
  [[ "$ENABLE_VPX"    =~ ^(true|1)$ ]] && ./vpx.sh  "$SRC" "$PREFIX" "$PARALLEL"
  [[ "$ENABLE_OPUS"   =~ ^(true|1)$ ]] && ./opus.sh "$SRC" "$PREFIX" "$PARALLEL"
  if [[ "$ENABLE_FDK_AAC" =~ ^(true|1)$ ]]; then
    [[ "$ENABLE_NONFREE" =~ ^(true|1)$ ]] || { echo "fdk-aac requested but nonfree not enabled"; exit 1; }
    ./fdk_aac.sh "$SRC" "$PREFIX" "$PARALLEL"
  fi
  if [[ "$ENABLE_ASS" =~ ^(true|1)$ ]]; then
    ./freetype.sh "$SRC" "$PREFIX" "$PARALLEL"
    ./fribidi.sh  "$SRC" "$PREFIX" "$PARALLEL"
    ./harfbuzz.sh "$SRC" "$PREFIX" "$PARALLEL"
    ./libass.sh   "$SRC" "$PREFIX" "$PARALLEL"
  fi
  [[ "$ENABLE_VMAF" =~ ^(true|1)$ ]] && ./vmaf.sh "$SRC" "$PREFIX" "$PARALLEL"
  [[ "$ENABLE_ZIMG"  =~ ^(true|1)$ ]] && ./zimg.sh  "$SRC" "$PREFIX" "$PARALLEL"
  [[ "$ENABLE_DAV1D" =~ ^(true|1)$ ]] && ./dav1d.sh "$SRC" "$PREFIX" "$PARALLEL"
  [[ "$ENABLE_LAME"  =~ ^(true|1)$ ]] && ./lame.sh  "$SRC" "$PREFIX" "$PARALLEL"
  ./openssl.sh "$SRC" "$PREFIX" "$PARALLEL"
  [[ "$ENABLE_SRT"  =~ ^(true|1)$ ]] && ./srt.sh  "$SRC" "$PREFIX" "$PARALLEL"
popd >/dev/null

# Fetch FFmpeg
fetch_src "ffmpeg-$FFMPEG_VERSION" "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.gz" "$SRC"
cd "$SRC/ffmpeg-$FFMPEG_VERSION"

CONFIG_FLAGS=(
  "--prefix=$PREFIX"
  "--pkg-config-flags=--static"
  "--extra-cflags=-I$PREFIX/include"
  "--extra-ldflags=-L$PREFIX/lib"
  "--extra-libs=-lpthread -lm"
  "--enable-gpl"
  "--enable-version3"
  "--disable-doc"
  "--disable-debug"
  "--enable-stripping"
  "--enable-pic"
  "--enable-static"
  "--disable-shared"
  "--disable-xlib"
  "--disable-libxcb"
  "--disable-libxcb-shm"
  "--disable-libxcb-xfixes"
  "--disable-libxcb-shape"
  "--disable-sdl2"
  "--enable-openssl"
)
[[ "$ENABLE_NONFREE" =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-nonfree)

# Enable libraries
[[ "$ENABLE_X264"   =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libx264)
[[ "$ENABLE_X265"   =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libx265)
[[ "$ENABLE_AOM"    =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libaom)
[[ "$ENABLE_SVTAV1" =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libsvtav1)
[[ "$ENABLE_VPX"    =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libvpx)
[[ "$ENABLE_OPUS"   =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libopus)
[[ "$ENABLE_FDK_AAC" =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libfdk-aac)
# freetype and harfbuzz are built as libass dependencies; exposing them to
# FFmpeg as well is what enables the drawtext filter. Fonts resolve by path
# (fontfile=) only — naming a font (font=) additionally needs fontconfig.
[[ "$ENABLE_ASS"    =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libass --enable-libfreetype --enable-libharfbuzz)
[[ "$ENABLE_VMAF"   =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libvmaf)
[[ "$ENABLE_SRT"    =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libsrt)
[[ "$ENABLE_ZIMG"   =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libzimg)
[[ "$ENABLE_DAV1D"  =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libdav1d)
[[ "$ENABLE_LAME"   =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-libmp3lame)

# FFplay
ENABLE_FFPLAY=${ENABLE_FFPLAY:-$(yq '.ffmpeg.enable_ffplay' "$PROFILE_FILE")}
[[ "$ENABLE_FFPLAY" =~ ^(true|1)$ ]] && CONFIG_FLAGS+=(--enable-ffplay) || CONFIG_FLAGS+=(--disable-ffplay)

log "Configure flags:
${CONFIG_FLAGS[*]}" | tee "$PWD/../../configure-flags.txt"
./configure "${CONFIG_FLAGS[@]}"
make -j"$PARALLEL"
make install

OUT_DIR="$PWD/../../out/$(platform_triplet)"
rm -rf "$OUT_DIR" && mkdir -p "$OUT_DIR/bin" "$OUT_DIR/LICENSES" "$OUT_DIR/share"
cp -av "$PREFIX/bin/ffmpeg" "$OUT_DIR/bin/"
cp -av "$PREFIX/bin/ffprobe" "$OUT_DIR/bin/" || true
[[ -f "$PREFIX/bin/ffplay" ]] && cp -av "$PREFIX/bin/ffplay" "$OUT_DIR/bin/"

# Licenses & models
collect_licenses "$PREFIX" "$OUT_DIR/LICENSES"
[[ -d "$PREFIX/share/model" ]] && cp -av "$PREFIX/share/model" "$OUT_DIR/share/" || true

make_manifest "$OUT_DIR"
log "Build complete: $OUT_DIR"
