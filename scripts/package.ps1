Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$env:MSYSTEM = "MINGW64"
$env:CHERE_INVOKING = "1"

$outDir = ".build-cache\out\windows-x86_64"
$ffmpeg = "$outDir\bin\ffmpeg.exe"

if (-not (Test-Path $ffmpeg)) {
  throw "[error] No ffmpeg.exe found in $outDir\bin"
}

# Get version
$ver = (& $ffmpeg -version 2>&1)[0] -replace '^ffmpeg version (\S+).*', '$1'

# Find required MinGW DLLs via ldd, skip Windows system DLLs
$script = @'
for bin in .build-cache/out/windows-x86_64/bin/*.exe; do
  ldd "$bin" | awk '{print $3}' | grep -iv '^/c/windows' | grep -v 'not found' | grep -v '^$'
done
'@
$tmpScript = [System.IO.Path]::GetTempFileName() + ".sh"
[System.IO.File]::WriteAllText($tmpScript, $script, [System.Text.Encoding]::ASCII)
$tmpScriptMsys = & "C:\msys64\usr\bin\cygpath.exe" $tmpScript

$dlls = & "C:\msys64\usr\bin\bash.exe" -lc "bash '$tmpScriptMsys'" | Sort-Object -Unique
Remove-Item $tmpScript

foreach ($dll in $dlls) {
  $dllWin = & "C:\msys64\usr\bin\cygpath.exe" -w $dll
  $dest = "$outDir\bin\$(Split-Path $dllWin -Leaf)"
  if (-not (Test-Path $dest)) {
    Copy-Item $dllWin $dest
    Write-Host "Copied: $(Split-Path $dllWin -Leaf)"
  }
}

# Package
$nonfree = if ($env:ENABLE_NONFREE -eq "true") { "-nonfree" } else { "" }
New-Item -ItemType Directory -Force -Path "dist" | Out-Null
$zipPath = "dist\ffmpeg-$ver-windows-x86_64$nonfree.zip"
Compress-Archive -Path "$outDir\*" -DestinationPath $zipPath -Force

Write-Host "==> Package written: $zipPath"
