@echo off
setlocal

rem ============================================================================
rem Builds the ThirdParty dependency package for x86, x64 AND arm64-windows.
rem
rem Two vcpkg instances:
rem   - vcpkg\       pinned 2020 (ed0df8e): x86/x64 trees (official 1.4.0
rem                  provenance, boost 1.72 vc142) + arm64 protobuf/gtest/
rem                  ctemplate (ctemplate needs the ARM64 UNALIGNED_LOAD32
rem                  patch, applied automatically).
rem   - vcpkg-modern current master: arm64 compiled boost (1.92 vc143) - the
rem                  pinned 2020 b2 engine cannot build boost on arm64 with
rem                  MSVC 14.4x.
rem The final nupkg is assembled by merging both instances' exports.
rem Poco arm64 is NOT produced here (needs its own modern-vcpkg port set);
rem InstallThirdPartyLibraries.ps1 merges a Poco arm64 subset from a local
rem vcpkg after install, or bake it into the nupkg afterwards (see README).
rem
rem VS2022-only machines: the pinned vcpkg bootstrap fails, so vcpkg.exe is
rem built from toolsrc (v143 toolset) and its toolset detection is patched
rem to recognize MSVC 14.3x/14.4x as v143. Both steps are automated below.
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

IF EXIST vcpkg.exe GOTO VCPKG_EXISTS
rem The pinned-2020 vcpkg needs two fixes on a VS2022-only machine:
rem 1) bootstrap.ps1 only knows VS2015/2017/2019 and throws -> build vcpkg.exe
rem    from toolsrc with the v143 toolset (MSBuild via vswhere, installed SDK).
rem 2) its toolset detection skips MSVC 14.3x/14.4x ("unknown toolset minor
rem    version") -> patch visualstudio.cpp to map 14.3x/14.4x to v143.
rem 2) must be applied BEFORE 1) rebuilds the exe.
set "VS_SRC=toolsrc\src\vcpkg\visualstudio.cpp"
copy /y "%VS_SRC%" "%VS_SRC%.orig" >nul
python "%~dp0Build\Dependencies\vcpkg-visualstudio-toolset-patch.py"
	rem 1) try bootstrap first (works when VS2015/2017/2019 exists)
	call .\bootstrap-vcpkg.bat
	IF EXIST vcpkg.exe GOTO VCPKG_EXISTS
	echo bootstrap failed - building vcpkg.exe from toolsrc with PlatformToolset=v143 ...
	rem locate msbuild via vswhere
	set "MSBUILD="
	for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`) do set "MSBUILD=%%i"
	IF NOT DEFINED MSBUILD (echo ERROR: msbuild not found via vswhere & exit /b 1)
	rem pinned project targets SDK 8.1 which a VS2022 machine may not have;
	rem override to the installed Win10/11 SDK
	set "SDKVER="
	for /f "usebackq delims=" %%i in (`reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0" /v ProductVersion 2^>nul ^| findstr /r "[0-9]*\.[0-9]*\.[0-9]*"`) do (
		for /f "tokens=3" %%j in ("%%i") do set "SDKVER=%%j"
	)
	IF NOT DEFINED SDKVER set "SDKVER=10.0"
	"%MSBUILD%" toolsrc\vcpkg.sln /p:Configuration=Release /p:PlatformToolset=v143 /p:WindowsTargetPlatformVersion=%SDKVER% /m /nologo /v:m
	IF ERRORLEVEL 1 (echo ERROR: building vcpkg.exe from toolsrc flat build failed & exit /b 1)
	copy /y toolsrc\msbuild.x64.release\vcpkg.exe vcpkg.exe
:VCPKG_EXISTS

rem prefetch jom (needed by openssl-windows): download.qt.io flakes often;
rem qt.mirrorservice.org hosts the same file (same SHA512, no download.qt.io
rem prefix in the path). vcpkg checks downloads\ first, so a cache hit makes
rem the flaky URL irrelevant.
IF NOT EXIST downloads\jom_1_1_3.zip (
	curl -fL -o downloads\jom_1_1_3.zip "https://qt.mirrorservice.org/official_releases/jom/jom_1_1_3.zip"
	IF ERRORLEVEL 1 (echo WARNING: jom prefetch failed - openssl build may hit download.qt.io flakiness)
)

.\vcpkg install poco:x64-windows poco:x86-windows
.\vcpkg install protobuf:x64-windows protobuf:x86-windows
.\vcpkg install gtest:x64-windows gtest:x86-windows
.\vcpkg install ctemplate:x64-windows ctemplate:x86-windows
.\vcpkg install boost-optional:x64-windows boost-optional:x86-windows
.\vcpkg install boost-filesystem:x64-windows boost-filesystem:x86-windows
.\vcpkg install boost-algorithm:x64-windows boost-algorithm:x86-windows
.\vcpkg install boost-container:x64-windows boost-container:x86-windows
.\vcpkg install boost-program-options:x64-windows boost-program-options:x86-windows
.\vcpkg install boost-regex:x64-windows boost-regex:x86-windows
.\vcpkg install boost-range:x64-windows boost-range:x86-windows
.\vcpkg install boost-log:x64-windows boost-log:x86-windows
.\vcpkg install boost-property-tree:x64-windows boost-property-tree:x86-windows
.\vcpkg install boost-spirit:x64-windows boost-spirit:x86-windows
.\vcpkg install boost-uuid:x64-windows boost-uuid:x86-windows
.\vcpkg install boost-locale:x64-windows boost-locale:x86-windows
.\vcpkg install boost-iostreams:x64-windows boost-iostreams:x86-windows
  
.\vcpkg export ^
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

rem ---------------------------------------------------------------------------
rem arm64-windows: modern vcpkg (compiled boost 1.92 vc143 + protobuf/gtest/
rem ctemplate 3.11.2/2019-10-09/2017-06-23 to match the pinned instance)
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

rem ctemplate ARM64 UNALIGNED_LOAD32 patch: applied to the port before install
IF EXIST ports\ctemplate\fix-arm64-macros.patch GOTO CTEMPLATE_PATCHED
copy /y "%~dp0Build\Dependencies\ctemplate-fix-arm64-macros.patch" ports\ctemplate\fix-arm64-macros.patch
rem add it to the port's patch list
powershell -NoProfile -Command "(Get-Content ports\ctemplate\portfile.cmake) -replace 'PATCHES', 'PATCHES fix-arm64-macros.patch' | Set-Content ports\ctemplate\portfile.cmake"
:CTEMPLATE_PATCHED

.\vcpkg install protobuf:arm64-windows gtest:arm64-windows ctemplate:arm64-windows
.\vcpkg install boost-optional:arm64-windows boost-filesystem:arm64-windows
.\vcpkg install boost-algorithm:arm64-windows boost-container:arm64-windows
.\vcpkg install boost-program-options:arm64-windows boost-regex:arm64-windows
.\vcpkg install boost-range:arm64-windows boost-log:arm64-windows
.\vcpkg install boost-property-tree:arm64-windows boost-spirit:arm64-windows
.\vcpkg install boost-uuid:arm64-windows boost-locale:arm64-windows
.\vcpkg install boost-iostreams:arm64-windows

.\vcpkg export ^
	protobuf:arm64-windows ^
	gtest:arm64-windows ^
	ctemplate:arm64-windows ^
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
rem Assemble the final three-arch package into ..\..\..\packages
rem ---------------------------------------------------------------------------
cd ..

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\assemble-thirdparty-1.5.0.ps1"