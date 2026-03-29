Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

winget install --id MSYS2.MSYS2 -e --source winget

# Install toolchain + deps inside MSYS2
& "$env:USERPROFILE\scoop\apps\msys2\current\usr\bin\bash" -lc "pacman -Sy --noconfirm --needed base-devel git nasm yasm cmake ninja mingw-w64-x86_64-toolchain mingw-w64-x86_64-pkgconf"
