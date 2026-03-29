Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path "C:\msys64\usr\bin\bash.exe")) {
  throw "MSYS2 not found. Install it from https://www.msys2.org and ensure it is at C:\msys64."
}

$env:MSYSTEM = "MINGW64"
& "C:\msys64\usr\bin\bash.exe" -lc "pacman -Sy --noconfirm --needed base-devel git nasm yasm cmake ninja mingw-w64-x86_64-toolchain mingw-w64-x86_64-pkgconf mingw-w64-x86_64-x264 mingw-w64-x86_64-x265 mingw-w64-x86_64-aom mingw-w64-x86_64-opus mingw-w64-x86_64-libvpx"
