#!/usr/bin/env bash
set -euo pipefail

# Points the Homebrew formula at a release's archives.
#
# update-tap-formula.sh <tag> <dist-dir> <formula>

TAG="${1:?usage: update-tap-formula.sh <tag> <dist-dir> <formula>}"
DIST="${2:?}"
FORMULA="${3:?}"

[[ -f "$FORMULA" ]] || { echo "[error] formula not found: $FORMULA" >&2; exit 1; }

find_zip() {
  find "$DIST" -type f -name "ffmpeg-*-macos-$1.zip" | head -n1
}

digest_of() {
  local zip="$1"
  if [[ -f "$zip.sha256" ]]; then
    awk '{print $1}' "$zip.sha256"
  else
    shasum -a 256 "$zip" 2>/dev/null | awk '{print $1}' || sha256sum "$zip" | awk '{print $1}'
  fi
}

ARM_ZIP=$(find_zip arm64)
INTEL_ZIP=$(find_zip x86_64)
[[ -n "$ARM_ZIP" && -n "$INTEL_ZIP" ]] || { echo "[error] could not find both archives under $DIST" >&2; exit 1; }

ARM_SHA=$(digest_of "$ARM_ZIP")
INTEL_SHA=$(digest_of "$INTEL_ZIP")
[[ ${#ARM_SHA} -eq 64 && ${#INTEL_SHA} -eq 64 ]] || { echo "[error] bad digest length" >&2; exit 1; }

BASE="https://github.com/video-commander/ffmpeg-builder/releases/download/$TAG"

TAG="$TAG" \
ARM_URL="$BASE/$(basename "$ARM_ZIP")" ARM_SHA="$ARM_SHA" \
INTEL_URL="$BASE/$(basename "$INTEL_ZIP")" INTEL_SHA="$INTEL_SHA" \
python3 - "$FORMULA" <<'PY'
import os, re, sys

path = sys.argv[1]
s = open(path).read()
version = os.environ["TAG"].lstrip("v")

new = re.sub(r'^(\s*)version "[^"]*"',
             lambda m: f'{m.group(1)}version "{version}"', s, count=1, flags=re.M)
if new == s:
    sys.exit("[error] no version line replaced")
s = new

def arch_block(text, marker, url, sha):
    pattern = re.compile(
        r'(' + marker + r'\n\s*url ")[^"]*("\n\s*sha256 ")[0-9a-f]{64}(")')
    out, n = pattern.subn(lambda m: m.group(1) + url + m.group(2) + sha + m.group(3), text, count=1)
    if n != 1:
        sys.exit(f"[error] no {marker} block replaced")
    return out

s = arch_block(s, r'if Hardware::CPU\.arm\?', os.environ["ARM_URL"], os.environ["ARM_SHA"])
s = arch_block(s, r'else', os.environ["INTEL_URL"], os.environ["INTEL_SHA"])

open(path, "w").write(s)
print(f"formula updated to {version}")
PY
