# Patch the pinned-2020 vcpkg's generator map (vcpkg_configure_cmake.cmake)
# to recognize the v143 platform toolset as "Visual Studio 17 2022".
# Without it, any port built WITHOUT PREFER_NINJA (e.g. poco) dies with
# "Unable to determine appropriate generator for: Windows-x64-v143".
# Ports using PREFER_NINJA (protobuf/gtest/ctemplate/zlib/...) are unaffected.
# Invoked from BuildThirdPartyDependencies.bat with the vcpkg root as arg.
# Idempotent.
param([string]$VcpkgRoot = '.')
$p = Join-Path $VcpkgRoot 'scripts\cmake\vcpkg_configure_cmake.cmake'
$c = [System.IO.File]::ReadAllText($p)
if ($c -match 'Visual Studio 17 2022') {
    Write-Host 'generator map already patched (v143 -> VS17 2022)'
    exit 0
}
$anchor = '    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64" AND VCPKG_PLATFORM_TOOLSET STREQUAL "v142")'
$idx = $c.IndexOf($anchor)
if ($idx -lt 0) { Write-Error 'v142 arm64 anchor not found in generator map'; exit 1 }
$insert = @'
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86" AND VCPKG_PLATFORM_TOOLSET STREQUAL "v143")
        set(GENERATOR "Visual Studio 17 2022")
        set(ARCH "Win32")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64" AND VCPKG_PLATFORM_TOOLSET STREQUAL "v143")
        set(GENERATOR "Visual Studio 17 2022")
        set(ARCH "x64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm" AND VCPKG_PLATFORM_TOOLSET STREQUAL "v143")
        set(GENERATOR "Visual Studio 17 2022")
        set(ARCH "ARM")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64" AND VCPKG_PLATFORM_TOOLSET STREQUAL "v143")
        set(GENERATOR "Visual Studio 17 2022")
        set(ARCH "ARM64")

'@
$insert += $anchor
$c = $c.Substring(0, $idx) + $insert + $c.Substring($idx + $anchor.Length)
[System.IO.File]::WriteAllText($p, $c)
Write-Host "generator map patched: v143 -> Visual Studio 17 2022 ($p)"
