# BuildEnvironment.ps1 - full from-scratch environment setup + build + release packaging.
#
# Usage (from repo root, in a PowerShell with VS2022's v143 toolset installed):
#   .\BuildEnvironment.ps1                       # deps + Debug build
#   .\BuildEnvironment.ps1 -Configuration Release -Platforms x64,ARM64 -Package
#   .\BuildEnvironment.ps1 -SkipDeps             # packages\ already installed
#
# Steps:
#   1. nuget.exe + ThirdParty.1.5.0 nupkg (local file > fork release download)
#      and install into packages\
#   2. msbuild the solution for each requested platform
#   3. optionally run CreateRelease.bat to assemble NewRelease\<arch>\{Binaries,Pdb}
#
# Requires: VS2022 (v143, ARM64 build tools, DIA SDK), internet for first run.

param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    # Platforms must be spelled as solution platforms: x86, x64, ARM64.
    [string[]]$Platforms = @('x64', 'ARM64'),
    [switch]$Package,          # run CreateRelease.bat after a Release build
    [switch]$SkipDeps          # packages\thirdparty.1.5.0 already installed
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $script:MyInvocation.MyCommand.Path
Set-Location $repoRoot

$NuGetId = 'ThirdParty'
$NuGetVersion = '1.5.0'
$PackagesDir = Join-Path $repoRoot 'packages'
$InstalledMarker = Join-Path $PackagesDir "$NuGetId.$NuGetVersion\build\native\$NuGetId.targets"
$ForkReleaseUrl = "https://github.com/oussamamk/OpenCppCoverage/releases/download/v$NuGetVersion/$NuGetId.$NuGetVersion.nupkg"

function Ensure-NuGet {
    $nuget = Join-Path $repoRoot 'nuget.exe'
    if (-Not (Test-Path $nuget)) {
        Write-Host "==> Downloading nuget.exe"
        Invoke-WebRequest -OutFile $nuget https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
    }
    return $nuget
}

function Ensure-ThirdParty {
    if (Test-Path $InstalledMarker) {
        Write-Host "==> $NuGetId.$NuGetVersion already installed in packages\ - skipping"
        return
    }

    # Local nupkg (offline / faster) beats downloading from the fork release.
    $nupkg = Join-Path $repoRoot "$NuGetId.$NuGetVersion.nupkg"
    if (-Not (Test-Path $nupkg)) {
        Write-Host "==> Downloading $NuGetId.$NuGetVersion.nupkg from fork release (~458 MB)"
        Invoke-WebRequest -OutFile $nupkg $ForkReleaseUrl
    }

    $nuget = Ensure-NuGet
    Write-Host "==> Installing $NuGetId.$NuGetVersion into packages\"
    & $nuget install $NuGetId -Source $repoRoot -OutputDirectory $PackagesDir
    if ($LASTEXITCODE -ne 0) { throw "nuget install failed" }

    # Post-install fixups (same as InstallThirdPartyLibraries.ps1):
    # arm64 gmock manual-link copies, then the standard install script for anything else.
    $pkgRoot = Join-Path $PackagesDir "$NuGetId.$NuGetVersion\installed\arm64-windows"
    foreach ($pair in @(
        @{ Source = 'lib\gmock.lib';        Dest = 'lib\manual-link\gmock.lib' },
        @{ Source = 'debug\lib\gmockd.lib'; Dest = 'debug\lib\manual-link\gmockd.lib' }
    )) {
        $src = Join-Path $pkgRoot $pair.Source
        $dst = Join-Path $pkgRoot $pair.Dest
        if ((Test-Path $src) -and -Not (Test-Path $dst)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            Copy-Item $src $dst
        }
    }
    Write-Host "==> Third-party package ready"
}

function Find-MsBuild {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-Not (Test-Path $vswhere)) { throw "vswhere not found - is Visual Studio installed?" }
    $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild `
        -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
    if (-Not $msbuild) { throw "MSBuild not found - install VS2022 with the C++ workload" }
    return $msbuild
}

function Build-Platform {
    param([string]$Platform)
    $msbuild = Find-MsBuild
    Write-Host "==> msbuild $Configuration|$Platform"
    # /m:1 avoids transient PCH C3859/C1076 heap failures on low-RAM machines.
    & $msbuild CppCoverage.sln "/p:Configuration=$Configuration" "/p:Platform=$Platform" /m:1 /nologo /v:m
    if ($LASTEXITCODE -ne 0) { throw "msbuild failed for $Platform" }
    Write-Host "==> $Platform build OK"
}

function Package-Release {
    if ($Configuration -ne 'Release') {
        Write-Warning "Package requested but Configuration is $Configuration - skipping (CreateRelease.bat copies Release trees)"
        return
    }
    Write-Host "==> Running CreateRelease.bat"
    cmd /c "CreateRelease.bat < NUL"
}

# ---------------------------------------------------------------------------
Ensure-ThirdParty
foreach ($p in $Platforms) { Build-Platform -Platform $p }
if ($Package) { Package-Release }

Write-Host ""
Write-Host "Done. Outputs:"
foreach ($p in $Platforms) { Write-Host "  $p\$Configuration\" }
if ($Package) { Write-Host "  NewRelease\<arch>\{Binaries,Pdb} - zip it and attach to a GitHub release" }
