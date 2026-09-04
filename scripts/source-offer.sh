#!/usr/bin/env bash
set -euo pipefail

# Emits the "Corresponding source" section of a release body.
#
# The published archives are conveyed GPL binaries, so the release has to say
# where the source for each component lives. Rendering it from the profile the
# build actually used keeps the versions honest: this runs on the tagged tree,
# so the pins here are the pins that were compiled.
#
# Usage: ./scripts/source-offer.sh [profile]   (default: profiles/default.yml)

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
PROFILE_FILE="${1:-$ROOT_DIR/profiles/default.yml}"
[[ -f "$PROFILE_FILE" ]] || { echo "[error] profile not found: $PROFILE_FILE" >&2; exit 1; }

v() { yq -r ".ports.$1.version // \"\"" "$PROFILE_FILE"; }
on() { [[ "$(yq -r ".codecs.$1 // false" "$PROFILE_FILE")" == "true" ]]; }

FFMPEG_VERSION=$(yq -r '.ffmpeg.version' "$PROFILE_FILE")

# library | version | license | source URL, one row per enabled component.
rows=()
row() { rows+=("| $1 | \`$2\` | $3 | $4 |"); }

row "FFmpeg" "$FFMPEG_VERSION" "GPL-3.0-or-later" \
  "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz"

on x264   && row "x264"     "$(v x264)"   "GPL-2.0-or-later"      "https://code.videolan.org/videolan/x264"
on x265   && row "x265"     "$(v x265)"   "GPL-2.0-or-later"      "https://bitbucket.org/multicoreware/x265_git/downloads/x265_$(v x265).tar.gz"
on aom    && row "libaom"   "$(v aom)"    "BSD-2-Clause + AOM patent" "https://aomedia.googlesource.com/aom/+/refs/tags/$(v aom)"
on svtav1 && row "SVT-AV1"  "$(v svtav1)" "BSD-3-Clause-Clear"    "https://gitlab.com/AOMediaCodec/SVT-AV1/-/tree/$(v svtav1)"
on dav1d  && row "dav1d"    "$(v dav1d)"  "BSD-2-Clause"          "https://github.com/videolan/dav1d/releases/tag/$(v dav1d)"
on vpx    && row "libvpx"   "$(v vpx)"    "BSD-3-Clause"          "https://github.com/webmproject/libvpx/releases/tag/$(v vpx)"
on opus   && row "Opus"     "$(v opus)"   "BSD-3-Clause"          "https://github.com/xiph/opus/releases/tag/$(v opus)"
on lame   && row "LAME"     "$(v lame)"   "LGPL-2.0-or-later"     "https://downloads.sourceforge.net/project/lame/lame/$(v lame)/lame-$(v lame).tar.gz"
on zimg   && row "zimg"     "$(v zimg)"   "WTFPL-2.0"             "https://github.com/sekrit-twc/zimg/releases/tag/$(v zimg)"
on vmaf   && row "libvmaf"  "$(v vmaf)"   "BSD-2-Clause-Patent"   "https://github.com/Netflix/vmaf/releases/tag/$(v vmaf)"
on srt    && row "libsrt"   "$(v srt)"    "MPL-2.0"               "https://github.com/Haivision/srt/releases/tag/$(v srt)"
if on ass; then
  row "libass"   "$(v libass)"   "ISC"                "https://github.com/libass/libass/releases/tag/$(v libass)"
  row "FreeType" "$(v freetype)" "FTL or GPL-2.0"     "https://github.com/freetype/freetype/releases/tag/$(v freetype)"
  row "FriBidi"  "$(v fribidi)"  "LGPL-2.1-or-later"  "https://github.com/fribidi/fribidi/releases/tag/$(v fribidi)"
  row "HarfBuzz" "$(v harfbuzz)" "MIT (Old MIT)"      "https://github.com/harfbuzz/harfbuzz/releases/tag/$(v harfbuzz)"
fi
row "OpenSSL" "$(v openssl)" "Apache-2.0" "https://github.com/openssl/openssl/releases/tag/openssl-$(v openssl)"

cat <<EOF
## Corresponding source

These archives contain FFmpeg built with \`--enable-gpl --enable-version3\`,
statically linked against the libraries below. The binaries are therefore
covered by the GPL v3, and this is where the corresponding source lives.

The build scripts that produced them — the "scripts used to control
compilation" — are this repository at the tag for this release. Each library is
fetched from the upstream URL below at the pinned version:

| Component | Version | License | Source |
| --- | --- | --- | --- |
$(printf '%s\n' "${rows[@]}")

Full license texts for every linked library are included in each archive under
\`LICENSES/\`, and the exact configure line is in \`configure-flags.txt\`.

Requests for source that has moved upstream: <support@video-commander.com>.
EOF
