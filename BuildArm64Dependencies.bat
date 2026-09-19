@echo off
setlocal

rem ============================================================================
rem Builds the ARM64-windows part of the ThirdParty dependency package.
rem Split out of BuildThirdPartyDependencies.bat so x86/x64 and arm64 runs are
rem independent (the full package takes hours; failing late in arm64 should
rem not cost an x86/x64 rerun).
rem
rem Two vcpkg instances:
rem   - vcpkg\        pinned 2020 (ed0df8e), shared with the x86/x64 bat:
rem                   arm64 protobuf 3.11.2 / gtest 2019-10-09 / ctemplate
rem                   2017-06-23 (ctemplate needs the ARM64 UNALIGNED_LOAD32
rem                   patch, wired automatically every run - the pinned git
rem                   checkout resets the portfile).
rem   - vcpkg-modern\ current master: arm64 compiled boost 1.92 vc143 + zlib
rem                   (the pinned 2020 b2 engine cannot build boost on arm64).
rem Exports land next to the x86/x64 ones and
rem Build\Dependencies\assemble-thirdparty-1.5.0.ps1 merges everything into
rem packages\ThirdParty.1.5.0\ + ThirdParty.1.5.0.nupkg.
rem Poco arm64 is NOT produced here (needs its own modern-vcpkg port set);
rem InstallThirdPartyLibraries.ps1 merges a Poco arm64 subset after install.
rem
rem Requires the pinned vcpkg from the x86/x64 bat (vcpkg\vcpkg.exe with the
rem VS2022 fixes) - run BuildThirdPartyDependencies.bat once first, or this
rem script clones+fixes it automatically.
rem ============================================================================

SET ROOT_FOLDER=%~dp0/Build/ThirdParty/

IF EXIST "%ROOT_FOLDER%" GOTO THIRD_PARTY_EXISTS
mkdir "%ROOT_FOLDER%"
:THIRD_PARTY_EXISTS

cd Build/ThirdParty

IF EXIST vcpkg GOTO REPO_EXISTS
git clone https://github.com/Microsoft/vcpkg.git
:REPO_EXISTS

cd vcpkg
git fetch
git checkout ed0df8ecc4ed7e755ea03e18aaf285fd9b4b4a74 .

IF NOT EXIST vcpkg.exe (
	echo ERROR: pinned vcpkg.exe missing - run BuildThirdPartyDependencies.bat first ^(it builds vcpkg.exe with the VS2022 fixes^) & exit /b 1
)

rem re-apply the VS2022 fixes every run (idempotent; the git checkout above
rem resets the patched files):
rem   - toolset detection in the vcpkg.exe source only matters for rebuilds
rem   - generator map + cmake repoint matter for non-PREFER_NINJA ports
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\patch-vcpkg-vs2022-generator.ps1" -VcpkgRoot "."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\repoint-vcpkg-cmake.ps1" -VcpkgRoot "."

rem prefetch jom (openssl) - same file as the x86/x64 bat, shared cache
IF NOT EXIST downloads\jom_1_1_3.zip (
	curl -fL -o downloads\jom_1_1_3.zip "https://qt.mirrorservice.org/official_releases/jom/jom_1_1_3.zip"
	IF ERRORLEVEL 1 (echo WARNING: jom prefetch failed - openssl build may hit download.qt.io flakiness)
)

rem ---------------------------------------------------------------------------
rem arm64 part 1 (PINNED vcpkg): protobuf/gtest/ctemplate - same provenance as
rem the shipped package; modern vcpkg would give protobuf 6.x with abseil.
rem The ctemplate ARM64 UNALIGNED_LOAD32 patch is re-wired every run (the git
rem checkout above resets the portfile).
rem ---------------------------------------------------------------------------
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
IF EXIST vcpkg-modern GOTO MODERN_EXISTS
git clone https://github.com/Microsoft/vcpkg.git vcpkg-modern
:MODERN_EXISTS
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

.\vcpkg export ^
	zlib:arm64-windows ^
	boost-optional:arm64-windows ^
	boost-filesystem:arm64-windows ^
	boost-algorithm:arm64-windows ^
	boost-container:arm64-windows ^
	boost-program-options:arm64-windows ^
	boost-regex:arm64-windows ^
	boost-range:arm64-windows ^
	boost-log:arm64-windows ^
	boost-property-tree:arm64-windows ^
	boost-spirit:arm64-windows ^
	boost-uuid:arm64-windows ^
	boost-locale:arm64-windows ^
	boost-iostreams:arm64-windows ^
	--nuget --nuget-id=ThirdPartyArm64 --nuget-version=1.5.0

rem ---------------------------------------------------------------------------
rem Assemble the final three-arch package into %ROOT_FOLDER%..\..\packages
rem ---------------------------------------------------------------------------
cd ..

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\assemble-thirdparty-1.5.0.ps1"
