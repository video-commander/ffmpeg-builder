#!/usr/bin/env bash
set -euo pipefail
if ! command -v brew >/dev/null; then
  echo "Homebrew required."; exit 1
fi
brew update
brew install automake autoconf libtool pkg-config cmake ninja nasm yasm git ccache
brew install yq