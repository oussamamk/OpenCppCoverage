$scriptFolder = Split-Path $script:MyInvocation.MyCommand.Path

if (-Not (Test-Path "$scriptFolder\nuget.exe")) {
    Invoke-WebRequest -OutFile "$scriptFolder\nuget.exe" https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
}

# Prefer a locally built ThirdParty.1.5.0.nupkg (arm64 support); fall back to the GitHub release.
if (-Not (Test-Path "$scriptFolder\ThirdParty.1.5.0.nupkg")) {
    Invoke-WebRequest -OutFile "$scriptFolder\ThirdParty.1.5.0.nupkg" https://github.com/OpenCppCoverage/OpenCppCoverageThirdParty/releases/download/1.5.0/ThirdParty.1.5.0.nupkg
}

Invoke-Expression "./nuget.exe install ThirdParty -Source $scriptFolder -OutputDirectory packages"
