@echo off
setlocal
cd /d "%~dp0"

rem ============================================================================
rem Builds the ARM64-windows part of the ThirdParty dependency package.
rem
rem One of four independent scripts (BuildThirdPartyDependencies.bat runs all
rem four in sequence):
rem   Buildx64Dependencies.bat      - pinned vcpkg setup (builds vcpkg.exe) + x64 ports
rem   Buildx86Dependencies.bat      - x86 ports
rem   BuildArm64Dependencies.bat    - this script: arm64 ports (pinned
rem                                   protobuf/gtest/ctemplate, modern boost+zlib)
rem   BuildPackageDependencies.bat  - both vcpkg exports + final nupkg assembly
rem
rem Two vcpkg instances:
rem   - vcpkg\        pinned 2020 (ed0df8e), shared with the x64/x86 scripts:
rem                   arm64 protobuf 3.11.2 / gtest 2019-10-09 / ctemplate
rem                   2017-06-23 (ctemplate needs the ARM64 UNALIGNED_LOAD32
rem                   patch, wired automatically every run - the pinned git
rem                   checkout resets the portfile).
rem   - vcpkg-modern\ current master: arm64 compiled boost 1.92 vc143 + zlib
rem                   (the pinned 2020 b2 engine cannot build boost on arm64).
rem Poco arm64 is NOT produced here (needs its own modern-vcpkg port set);
rem InstallThirdPartyLibraries.ps1 merges a Poco arm64 subset after install.
rem ============================================================================

SET ROOT_FOLDER=%~dp0/Build/ThirdParty/

IF NOT EXIST "%ROOT_FOLDER%vcpkg\vcpkg.exe" (
	echo ERROR: %ROOT_FOLDER%vcpkg\vcpkg.exe missing - run Buildx64Dependencies.bat first ^(it sets up pinned vcpkg with the VS2022 fixes^) & exit /b 1
)

cd Build/ThirdParty

IF EXIST vcpkg-modern GOTO MODERN_EXISTS
git clone https://github.com/Microsoft/vcpkg.git vcpkg-modern
:MODERN_EXISTS

rem ---------------------------------------------------------------------------
rem arm64 part 1 (PINNED vcpkg): protobuf/gtest/ctemplate - same provenance as
rem the shipped package; modern vcpkg would give protobuf 6.x with abseil.
rem The ctemplate ARM64 UNALIGNED_LOAD32 patch is re-wired every run (the git
rem checkout above resets the portfile).
rem ---------------------------------------------------------------------------
cd vcpkg
rem re-apply the VS2022 fixes every run (idempotent; the pinned git checkout
rem in the x64 script resets the patched files):
rem   - generator map + cmake repoint matter for non-PREFER_NINJA ports
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\patch-vcpkg-vs2022-generator.ps1" -VcpkgRoot "."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\repoint-vcpkg-cmake.ps1" -VcpkgRoot "."

copy /y "%~dp0Build\Dependencies\ctemplate-fix-arm64-macros.patch" ports\ctemplate\fix-arm64-macros.patch
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\wire-ctemplate-arm64-patch.ps1" -PortDir "ports\ctemplate"
findstr /c:"fix-arm64-macros" ports\ctemplate\portfile.cmake >nul
IF ERRORLEVEL 1 (echo ERROR: ctemplate arm64 patch not wired into portfile.cmake & exit /b 1)

.\vcpkg install protobuf:arm64-windows gtest:arm64-windows ctemplate:arm64-windows

rem ---------------------------------------------------------------------------
rem arm64 part 2: MODERN vcpkg for compiled boost (pinned b2 cannot build
rem boost on arm64 with MSVC 14.4x) + zlib 1.3.x
rem ---------------------------------------------------------------------------
cd ..
cd vcpkg-modern
git fetch
git reset --hard origin/master

IF EXIST vcpkg.exe GOTO MODERN_VCPKG_EXISTS
	call .\bootstrap-vcpkg.bat
	IF NOT EXIST vcpkg.exe (echo ERROR: modern vcpkg bootstrap failed & exit /b 1)
:MODERN_VCPKG_EXISTS

.\vcpkg install zlib:arm64-windows
.\vcpkg install boost-optional:arm64-windows boost-filesystem:arm64-windows
.\vcpkg install boost-algorithm:arm64-windows boost-container:arm64-windows
.\vcpkg install boost-program-options:arm64-windows boost-regex:arm64-windows
.\vcpkg install boost-range:arm64-windows boost-log:arm64-windows
.\vcpkg install boost-property-tree:arm64-windows boost-spirit:arm64-windows
.\vcpkg install boost-uuid:arm64-windows boost-locale:arm64-windows
.\vcpkg install boost-iostreams:arm64-windows

echo arm64 dependencies done - run BuildPackageDependencies.bat next
echo (or BuildThirdPartyDependencies.bat for all).
