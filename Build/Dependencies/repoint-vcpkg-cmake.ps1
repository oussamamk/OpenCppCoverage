# Make the pinned-2020 vcpkg use a modern CMake. The pinned vcpkgTools.xml
# acquires cmake 3.14.0, which predates VS2022 and cannot create the
# "Visual Studio 17 2022" generator - so any port built WITHOUT PREFER_NINJA
# (poco) fails at configure with "Could not create named generator
# Visual Studio 17 2022". This script copies a VS2022-shipped cmake over the
# acquired 3.14.0 tool location (same path, newer binary).
# Idempotent: no-op when the acquired cmake already reports >= 3.21.
param([string]$VcpkgRoot = '.')
$ErrorActionPreference = 'Stop'

$acquired = Join-Path $VcpkgRoot 'downloads\tools\cmake-3.14.0-windows\cmake-3.14.0-win32-x86'
$acquiredCmake = Join-Path $acquired 'bin\cmake.exe'

if (Test-Path $acquiredCmake) {
    $ver = (& $acquiredCmake --version | Select-Object -First 1) -replace '^cmake version ', ''
    if ($ver -notmatch '^3\.(0|1[0-9]|20)\.') {
        Write-Host "acquired cmake already $ver - nothing to do"
        exit 0
    }
    Write-Host "acquired cmake is $ver - overwriting with VS2022 cmake"
} else {
    Write-Host "acquired cmake dir missing - will seed it from VS2022"
    New-Item -ItemType Directory -Force -Path $acquired | Out-Null
}

$vsCmake = 'C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
if (-not (Test-Path $vsCmake)) {
    $cand = Get-ChildItem 'C:\Program Files\Microsoft Visual Studio\2022' -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe' } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($cand) { $vsCmake = $cand } else { Write-Error 'VS2022 cmake.exe not found'; exit 1 }
}
$vsCmakeRoot = Split-Path (Split-Path $vsCmake)   # ...\CMake\CMake\bin -> ...\CMake\CMake
$vsCmakeRoot = Split-Path $vsCmakeRoot            # -> ...\CMake
Copy-Item (Join-Path $vsCmakeRoot '*') $acquired -Recurse -Force
$ver = (& $acquiredCmake --version | Select-Object -First 1)
Write-Host "acquired cmake now: $ver"
