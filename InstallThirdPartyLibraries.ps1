$scriptFolder = Split-Path $script:MyInvocation.MyCommand.Path

if (-Not (Test-Path "$scriptFolder\nuget.exe")) {
    Invoke-WebRequest -OutFile "$scriptFolder\nuget.exe" https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
}

# Prefer a locally built ThirdParty.1.5.0.nupkg (arm64 support); fall back to the GitHub release.
if (-Not (Test-Path "$scriptFolder\ThirdParty.1.5.0.nupkg")) {
    Invoke-WebRequest -OutFile "$scriptFolder\ThirdParty.1.5.0.nupkg" https://github.com/OpenCppCoverage/OpenCppCoverageThirdParty/releases/download/1.5.0/ThirdParty.1.5.0.nupkg
}

Invoke-Expression "./nuget.exe install ThirdParty -Source $scriptFolder -OutputDirectory packages"

# The 1.5.0 nupkg lacks arm64 gmock.lib/gmockd.lib under lib\manual-link (the ARM64 GTest
# property sheets link gmock from there). Copy them from lib\ root if they are missing.
if (Test-Path "$scriptFolder\packages\ThirdParty.1.5.0\installed\arm64-windows\lib\gmock.lib" -PathType Leaf) {
    foreach ($pair in @(
        @{ Source = "lib\gmock.lib";          Dest = "lib\manual-link\gmock.lib" },
        @{ Source = "debug\lib\gmockd.lib";   Dest = "debug\lib\manual-link\gmockd.lib" }
    )) {
        $src = "$scriptFolder\packages\ThirdParty.1.5.0\installed\arm64-windows\$($pair.Source)"
        $dst = "$scriptFolder\packages\ThirdParty.1.5.0\installed\arm64-windows\$($pair.Dest)"
        if (-Not (Test-Path $dst -PathType Leaf)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
            Copy-Item $src $dst
        }
    }
}
