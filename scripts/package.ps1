Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$env:MSYSTEM = "MINGW64"
$env:CHERE_INVOKING = "1"
& "C:\msys64\usr\bin\bash.exe" -lc @"
set -euo pipefail

OUT_DIR=".build-cache/out/windows-x86_64"

if [[ ! -x "`$OUT_DIR/bin/ffmpeg.exe" ]]; then
  echo "[error] No ffmpeg.exe found in `$OUT_DIR/bin"
  exit 1
fi

# Get version from binary
ver=`$("`$OUT_DIR/bin/ffmpeg.exe" -version 2>&1 | awk 'NR==1{print `$3}')

# Copy required MinGW runtime DLLs (skip Windows system DLLs)
for bin in `$OUT_DIR/bin/*.exe; do
  ldd "`$bin" | awk '{print `$3}' | grep -v '^/c/Windows' | grep -v 'not found' | grep -v '^`$' | while read dll; do
    [[ -f "`$dll" ]] && cp -n "`$dll" "`$OUT_DIR/bin/" && echo "Copied: `$dll"
  done
done

NONFREE_SUFFIX=""
[[ "$($env:ENABLE_NONFREE)" == "true" ]] && NONFREE_SUFFIX="-nonfree"

mkdir -p dist
zip_path="dist/ffmpeg-`${ver}-windows-x86_64`${NONFREE_SUFFIX}.zip"
(cd .build-cache/out && zip -r "../../`$zip_path" windows-x86_64)

echo "==> Package written: `$zip_path"
"@
