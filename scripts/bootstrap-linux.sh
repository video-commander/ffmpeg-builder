#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
sudo apt-get install -y \
  build-essential autoconf automake libtool pkg-config \
  cmake ninja-build meson nasm yasm git curl wget unzip \
  python3 python3-pip ccache

# yq for YAML parsing (portable, no jq dependency)
sudo wget -O /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq