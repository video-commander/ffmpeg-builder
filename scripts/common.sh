#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------
# platform_triplet
# -------------------------------------------------------------
# Produces a normalized OS/arch string usable for output
# folders, manifests, and artifact naming.
#
# Examples:
#   linux-x86_64
#   macos-arm64
#   windows-x86_64
# -------------------------------------------------------------

platform_triplet() {
  local os arch

  # OS detection
  case "$(uname -s)" in
    Linux*)    os="linux" ;;
    Darwin*)   os="macos" ;;
    MINGW*|MSYS*|CYGWIN*) os="windows" ;;
    *)         os="unknown" ;;
  esac

  # Architecture detection
  arch="$(uname -m)"

  # Normalize common arch names
  case "$arch" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
  esac

  echo "${os}-${arch}"
}

# -------------------------------------------------------------
# require_cmd
# -------------------------------------------------------------
# Utility to ensure a required tool is installed.
#
# Example:
#   require_cmd yq "Install yq via Homebrew or apt."
# -------------------------------------------------------------

require_cmd() {
  local cmd="$1"
  local msg="${2:-}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[error] Missing required command: $cmd" >&2
    [[ -n "$msg" ]] && echo "        $msg" >&2
    exit 1
  fi
}

# -------------------------------------------------------------
# die (shortcut error)
# -------------------------------------------------------------

die() {
  echo "[error] $*" >&2
  exit 1
}

# Return the version for a given port name.
# Precedence:
#   1. Env:  PORT_<NAME>_VERSION (e.g. PORT_X265_VERSION=3.5)
#   2. YAML: .ports.<name>.version in $PROFILE_FILE
#   3. Default argument
#
# Usage:
#   PORT_X265_VERSION=$(port_version x265 "3.6")
port_version() {
  local name="$1"
  local default="${2:-}"

  # ENV override wins: PORT_X265_VERSION, PORT_AOM_VERSION, ...
  local upper
  upper=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')
  local env_var="PORT_${upper}_VERSION"

  if [[ -n "${!env_var-}" ]]; then
    echo "${!env_var}"
    return 0
  fi

  # Profile YAML: .ports.<name>.version
  if [[ -n "${PROFILE_FILE-}" && -f "$PROFILE_FILE" ]]; then
    # -r: raw string, // "" to map null to empty
    local val
    val=$(yq -r ".ports.$name.version // \"\"" "$PROFILE_FILE")
    if [[ -n "$val" && "$val" != "null" ]]; then
      echo "$val"
      return 0
    fi
  fi

  # Fallback default
  echo "$default"
}

# Return 1/0 whether a codec/port is enabled.
# Precedence:
#   1. Env: ENABLE_<NAME>=1/0 (e.g. ENABLE_X265=0)
#   2. YAML: .codecs.<name> bool in $PROFILE_FILE
port_enabled() {
  local name="$1"

  local upper
  upper=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')
  local env_var="ENABLE_${upper}"

  if [[ -n "${!env_var-}" ]]; then
    case "${!env_var}" in
      1|true|TRUE|yes|YES) echo 1; return 0 ;;
      *)                   echo 0; return 0 ;;
    esac
  fi

  if [[ -n "${PROFILE_FILE-}" && -f "$PROFILE_FILE" ]]; then
    local val
    val=$(yq -r ".codecs.$name // false" "$PROFILE_FILE")
    [[ "$val" == "true" ]] && echo 1 || echo 0
    return 0
  fi

  echo 0
}
