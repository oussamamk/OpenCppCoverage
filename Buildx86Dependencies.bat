@echo off
setlocal
cd /d "%~dp0"

rem ============================================================================
rem Builds the x86-windows part of the ThirdParty dependency package.
rem
rem One of four independent scripts (BuildThirdPartyDependencies.bat runs all
rem four in sequence):
rem   Buildx64Dependencies.bat      - pinned vcpkg setup (builds vcpkg.exe) + x64 ports
rem   Buildx86Dependencies.bat      - this script: x86 ports
rem   BuildArm64Dependencies.bat    - arm64 ports (pinned protobuf/gtest/ctemplate,
rem                                   modern boost+zlib)
rem   BuildPackageDependencies.bat  - both vcpkg exports + final nupkg assembly
rem
rem Run Buildx64Dependencies.bat first - this script reuses the pinned vcpkg
rem checkout and the vcpkg.exe it produces.
rem ============================================================================

SET ROOT_FOLDER=%~dp0/Build/ThirdParty/

IF NOT EXIST "%ROOT_FOLDER%vcpkg\vcpkg.exe" (
	echo ERROR: %ROOT_FOLDER%vcpkg\vcpkg.exe missing - run Buildx64Dependencies.bat first ^(it sets up pinned vcpkg with the VS2022 fixes^) & exit /b 1
)

cd Build/ThirdParty\vcpkg

rem re-apply the VS2022 fixes every run (idempotent; the pinned git checkout
rem in the x64 script resets the patched files):
rem   - generator map + cmake repoint matter for non-PREFER_NINJA ports
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\patch-vcpkg-vs2022-generator.ps1" -VcpkgRoot "."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\repoint-vcpkg-cmake.ps1" -VcpkgRoot "."

rem zlib and pcre are PocoFoundation's and boost-iostreams' runtime deps;
rem install them explicitly so they never depend on transitive luck.
.\vcpkg install zlib:x86-windows
.\vcpkg install pcre:x86-windows
rem boost-build (b2 1.72) toolset fix must also land in the x86 tool copy
rem before any x86 boost port links.
.\vcpkg install boost-build:x86-windows
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\patch-b2-vs2022-toolset.ps1" -VcpkgRoot "."
.\vcpkg install poco:x86-windows
.\vcpkg install protobuf:x86-windows
.\vcpkg install gtest:x86-windows
.\vcpkg install ctemplate:x86-windows
.\vcpkg install boost-optional:x86-windows
.\vcpkg install boost-filesystem:x86-windows
.\vcpkg install boost-algorithm:x86-windows
.\vcpkg install boost-container:x86-windows
.\vcpkg install boost-program-options:x86-windows
.\vcpkg install boost-regex:x86-windows
.\vcpkg install boost-range:x86-windows
.\vcpkg install boost-log:x86-windows
.\vcpkg install boost-property-tree:x86-windows
.\vcpkg install boost-spirit:x86-windows
.\vcpkg install boost-uuid:x86-windows
.\vcpkg install boost-locale:x86-windows
.\vcpkg install boost-iostreams:x86-windows

echo x86 dependencies done - run BuildArm64Dependencies.bat and
echo BuildPackageDependencies.bat next (or BuildThirdPartyDependencies.bat for all).
