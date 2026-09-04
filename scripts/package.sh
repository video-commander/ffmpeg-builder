#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

. "$SCRIPT_DIR/common.sh"
. "$SCRIPT_DIR/util.sh"

triplet=$(platform_triplet)

PRIMARY_OUT="$ROOT_DIR/out/$triplet"
ALT_OUT="$ROOT_DIR/.build-cache/out/$triplet"

if [[ -x "$PRIMARY_OUT/bin/ffmpeg" ]]; then
  out="$PRIMARY_OUT"
elif [[ -x "$ALT_OUT/bin/ffmpeg" ]]; then
  out="$ALT_OUT"
else
  echo "[error] No ffmpeg binary found in:"
  echo "  $PRIMARY_OUT/bin"
  echo "  $ALT_OUT/bin"
  exit 1
fi

ver=$("$out/bin/ffmpeg" -version | awk 'NR==1{print $3}')

nonfree_suffix=""
if [[ "${ENABLE_NONFREE:-false}" == "true" || "${ENABLE_NONFREE:-0}" == "1" ]]; then
  nonfree_suffix="-nonfree"
fi

mkdir -p "$ROOT_DIR/dist"

zip_path="$ROOT_DIR/dist/ffmpeg-${ver}-${triplet}${nonfree_suffix}.zip"

echo "==> Packaging $out -> $zip_path"
(
  cd "$(dirname "$out")"   # cd into .../out or .../.build-cache/out
  zip -r "$zip_path" "$triplet"
)

# Sidecar digest: the consuming installer pins each archive by SHA-256, and
# computing it here means the release carries it rather than the maintainer
# running shasum by hand.
if command -v shasum >/dev/null; then
  ( cd "$ROOT_DIR/dist" && shasum -a 256 "$(basename "$zip_path")" > "$(basename "$zip_path").sha256" )
else
  ( cd "$ROOT_DIR/dist" && sha256sum "$(basename "$zip_path")" > "$(basename "$zip_path").sha256" )
fi

echo "==> Package written: $zip_path"
echo "==> Digest written:  $zip_path.sha256"
