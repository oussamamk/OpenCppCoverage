# InstallThirdPartyLibraries.ps1 - install the C++ third-party dependency package.
#
# Resolution order for ThirdParty.1.5.0.nupkg:
#   1. already-installed package in packages\  -> nothing to do
#   2. local nupkg next to this script         -> install it
#   3. fork's v1.5.0 GitHub release asset      -> download, then install
#
# Run again after a failed download: a partial file is removed before retrying.

$scriptFolder = Split-Path $script:MyInvocation.MyCommand.Path
$NuGetId = 'ThirdParty'
$NuGetVersion = '1.5.0'
$PackagesDir = Join-Path $scriptFolder 'packages'
$Nupkg = Join-Path $scriptFolder "$NuGetId.$NuGetVersion.nupkg"
$InstalledMarker = Join-Path $PackagesDir "$NuGetId.$NuGetVersion\build\native\$NuGetId.targets"
$ForkReleaseUrl = "https://github.com/oussamamk/OpenCppCoverage/releases/download/v$NuGetVersion/$NuGetId.$NuGetVersion.nupkg"

if (Test-Path $InstalledMarker) {
    Write-Host "$NuGetId.$NuGetVersion already installed in packages\ - nothing to do."
} else {
    if (-Not (Test-Path "$scriptFolder\nuget.exe")) {
        Invoke-WebRequest -OutFile "$scriptFolder\nuget.exe" https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
    }

    if (-Not (Test-Path $Nupkg)) {
        Write-Host "Downloading $NuGetId.$NuGetVersion.nupkg from fork release (~458 MB)..."
        Write-Host "  $ForkReleaseUrl"
        # Retry a few times: big assets over flaky links drop mid-transfer.
        $downloaded = $false
        foreach ($attempt in 1..3) {
            try {
                Invoke-WebRequest -OutFile $Nupkg $ForkReleaseUrl
                $downloaded = $true
                break
            } catch {
                # A partial file is worse than none: remove it before retrying.
                if (Test-Path $Nupkg) { Remove-Item $Nupkg -Force }
                Write-Warning "Download attempt $attempt failed: $($_.Exception.Message)"
                Start-Sleep -Seconds 3
            }
        }
        if (-Not $downloaded) {
            Write-Host ""
            Write-Host "ERROR: could not download $NuGetId.$NuGetVersion.nupkg." -ForegroundColor Red
            Write-Host "The fork's v$NuGetVersion release must exist with the nupkg attached:"
            Write-Host "  $ForkReleaseUrl"
            Write-Host ""
            Write-Host "Alternatives:"
            Write-Host "  - Copy an existing $Nupkg file into this folder and rerun, e.g.:"
            Write-Host "      Copy-Item C:\path\to\$NuGetId.$NuGetVersion.nupkg $scriptFolder\"
            Write-Host "  - Publish the v$NuGetVersion release (Releases -> Draft a new release -> tag v$NuGetVersion -> attach the nupkg)."
            exit 1
        }
    }

    Write-Host "Installing $NuGetId.$NuGetVersion into packages\..."
    & "$scriptFolder\nuget.exe" install $NuGetId -Source $scriptFolder -OutputDirectory $PackagesDir
    if ($LASTEXITCODE -ne 0) { throw "nuget install failed" }
}

# The 1.5.0 nupkg lacks arm64 gmock.lib/gmockd.lib under lib\manual-link (the ARM64 GTest
# property sheets link gmock from there). Copy them from lib\ root if they are missing.
if (Test-Path "$scriptFolder\packages\$NuGetId.$NuGetVersion\installed\arm64-windows\lib\gmock.lib" -PathType Leaf) {
    foreach ($pair in @(
        @{ Source = "lib\gmock.lib";          Dest = "lib\manual-link\gmock.lib" },
        @{ Source = "debug\lib\gmockd.lib";   Dest = "debug\lib\manual-link\gmockd.lib" }
    )) {
        $src = "$scriptFolder\packages\$NuGetId.$NuGetVersion\installed\arm64-windows\$($pair.Source)"
        $dst = "$scriptFolder\packages\$NuGetId.$NuGetVersion\installed\arm64-windows\$($pair.Dest)"
        if (-Not (Test-Path $dst -PathType Leaf)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            Copy-Item $src $dst
        }
    }
}

Write-Host "Third-party package ready."
