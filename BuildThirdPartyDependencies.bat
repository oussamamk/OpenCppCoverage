@echo off
setlocal

rem ============================================================================
rem Builds the ThirdParty dependency package for x86 and x64.
rem ARM64 is a separate, independent script: BuildArm64Dependencies.bat
rem (split so a late arm64 failure never costs an x86/x64 rerun).
rem
rem Uses the pinned 2020 vcpkg (ed0df8e): official 1.4.0 provenance,
rem boost 1.72 vc142. The final three-arch nupkg is assembled afterwards by
rem Build\Dependencies\assemble-thirdparty-1.5.0.ps1 (called by the arm64
rem script; it also merges the arm64 export).
rem Poco arm64 is NOT produced by either script (needs its own modern-vcpkg
rem port set); InstallThirdPartyLibraries.ps1 merges a Poco arm64 subset
rem after install.
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

rem the pinned generator map (vcpkg_configure_cmake.cmake) has no v143 ->
rem "Visual Studio 17 2022" entries, so any port built WITHOUT PREFER_NINJA
rem (poco) dies with "Unable to determine appropriate generator". Patch it.
rem (Our toolset patch above makes vcpkg pick v143 as preferred toolset.)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\patch-vcpkg-vs2022-generator.ps1" -VcpkgRoot "."

rem the pinned vcpkg acquires cmake 3.14.0, which predates VS2022 and cannot
rem create the "Visual Studio 17 2022" generator ("Could not create named
rem generator"). Copy VS2022's cmake 3.31 over the acquired 3.14 tool.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\repoint-vcpkg-cmake.ps1" -VcpkgRoot "."

rem prefetch jom (needed by openssl-windows): download.qt.io flakes often;
rem qt.mirrorservice.org hosts the same file (same SHA512, no download.qt.io
rem prefix in the path). vcpkg checks downloads\ first, so a cache hit makes
rem the flaky URL irrelevant.
IF NOT EXIST downloads\jom_1_1_3.zip (
	curl -fL -o downloads\jom_1_1_3.zip "https://qt.mirrorservice.org/official_releases/jom/jom_1_1_3.zip"
	IF ERRORLEVEL 1 (echo WARNING: jom prefetch failed - openssl build may hit download.qt.io flakiness)
)

rem zlib and pcre are PocoFoundation's and boost-iostreams' runtime deps;
rem install them explicitly so they never depend on transitive luck.
.\vcpkg install zlib:x64-windows zlib:x86-windows
.\vcpkg install pcre:x64-windows pcre:x86-windows
rem boost-build (b2 1.72) detects the MSVC toolset version from the cl.exe
rem path and only knows 14.1/14.2 - VS2022's 14.3x/14.4x falls through to
rem VC6 and every boost link dies with "'/DLL' is not recognized". Teach b2
rem the new toolsets right after boost-build installs, before any boost port.
.\vcpkg install boost-build:x64-windows boost-build:x86-windows
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build\Dependencies\patch-b2-vs2022-toolset.ps1" -VcpkgRoot "."
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

rem Export the x86/x64 trees now. (arm64 protobuf/gtest/ctemplate
rem installs, modern-vcpkg arm64 boost+zlib, their exports, and the final
rem three-arch assembly live in BuildArm64Dependencies.bat - run it after
rem this script for the complete package.)
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

rem The x86/x64 nupkg above lands in vcpkg\ThirdParty.1.5.0.nupkg.
rem Run BuildArm64Dependencies.bat for the arm64 side + final assembly.
