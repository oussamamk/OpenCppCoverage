param([string]$PortDir = 'ports\ctemplate')
# Wire fix-arm64-macros.patch into the ctemplate port's patch list.
# Idempotent: skips when already wired. The pinned vcpkg_from_github takes
# PATCHES as a keyword argument; the portfile has none, so insert one after
# HEAD_REF.
$ErrorActionPreference = 'Stop'
$p = Join-Path $PortDir 'portfile.cmake'
$c = [System.IO.File]::ReadAllText($p)
if ($c -match 'fix-arm64-macros') {
    Write-Host 'ctemplate portfile already patched'
    exit 0
}
$patched = $c -replace '(HEAD_REF master\r?\n)', "`$1  PATCHES `${CURRENT_PORT_DIR}/fix-arm64-macros.patch`r`n"
if ($patched -eq $c) { Write-Error 'HEAD_REF anchor not found in portfile.cmake'; exit 1 }
[System.IO.File]::WriteAllText($p, $patched)
Write-Host "ctemplate portfile patched (PATCHES added to $p)"
