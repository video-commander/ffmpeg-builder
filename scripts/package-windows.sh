#!/usr/bin/env bash
set -euo pipefail
export PATH="/mingw64/bin:/usr/bin:${PATH:-}"

OUT_DIR=".build-cache/out/windows-x86_64"

if [[ ! -x "$OUT_DIR/bin/ffmpeg.exe" ]]; then
  echo "[error] No ffmpeg.exe found in $OUT_DIR/bin"
  exit 1
fi

ver=$("$OUT_DIR/bin/ffmpeg.exe" -version 2>&1 | awk 'NR==1{print $3}')

# Copy required MinGW runtime DLLs (skip Windows system DLLs)
for bin in "$OUT_DIR/bin/"*.exe; do
  ldd "$bin" | awk '{print $3}' | grep -i '/mingw64/bin/' | while read dll; do
    [[ -f "$dll" ]] && cp -n "$dll" "$OUT_DIR/bin/" && echo "Copied: $(basename "$dll")"
  done
done

NONFREE_SUFFIX=""
[[ "${ENABLE_NONFREE:-false}" == "true" ]] && NONFREE_SUFFIX="-nonfree"

mkdir -p dist
zip_path="dist/ffmpeg-${ver}-windows-x86_64${NONFREE_SUFFIX}.zip"
(cd .build-cache/out && zip -r "../../$zip_path" windows-x86_64)

echo "==> Package written: $zip_path"
