@echo off
setlocal

rem ============================================================================
rem Builds the ThirdParty dependency package for x86/x64 via the pinned vcpkg.
rem
rem NOTE (ARM64, 1.5.0+): this script CANNOT regenerate the full 1.5.0 package.
rem The shipped ThirdParty.1.5.0.nupkg was assembled from:
rem   - the official 1.4.0 nupkg (x86/x64 trees, copied byte-identical),
rem   - an arm64-windows tree built with TWO vcpkg instances:
rem       * pinned 2020 vcpkg (ed0df8e): protobuf/gtest/ctemplate (ctemplate
rem         needs an ARM64 UNALIGNED_LOAD32 patch; vcpkg.exe itself must be
rem         built manually with /p:PlatformToolset=v143 on VS2022),
rem       - a modern vcpkg for compiled boost (the 2020 b2 engine fails on
rem         arm64 with MSVC 14.4x),
rem   - an arm64 Poco Foundation subset merged from a separate vcpkg install.
rem Regenerating from scratch requires that process; prefer downloading the
rem package from the fork's v1.5.0 GitHub release instead.
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

downloads\tools\nuget-4.6.2-windows\nuget.exe install ThirdParty -Source %ROOT_FOLDER%\vcpkg -OutputDirectory ..\..\..\packages