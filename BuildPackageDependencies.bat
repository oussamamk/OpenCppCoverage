@echo off
setlocal
cd /d "%~dp0"

rem ============================================================================
rem Mints both vcpkg export nupkgs and assembles the final three-arch package.
rem
rem One of four independent scripts (BuildThirdPartyDependencies.bat runs all
rem four in sequence):
rem   Buildx64Dependencies.bat      - pinned vcpkg setup (builds vcpkg.exe) + x64 ports
rem   Buildx86Dependencies.bat      - x86 ports
rem   BuildArm64Dependencies.bat    - arm64 ports (pinned protobuf/gtest/ctemplate,
rem                                   modern boost+zlib)
rem   BuildPackageDependencies.bat  - this script: both exports + final nupkg
rem
rem Requires all three port scripts to have run (their sentinel DLLs are
rem checked below). The exports take minutes; the installs from the port
rem scripts are reused as-is.
rem ============================================================================

SET ROOT_FOLDER=%~dp0/Build/ThirdParty/

rem sentinel check: each port script leaves a distinctive DLL behind
IF NOT EXIST "%ROOT_FOLDER%vcpkg\installed\x64-windows\bin\PocoFoundation.dll" (
	echo ERROR: x64 ports missing - run Buildx64Dependencies.bat first & exit /b 1
)
IF NOT EXIST "%ROOT_FOLDER%vcpkg\installed\x86-windows\bin\PocoFoundation.dll" (
	echo ERROR: x86 ports missing - run Buildx86Dependencies.bat first & exit /b 1
)
IF NOT EXIST "%ROOT_FOLDER%vcpkg\installed\arm64-windows\lib\libprotobuf.lib" (
	echo ERROR: arm64 pinned ports missing - run BuildArm64Dependencies.bat first & exit /b 1
)
IF NOT EXIST "%ROOT_FOLDER%vcpkg-modern\installed\arm64-windows\lib\boost_chrono-vc143-mt-a64-1_92.lib" (
	echo ERROR: arm64 modern ports missing - run BuildArm64Dependencies.bat first & exit /b 1
)

cd Build/ThirdParty\vcpkg

rem re-apply the VS2022 fixes every run (idempotent)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\patch-vcpkg-vs2022-generator.ps1" -VcpkgRoot "."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\repoint-vcpkg-cmake.ps1" -VcpkgRoot "."

rem ---------------------------------------------------------------------------
rem Export 1: x86 + x64 from the pinned vcpkg
rem ---------------------------------------------------------------------------
rem delete any previous nupkg first: vcpkg export refuses to overwrite... it
rem does overwrite, but a FAILED export leaves the old file behind and the
rem IF NOT EXIST below would pass on stale output.
IF EXIST ThirdParty.1.5.0.nupkg del ThirdParty.1.5.0.nupkg
.\vcpkg export ^
	zlib:x64-windows zlib:x86-windows ^
	pcre:x64-windows pcre:x86-windows ^
	poco:x64-windows poco:x86-windows ^
	protobuf:x64-windows protobuf:x86-windows ^
	gtest:x64-windows gtest:x86-windows ^
	ctemplate:x64-windows ctemplate:x86-windows ^
	boost-optional:x64-windows boost-optional:x86-windows ^
	boost-filesystem:x64-windows boost-filesystem:x86-windows ^
	boost-algorithm:x64-windows boost-algorithm:x86-windows ^
	boost-container:x64-windows boost-container:x86-windows ^
	boost-program-options:x64-windows boost-program-options:x86-windows ^
	boost-regex:x64-windows boost-regex:x86-windows ^
	boost-range:x64-windows boost-range:x86-windows ^
	boost-log:x64-windows boost-log:x86-windows ^
	boost-property-tree:x64-windows boost-property-tree:x86-windows ^
	boost-spirit:x64-windows boost-spirit:x86-windows ^
	boost-uuid:x64-windows boost-uuid:x86-windows ^
	boost-locale:x64-windows boost-locale:x86-windows ^
	boost-iostreams:x64-windows boost-iostreams:x86-windows ^
	--nuget --nuget-id=ThirdParty --nuget-version=1.5.0

IF NOT EXIST ThirdParty.1.5.0.nupkg (
	echo ERROR: pinned vcpkg export did not produce ThirdParty.1.5.0.nupkg & exit /b 1
)

rem ---------------------------------------------------------------------------
rem Export 2: arm64 boost+zlib from the modern vcpkg
rem ---------------------------------------------------------------------------
cd ..\vcpkg-modern

IF EXIST ThirdPartyArm64.1.5.0.nupkg del ThirdPartyArm64.1.5.0.nupkg
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

IF NOT EXIST ThirdPartyArm64.1.5.0.nupkg (
	echo ERROR: modern vcpkg export did not produce ThirdPartyArm64.1.5.0.nupkg & exit /b 1
)

rem ---------------------------------------------------------------------------
rem Assemble the final three-arch package into %ROOT_FOLDER%..\..\packages
rem ---------------------------------------------------------------------------
cd ..\..

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\assemble-thirdparty-1.5.0.ps1"
