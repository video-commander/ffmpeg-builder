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
# Download a single file
# -------------------------------------------------------------
# fetch_url <url> <output-path>
#
# ffmpeg.org and the GitHub release CDN both reset connections under load, and
# a bare `curl -L` turns one dropped packet into a failed build that is already
# many minutes deep. Retry transient failures instead.
#
# --retry-all-errors is the flag that matters: plain --retry only covers
# transient *HTTP* statuses, not connection resets (curl exit 35/56).
# -f makes an HTTP error a non-zero exit rather than silently writing the
# error page into the tarball, where it would surface later as a confusing
# "not in gzip format" from tar.
# -------------------------------------------------------------

fetch_url() {
  local url="$1"
  local out="$2"

  curl -fL \
    --retry 5 \
    --retry-all-errors \
    --retry-max-time 120 \
    --connect-timeout 30 \
    -o "$out" "$url"
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

  fetch_url "$url" "$tmp/src.tar.gz"

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
# Portability guard
# -------------------------------------------------------------
# Fails if a shipped binary links anything the target machine won't have.
#
# check_portable_linkage <bindir>
# -------------------------------------------------------------

check_portable_linkage() {
  local bindir="$1"
  local bad=0 f deps

  for f in "$bindir"/*; do
    [[ -f "$f" && -x "$f" ]] || continue

    case "$(uname -s)" in
      Darwin)
        deps=$(otool -L "$f" 2>/dev/null | tail -n +2 | awk '{print $1}' \
               | grep -vE '^(/System/|/usr/lib/)' || true)
        ;;
      Linux)
        # Skip the loader and vDSO, which ldd prints without a path.
        deps=$(ldd "$f" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /^\//) {print $i; break}}' \
               | grep -vE '^(/lib/|/lib64/|/usr/lib/|/usr/lib64/)' || true)
        ;;
      *)
        return 0
        ;;
    esac

    if [[ -n "$deps" ]]; then
      warn "non-portable linkage in $(basename "$f"):"
      printf '  %s\n' $deps >&2
      bad=1
    fi
  done

  if [[ $bad -ne 0 ]]; then
    err "shipped binaries depend on libraries outside the OS. Build them as static ports, or disable the feature in CONFIG_FLAGS."
  fi

  log "Linkage check passed: binaries depend only on OS libraries"
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
