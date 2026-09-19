# Assembles the final three-arch ThirdParty.1.5.0 NuGet package from the two
# vcpkg exports minted by BuildThirdPartyDependencies.bat:
#   Build\ThirdParty\vcpkg\ThirdParty.1.5.0.nupkg         (x86 + x64 + pinned bookkeeping)
#   Build\ThirdParty\vcpkg-modern\ThirdPartyArm64.1.5.0.nupkg (arm64-windows)
#
# Output: ..\packages\ThirdParty.1.5.0\ (installed layout) with
# arm64 entries merged over x86/x64 (disjoint trees - no clobbering),
# and a ThirdParty.1.5.0.nupkg rezipped in the same layout.
# Poco arm64 is intentionally absent (see bat header) - the install script
# merges a local Poco subset after package install.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent
$tpDir = Join-Path $repoRoot 'Build\ThirdParty'
$oldNupkg = Join-Path $tpDir 'vcpkg\ThirdParty.1.5.0.nupkg'
$a64Nupkg = Join-Path $tpDir 'vcpkg-modern\ThirdPartyArm64.1.5.0.nupkg'
$outRoot = Join-Path $repoRoot 'packages'
$installed = Join-Path $outRoot 'ThirdParty.1.5.0'

foreach ($f in ($oldNupkg, $a64Nupkg)) {
    if (-not (Test-Path $f)) {
        Write-Error "MISSING export: $f (did both vcpkg export steps succeed?)"
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

Write-Host "extracting x86/x64 export..."
$x86x64 = Expand-Into $oldNupkg 'installed/*' $installed
Write-Host "  $x86x64 files"
Write-Host "extracting arm64 export (merged over, disjoint trees)..."
$a64 = Expand-Into $a64Nupkg 'installed/arm64-windows/*' $installed
Write-Host "  $a64 files"

# vcpkg bookkeeping so the layout matches the official 1.4.0-era structure
$vcpkgA64 = Expand-Into $a64Nupkg 'installed/vcpkg/info/*' $installed
$installedVcpkgInfo = Join-Path $installed 'installed\vcpkg\info'
Write-Host "vcpkg bookkeeping (arm64 info): $vcpkgA64 entries"

# .vcpkg-root marker (GetDirectoryNameOfFileAbove walks for it)
if (-not (Test-Path (Join-Path $installed '.vcpkg-root'))) {
    New-Item -ItemType File -Path (Join-Path $installed '.vcpkg-root') | Out-Null
}

# carry build/native targets + scripts from the x86/x64 export if not yet extracted
$targets = Expand-Into $oldNupkg 'build/*' $installed
$scripts = Expand-Into $oldNupkg 'scripts/*' $installed
$metadata = Expand-Into $oldNupkg 'ThirdParty.nuspec' $installed
$psmdcp = Expand-Into $oldNupkg 'package/*' $installed
Write-Host "targets: $targets, scripts: $scripts, metadata: $metadata + $psmdcp"

# rezip the assembled tree as ThirdParty.1.5.0.nupkg next to it
$outNupkg = Join-Path $outRoot 'ThirdParty.1.5.0.nupkg'
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
Write-Host "  or merge the subset into packages\ThirdParty.1.5.0 before shipping (see README)."
