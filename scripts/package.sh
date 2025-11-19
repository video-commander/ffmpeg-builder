#!/usr/bin/env bash
set -euo pipefail
triplet=$(./scripts/common.sh; platform_triplet)
out="out/$triplet"
ver=$("$out/bin/ffmpeg" -version | awk 'NR==1{print $3}')
nonfree_suffix=""
[[ "${ENABLE_NONFREE:-false}" == "true" || "${ENABLE_NONFREE:-0}" == "1" ]] && nonfree_suffix="-nonfree"
mkdir -p dist
zip -r "dist/ffmpeg-${ver}-${triplet}${nonfree_suffix}.zip" "$out"