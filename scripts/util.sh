#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------
# Logging helpers
# -------------------------------------------------------------

log() {
  # Green bold prefix
  printf "\033[1;32m==>\033[0m %s\n" "$*"
}

warn() {
  # Yellow prefix
  printf "\033[1;33m[warn]\033[0m %s\n" "$*" >&2
}

err() {
  # Red prefix + exit
  printf "\033[1;31m[error]\033[0m %s\n" "$*" >&2
  exit 1
}

# -------------------------------------------------------------
# Fetch & extract source trees
# -------------------------------------------------------------
# fetch_src <folder-name> <url> <dest>
# Will only download/unpack if missing.
#
# Example:
#   fetch_src "ffmpeg-7.1" \
#     "https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n7.1.tar.gz" \
#     "$SRC"
# -------------------------------------------------------------

fetch_src() {
  local name="$1"
  local url="$2"
  local dest="$3"

  mkdir -p "$dest"

  if [[ -d "$dest/$name" ]]; then
    log "$name already present"
    return 0
  fi

  log "Fetching $name"
  local tmp
  tmp=$(mktemp -d)

  curl -L "$url" -o "$tmp/src.tar.gz"

  # Detect top-level directory in the tarball
  local top
  top=$(tar -tzf "$tmp/src.tar.gz" | head -n1 | cut -d/ -f1)

  tar -C "$dest" -xzf "$tmp/src.tar.gz"

  # Normalize directory name to the requested $name
  if [[ -n "$top" && "$top" != "$name" && -d "$dest/$top" ]]; then
    mv "$dest/$top" "$dest/$name"
  fi

  rm -rf "$tmp"
}


# -------------------------------------------------------------
# License collector
# -------------------------------------------------------------
# Copies all COPY* / LICENSE* files from prefix into out/LICENSES/
#
# collect_licenses <prefix> <output>
# -------------------------------------------------------------

collect_licenses() {
  local prefix="$1"
  local out="$2"

  mkdir -p "$out"

  # Copy up to depth 4 inside prefix (matches ports layout)
  local files
  files=$(find "$prefix" \
    -maxdepth 4 \
    -type f \( -iname 'COPYING*' -o -iname 'LICENSE*' \) \
    2>/dev/null || true)

  if [[ -z "$files" ]]; then
    warn "No license files found under $prefix"
    return 0
  fi

  for f in $files; do
    cp -v "$f" "$out/" || warn "Failed to copy license $f"
  done
}

# -------------------------------------------------------------
# Build manifest
# -------------------------------------------------------------
# make_manifest <outdir>
# Creates build-manifest.json containing:
#  - timestamp
#  - platform (linux-x86_64, macos-arm64, etc.)
#  - ffmpeg version string
#  - nonfree flag
# -------------------------------------------------------------

make_manifest() {
  local out="$1"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # assume ffmpeg exists
  local version
  version=$("$out/bin/ffmpeg" -version | head -n1 | sed 's/^ffmpeg //')

  cat > "$out/build-manifest.json" <<JSON
{
  "timestamp": "$ts",
  "platform": "$(platform_triplet)",
  "ffmpeg": "$version",
  "nonfree": ${ENABLE_NONFREE:-false}
}
JSON
}

# -------------------------------------------------------------
# Helper: safe mkdir
# -------------------------------------------------------------

ensure_dir() {
  mkdir -p "$1"
}

# -------------------------------------------------------------
# Helper: detect OS/arch for portability (mac/linux)
# platform_triplet is actually generated in `common.sh`
# but we forward declare a fallback here in case reused.
# -------------------------------------------------------------

platform_triplet() {
  case "$(uname -s)" in
    Linux*)  os="linux" ;;
    Darwin*) os="macos" ;;
    MINGW*|MSYS*|CYGWIN*) os="windows" ;;
    *) os="unknown" ;;
  esac

  arch=$(uname -m)
  echo "${os}-${arch}"
}
