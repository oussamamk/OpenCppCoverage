# Teach b2 1.72 (boost-build) about VS2022's MSVC 14.3x/14.4x toolchains.
# b2's msvc.jam detects the toolset version from the cl.exe path with regexes
# matching only "MSVC\14.1" / "MSVC\14.2" (4 backslashes - jam-escaped).
# VS2022 ships 14.3x/14.4x, so b2 falls through to "version = 6.0" (VC6):
# the wrong vcvars setup resolves and every boost link fails with
# "'/DLL' is not recognized" (no linker environment).
#
# Two edits per msvc.jam:
#   1. command-path detection: after the 14.2 arm add an else-if arm mapping
#      MSVC\14.3 / MSVC\14.4 -> version 14.2 (identical vcvars layout).
#   2. generate-setup-cmd's version arm: extend the 14.2 match with 14.3/14.4
#      so the Auxiliary\Build vcvarsall lookup also applies.
# Patches both the port copy (future installs) and every installed tool copy.
# Idempotent: skips files already carrying the 14.3 arm.
param([string]$VcpkgRoot = '.')
$ErrorActionPreference = 'Stop'

$targets = @()
$portJam = Join-Path $VcpkgRoot 'ports\boost-build\src\tools\msvc.jam'
if (Test-Path $portJam) { $targets += $portJam }
$installedJamRoot = Join-Path $VcpkgRoot 'installed'
if (Test-Path $installedJamRoot) {
    $targets += Get-ChildItem $installedJamRoot -Recurse -Filter 'msvc.jam' |
        Where-Object { $_.FullName -match 'tools[\\/]boost-build[\\/]src[\\/]tools' } |
        ForEach-Object { $_.FullName }
}
if (-not $targets) { Write-Error 'no msvc.jam found (port or installed tool)'; exit 1 }

$bs4 = '\\\\'    # the literal file text is MSVC\\\\14.2 (4 backslashes, jam-escaped; PS single quotes need no doubling)
$block142 = "if [ MATCH `"(MSVC$bs4" + '14.2)" : $(command) ]' + "`r`n" + '            {' + "`r`n" + '                version = 14.2 ;' + "`r`n" + '            }' + "`r`n"
$arm143 = '            else if [ MATCH "(MSVC' + $bs4 + '14.3)" : $(command) ] || [ MATCH "(MSVC' + $bs4 + '14.4)" : $(command) ]' + "`r`n" + '            {' + "`r`n" + '                version = 14.2 ;' + "`r`n" + '            }' + "`r`n"
$verArmOld = 'if [ MATCH "(14.2)" : $(version) ]'
$verArmNew = 'if [ MATCH "(14.2)" : $(version) ] || [ MATCH "(14.3)" : $(version) ] || [ MATCH "(14.4)" : $(version) ]'

$patched = 0
foreach ($jam in $targets) {
    # normalize line endings for matching, remember the original kind
    $raw = [System.IO.File]::ReadAllText($jam)
    $crlf = $raw.Contains("`r`n")
    $c = if ($crlf) { $raw } else { $raw.Replace("`n", "`r`n") }

    if ($c.Contains('MSVC' + $bs4 + '14.3')) { Write-Host "already patched: $jam"; continue }

    $orig = $c
    $c = $c.Replace($block142, $block142 + '            ' + $arm143 + "`r`n")
    $c = $c.Replace($verArmOld, $verArmNew)
    if ($c -eq $orig) { Write-Warning "no edits applied: $jam"; continue }

    $out = if ($crlf) { $c } else { $c.Replace("`r`n", "`n") }
    [System.IO.File]::WriteAllText($jam, $out)
    $patched++
    Write-Host "patched: $jam"
}
Write-Host "b2 msvc.jam VS2022 detection: done ($patched file(s) patched)"
