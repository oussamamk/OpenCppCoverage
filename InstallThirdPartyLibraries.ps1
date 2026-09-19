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
$ForkReleaseUrl = "https://github.com/oussamamk/OpenCppCoverageThirdParty/releases/download/$NuGetVersion/$NuGetId.$NuGetVersion.nupkg"

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

# The 1.5.0 nupkg lacks arm64 Poco Foundation headers/libs (TestHelper includes
# Poco/Process.h; the x86/x64 trees carry Poco from 1.4.0, the arm64 tree was
# assembled without it). Merge the subset from a local vcpkg arm64 install if
# one exists; without it ARM64 builds of TestHelper/TestCoverageConsole fail.
$PocoMarker = "$scriptFolder\packages\$NuGetId.$NuGetVersion\installed\arm64-windows\include\Poco"
if (-Not (Test-Path $PocoMarker)) {
    $vcpkgPoco = 'C:\tools\vcpkg\installed\arm64-windows'
    if (Test-Path "$vcpkgPoco\include\Poco" -PathType Container) {
        Write-Host "Merging arm64 Poco Foundation subset from $vcpkgPoco (not in the 1.5.0 nupkg)..."
        $dst = "$scriptFolder\packages\$NuGetId.$NuGetVersion\installed\arm64-windows"
        $merges = @(
            @{ From = "$vcpkgPoco\include\Poco";            To = "$dst\include\Poco" }
            @{ From = "$vcpkgPoco\lib\PocoFoundation.lib";  To = "$dst\lib\PocoFoundation.lib" }
            @{ From = "$vcpkgPoco\debug\lib\PocoFoundationd.lib"; To = "$dst\debug\lib\PocoFoundationd.lib" }
            @{ From = "$vcpkgPoco\share\poco";              To = "$dst\share\poco" }
        )
        foreach ($f in @('PocoFoundation.dll', 'PocoFoundation.pdb', 'pcre2-8.dll', 'pcre2-16.dll',
                         'pcre2-32.dll', 'pcre2-posix.dll', 'utf8proc.dll')) {
            $merges += @{ From = "$vcpkgPoco\bin\$f"; To = "$dst\bin\$f" }
        }
        foreach ($f in @('PocoFoundationd.dll', 'PocoFoundationd.pdb', 'pcre2-8d.dll', 'pcre2-16d.dll',
                         'pcre2-32d.dll', 'pcre2-posixd.dll', 'utf8proc.dll')) {
            $merges += @{ From = "$vcpkgPoco\debug\bin\$f"; To = "$dst\debug\bin\$f" }
        }
        foreach ($m in $merges) {
            if (-Not (Test-Path $m.From)) { continue }   # optional piece (e.g. pcre2 variant)
            if (Test-Path $m.From -PathType Container) {
                Copy-Item $m.From $m.To -Recurse -Force
            } else {
                New-Item -ItemType Directory -Force -Path (Split-Path $m.To) | Out-Null
                Copy-Item $m.From $m.To -Force
            }
        }
        Write-Host "  arm64 Poco merged."
    } else {
        Write-Warning @"
arm64 Poco is missing from the installed package (needed to build TestHelper/
TestCoverageConsole for ARM64). Install it into a local vcpkg first:
    vcpkg install poco:arm64-windows
so that $vcpkgPoco\include\Poco exists, then rerun this script.
"@
    }
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
