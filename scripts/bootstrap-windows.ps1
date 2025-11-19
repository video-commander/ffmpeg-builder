Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
choco install -y msys2
# Install toolchain + deps inside MSYS2
& C:\tools\msys64\usr\bin\bash -lc "pacman -Sy --noconfirm --needed base-devel git nasm yasm cmake ninja mingw-w64-x86_64-toolchain mingw-w64-x86_64-pkgconf"