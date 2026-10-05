# Assembles the final three-arch ThirdParty.1.6.0 NuGet package.
#
# Strategy: extend the shipped 1.5.0 payload with the branch-coverage
# increments instead of rebuilding every port:
#   - capstone 5.0.9 (x86/x64/arm64) from Build\ThirdParty\vcpkg-modern\installed
#   - pinned-vcpkg arm64 protobuf/gtest/ctemplate (missing from the 1.5.0
#     arm64 tree; needed to build Exporter + test projects for ARM64)
#
# Output: ..\..\packages\ThirdParty.1.6.0\ (installed layout, 1.5.0 payload +
# capstone/gtest increments) and a rezipped ThirdParty.1.6.0.nupkg next to it.
# Poco arm64 is intentionally absent (same as 1.5.0) - the install script
# merges a local Poco subset after package install.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent
$tpDir = Join-Path $repoRoot 'Build\ThirdParty'
$baseNupkg = Join-Path $repoRoot 'ThirdParty.1.5.0.nupkg'
$modernInstalled = Join-Path $tpDir 'vcpkg-modern\installed'
$pinnedInstalled = Join-Path $tpDir 'vcpkg\installed'
$outRoot = Join-Path $repoRoot 'packages'
$installed = Join-Path $outRoot 'ThirdParty.1.6.0'

foreach ($f in ($baseNupkg, "$modernInstalled\arm64-windows\lib\capstone.lib",
                "$modernInstalled\x64-windows\lib\capstone.lib",
                "$modernInstalled\x86-windows\lib\capstone.lib",
                "$pinnedInstalled\arm64-windows\lib\libprotobuf.lib",
                "$pinnedInstalled\arm64-windows\lib\gtest.lib",
                "$pinnedInstalled\arm64-windows\lib\libctemplate.lib")) {
    if (-not (Test-Path $f)) {
        Write-Error "MISSING input: $f"
        exit 1
    }
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

New-Item -ItemType Directory -Force -Path $installed | Out-Null

function Expand-Into($nupkgPath, $destFilter, $destRoot) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($nupkgPath)
    try {
        $n = 0
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -match '/$') { continue }
            if ($entry.FullName -notlike $destFilter) { continue }
            $target = Join-Path $destRoot $entry.FullName
            $tdir = Split-Path $target
            if (-not (Test-Path $tdir)) { New-Item -ItemType Directory -Force -Path $tdir | Out-Null }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
            $n++
        }
        return $n
    } finally { $zip.Dispose() }
}

Write-Host "extracting 1.5.0 base payload..."
$base = Expand-Into $baseNupkg 'installed/*' $installed
Write-Host "  $base files"
$targets = Expand-Into $baseNupkg 'build/*' $installed
$scripts = Expand-Into $baseNupkg 'scripts/*' $installed
$metadata = Expand-Into $baseNupkg 'ThirdParty.nuspec' $installed
$psmdcp = Expand-Into $baseNupkg 'package/*' $installed
Write-Host "  targets: $targets, scripts: $scripts, metadata: $metadata + $psmdcp"

# OPC standard parts ([Content_Types].xml, _rels/.rels) live at the zip root.
# Cannot go through Expand-Into: its -like filter would read [Content_Types]
# as a wildcard character class, so match the literal names instead.
$opc = 0
$zip2 = [System.IO.Compression.ZipFile]::OpenRead($baseNupkg)
try {
    foreach ($entry in $zip2.Entries) {
        if ($entry.FullName -ne '[Content_Types].xml' -and $entry.FullName -ne '_rels/.rels') { continue }
        $target = Join-Path $installed $entry.FullName
        $tdir = Split-Path $target
        if (-not (Test-Path $tdir)) { New-Item -ItemType Directory -Force -Path $tdir | Out-Null }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        $opc++
    }
} finally { $zip2.Dispose() }
Write-Host "OPC parts: $opc"

# vcpkg bookkeeping so the layout matches the official 1.4.0-era structure
if (-not (Test-Path (Join-Path $installed '.vcpkg-root'))) {
    New-Item -ItemType File -Path (Join-Path $installed '.vcpkg-root') | Out-Null
}

# ---------------------------------------------------------------------------
# Increment 1: capstone 5.0.9 for x86/x64/arm64 from the modern vcpkg tree.
# ---------------------------------------------------------------------------
Write-Host "merging capstone x86/x64/arm64 from vcpkg-modern..."
$capFiles = 0
foreach ($triplet in @('x86-windows', 'x64-windows', 'arm64-windows')) {
    $src = Join-Path $modernInstalled $triplet
    $dst = Join-Path $installed "installed\$triplet"
    foreach ($sub in @(
        @{ From = 'include\capstone';   To = 'include\capstone' },
        @{ From = 'lib\capstone.lib';   To = 'lib\capstone.lib' },
        @{ From = 'lib\pkgconfig\capstone.pc'; To = 'lib\pkgconfig\capstone.pc' },
        @{ From = 'bin\capstone.dll';   To = 'bin\capstone.dll' },
        @{ From = 'debug\lib\capstone.lib'; To = 'debug\lib\capstone.lib' },
        @{ From = 'debug\bin\capstone.dll'; To = 'debug\bin\capstone.dll' },
        @{ From = 'share\capstone';     To = 'share\capstone' }
    )) {
        $from = Join-Path $src $sub.From
        if (-not (Test-Path $from)) { continue }
        $to = Join-Path $dst $sub.To
        if (Test-Path $from -PathType Container) {
            Copy-Item $from $to -Recurse -Force
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null
            Copy-Item $from $to -Force
        }
        $capFiles++
    }
}
Write-Host "  capstone merged: $capFiles items"

# ---------------------------------------------------------------------------
# NOTE: no gtest increment. The 1.5.0 payload already carries x86/x64 gmock
# (resolved from its pinned-vcpkg lib\manual-link trees); mixing a modern
# gtest gmockd.lib over the pinned one would break version provenance.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Increment 2: pinned-vcpkg arm64 ports (protobuf 3.11.2 / gtest 2019 /
# ctemplate) - the 1.5.0 package's arm64 tree only ever carried boost+zlib,
# but every project auto-links all libs in the triplet's lib dir and needs
# the headers (Exporter protobuf, TestHelper gtest, ctemplate HTML).
# ---------------------------------------------------------------------------
Write-Host "merging pinned arm64 protobuf/gtest/ctemplate..."
$pinnedFiles = 0
$src = Join-Path $pinnedInstalled 'arm64-windows'
$dst = Join-Path $installed 'installed\arm64-windows'
foreach ($sub in @(
    @{ From = 'include\google';     To = 'include\google' },
    @{ From = 'include\gtest';      To = 'include\gtest' },
    @{ From = 'include\gmock';      To = 'include\gmock' },
    @{ From = 'include\ctemplate';  To = 'include\ctemplate' },
    @{ From = 'lib\libprotobuf.lib';    To = 'lib\libprotobuf.lib' },
    @{ From = 'lib\libprotobuf-lite.lib'; To = 'lib\libprotobuf-lite.lib' },
    @{ From = 'lib\libprotoc.lib';      To = 'lib\libprotoc.lib' },
    @{ From = 'lib\gtest.lib';          To = 'lib\gtest.lib' },
    @{ From = 'lib\gmock.lib';          To = 'lib\gmock.lib' },
    @{ From = 'lib\gtest_main.lib';     To = 'lib\gtest_main.lib' },
    @{ From = 'lib\gmock_main.lib';     To = 'lib\gmock_main.lib' },
    @{ From = 'lib\libctemplate.lib';   To = 'lib\libctemplate.lib' },
    @{ From = 'debug\lib\libprotobufd.lib';  To = 'debug\lib\libprotobufd.lib' },
    @{ From = 'debug\lib\libprotobuf-lited.lib'; To = 'debug\lib\libprotobuf-lited.lib' },
    @{ From = 'debug\lib\libprotocd.lib';    To = 'debug\lib\libprotocd.lib' },
    @{ From = 'debug\lib\gtestd.lib';        To = 'debug\lib\gtestd.lib' },
    @{ From = 'debug\lib\gmockd.lib';        To = 'debug\lib\gmockd.lib' },
    @{ From = 'debug\lib\gtest_maind.lib';   To = 'debug\lib\gtest_maind.lib' },
    @{ From = 'debug\lib\gmock_maind.lib';   To = 'debug\lib\gmock_maind.lib' },
    @{ From = 'debug\lib\libctemplate.lib';  To = 'debug\lib\libctemplate.lib' },
    @{ From = 'bin\libprotobuf.dll';     To = 'bin\libprotobuf.dll' },
    @{ From = 'bin\libprotobuf-lite.dll'; To = 'bin\libprotobuf-lite.dll' },
    @{ From = 'bin\libctemplate.dll';    To = 'bin\libctemplate.dll' },
    @{ From = 'bin\gmock.dll';           To = 'bin\gmock.dll' },
    @{ From = 'bin\gmock_main.dll';      To = 'bin\gmock_main.dll' },
    @{ From = 'bin\gtest.dll';           To = 'bin\gtest.dll' },
    @{ From = 'bin\gtest_main.dll';      To = 'bin\gtest_main.dll' },
    @{ From = 'debug\bin\libprotobufd.dll';  To = 'debug\bin\libprotobufd.dll' },
    @{ From = 'debug\bin\libprotobuf-lited.dll'; To = 'debug\bin\libprotobuf-lited.dll' },
    @{ From = 'debug\bin\libctemplate.dll'; To = 'debug\bin\libctemplate.dll' },
    @{ From = 'debug\bin\gmockd.dll';        To = 'debug\bin\gmockd.dll' },
    @{ From = 'debug\bin\gmock_maind.dll';   To = 'debug\bin\gmock_maind.dll' },
    @{ From = 'debug\bin\gtestd.dll';        To = 'debug\bin\gtestd.dll' },
    @{ From = 'debug\bin\gtest_maind.dll';   To = 'debug\bin\gtest_maind.dll' },
    @{ From = 'tools\protobuf';  To = 'tools\protobuf' }
)) {
    $from = Join-Path $src $sub.From
    if (-not (Test-Path $from)) { continue }
    $to = Join-Path $dst $sub.To
    if (Test-Path $from -PathType Container) {
        Copy-Item $from $to -Recurse -Force
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null
        Copy-Item $from $to -Force
    }
    $pinnedFiles++
}
Write-Host "  pinned arm64 merged: $pinnedFiles items"

# carry vcpkg info bookkeeping for the new packages (best effort)
foreach ($t in @('x86-windows', 'x64-windows', 'arm64-windows')) {
    foreach ($pkg in @('capstone', 'protobuf', 'gtest', 'ctemplate')) {
        $infoSrc = Join-Path $modernInstalled "vcpkg\info\$pkg`_$t.cmake"
        if (-not (Test-Path $infoSrc)) {
            $infoSrc = Join-Path $pinnedInstalled "vcpkg\info\$pkg`_$t.cmake"
        }
        if (Test-Path $infoSrc) {
            $infoDst = Join-Path $installed "installed\vcpkg\info"
            New-Item -ItemType Directory -Force -Path $infoDst | Out-Null
            Copy-Item $infoSrc $infoDst -Force
        }
    }
}

# rezip the assembled tree as ThirdParty.1.6.0.nupkg next to it
$outNupkg = Join-Path $outRoot 'ThirdParty.1.6.0.nupkg'
if (Test-Path $outNupkg) { Remove-Item $outNupkg -Force }
$zip = [System.IO.Compression.ZipFile]::Open($outNupkg, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $n = 0
    Get-ChildItem $installed -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($installed.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        $n++
    }
} finally { $zip.Dispose() }
$size = (Get-Item $outNupkg).Length
Write-Host ""
Write-Host "ASSEMBLED $outNupkg"
Write-Host "  $n files, $([math]::Round($size / 1MB, 1)) MB"
Write-Host "  Poco arm64 absent by design - run InstallThirdPartyLibraries.ps1 after install,"
Write-Host "  or merge the subset into packages\ThirdParty.1.6.0 before shipping (see README)."
