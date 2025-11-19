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
