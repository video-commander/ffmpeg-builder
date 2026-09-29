#!/usr/bin/env bash
set -euo pipefail
if ! command -v brew >/dev/null; then
  echo "Homebrew required."; exit 1
fi
brew update
# No ccache: nothing routes the compiler through it, and on Intel runners,
# where Homebrew no longer publishes bottles, it builds llvm, rust and gcc
# from source.
brew install automake autoconf libtool pkg-config cmake ninja meson nasm yasm git
brew install yq