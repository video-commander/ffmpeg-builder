#!/usr/bin/env bash
set -euo pipefail
export PATH="/mingw64/bin:/usr/bin:${PATH:-}"

OUT_DIR=".build-cache/out/windows-x86_64"

if [[ ! -x "$OUT_DIR/bin/ffmpeg.exe" ]]; then
  echo "[error] No ffmpeg.exe found in $OUT_DIR/bin"
  exit 1
fi

ver=$("$OUT_DIR/bin/ffmpeg.exe" -version 2>&1 | awk 'NR==1{print $3}')

# Copy required MinGW runtime DLLs (e.g. libgcc, libwinpthread) and their
# transitive deps. Runs until no new DLLs are added.
copy_mingw_dlls() {
  local dir="$1"
  local changed=1
  while [[ $changed -eq 1 ]]; do
    changed=0
    for bin in "$dir"/*.exe "$dir"/*.dll; do
      [[ -f "$bin" ]] || continue
      while IFS= read -r dll; do
        [[ -z "$dll" || ! -f "$dll" ]] && continue
        local name
        name=$(basename "$dll")
        if [[ ! -f "$dir/$name" ]]; then
          cp "$dll" "$dir/"
          echo "Copied: $name"
          changed=1
        fi
      done < <(ldd "$bin" 2>/dev/null | awk '{print $3}' | grep -iE '/mingw64/bin/' || true)
    done
  done
}

copy_mingw_dlls "$OUT_DIR/bin"

NONFREE_SUFFIX=""
[[ "${ENABLE_NONFREE:-false}" == "true" ]] && NONFREE_SUFFIX="-nonfree"

mkdir -p dist
zip_path="dist/ffmpeg-${ver}-windows-x86_64${NONFREE_SUFFIX}.zip"
(cd .build-cache/out && zip -r "../../$zip_path" windows-x86_64)

echo "==> Package written: $zip_path"
