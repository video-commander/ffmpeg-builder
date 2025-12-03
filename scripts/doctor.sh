#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# Shared helpers
# - common.sh should define: port_version, port_enabled
# - util.sh can define: info, warn (optional; we fallback to echo if missing)
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/common.sh"
fi

if [[ -f "$SCRIPT_DIR/util.sh" ]]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/util.sh"
else
  info() { echo "[info]" "$@"; }
  warn() { echo "[warn]" "$@" >&2; }
fi

# Resolve profile file
PROFILE_FILE_ENV="${PROFILE:-}"
if [[ -n "$PROFILE_FILE_ENV" ]]; then
  PROFILE_FILE="$PROFILE_FILE_ENV"
else
  PROFILE_FILE="$ROOT_DIR/profiles/default.yml"
fi

if [[ ! -f "$PROFILE_FILE" ]]; then
  warn "Profile file not found: $PROFILE_FILE"
  exit 1
fi

echo "=== ffmpeg-builder doctor ==="
echo "ROOT_DIR      : $ROOT_DIR"
echo "PROFILE_FILE  : $PROFILE_FILE"
echo

# Basic ffmpeg section
FFMPEG_VERSION=$(yq -r '.ffmpeg.version // "unknown"' "$PROFILE_FILE")
FFMPEG_FFPLAY=$(yq -r '.ffmpeg.enable_ffplay // false' "$PROFILE_FILE")
FFMPEG_GPL=$(yq -r '.ffmpeg.gpl // false' "$PROFILE_FILE")
FFMPEG_NONFREE=$(yq -r '.ffmpeg.nonfree // false' "$PROFILE_FILE")
FFMPEG_LD_STATIC=$(yq -r '.ffmpeg.ld_static // false' "$PROFILE_FILE")
PARALLEL=$(yq -r '.system.parallel // 0' "$PROFILE_FILE")

echo "[ffmpeg]"
echo "  version     : $FFMPEG_VERSION"
echo "  enable_ffplay: $FFMPEG_FFPLAY"
echo "  gpl         : $FFMPEG_GPL"
echo "  nonfree     : $FFMPEG_NONFREE"
echo "  ld_static   : $FFMPEG_LD_STATIC"
echo
echo "[system]"
echo "  parallel    : $PARALLEL"
echo

# Codecs
CODECS=(x264 x265 aom svtav1 vpx opus fdk_aac ass vmaf srt)

echo "[codecs]"
for c in "${CODECS[@]}"; do
  if command -v port_enabled >/dev/null 2>&1; then
    enabled=$(port_enabled "$c")
    if [[ "$enabled" == "1" ]]; then
      status="enabled"
    else
      status="disabled"
    fi
  else
    # fallback: read from YAML directly
    val=$(yq -r ".codecs.$c // false" "$PROFILE_FILE")
    status=$([[ "$val" == "true" ]] && echo "enabled" || echo "disabled")
  fi
  echo "  $c: $status"
done
echo

# Port versions
PORTS=(x264 x265 aom svtav1 vpx opus srt vmaf libass)

echo "[ports]"
for p in "${PORTS[@]}"; do
  version="unknown"
  if command -v port_version >/dev/null 2>&1; then
    version=$(port_version "$p" "")
  else
    version=$(yq -r ".ports.$p.version // \"\"" "$PROFILE_FILE")
    [[ "$version" == "null" ]] && version=""
  fi
  if [[ -z "$version" ]]; then
    version="(default)"
  fi
  echo "  $p: $version"
done
echo

# Show env overrides (if any)
echo "[env overrides]"
for var in $(env | cut -d= -f1 | grep -E '^PORT_[A-Z0-9_]+_VERSION$|^ENABLE_[A-Z0-9_]+$' | sort); do
  echo "  $var=${!var}"
done
echo

# Inspect built ffmpeg binaries if present
echo "[binaries]"
CANDIDATES=()

# New canonical out dir
if [[ -d "$ROOT_DIR/out" ]]; then
  while IFS= read -r -d '' f; do
    CANDIDATES+=("$f")
  done < <(find "$ROOT_DIR/out" -maxdepth 3 -type f -name ffmpeg -print0 2>/dev/null || true)
fi

# Legacy .build-cache/out
if [[ -d "$ROOT_DIR/.build-cache/out" ]]; then
  while IFS= read -r -d '' f; do
    CANDIDATES+=("$f")
  done < <(find "$ROOT_DIR/.build-cache/out" -maxdepth 3 -type f -name ffmpeg -print0 2>/dev/null || true)
fi

if (( ${#CANDIDATES[@]} == 0 )); then
  echo "  no ffmpeg binaries found yet (build not run?)"
else
  for f in "${CANDIDATES[@]}"; do
    echo "  $(realpath "$f")"
  done
  echo
  echo "[ffmpeg -version (first binary)]"
  "${CANDIDATES[0]}" -version || warn "Failed to run ffmpeg -version"
fi

echo
echo "=== doctor done ==="
