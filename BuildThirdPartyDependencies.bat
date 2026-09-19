@echo off
setlocal
cd /d "%~dp0"

rem ============================================================================
rem Builds the complete ThirdParty dependency package for all three arches by
rem running the four independent scripts in sequence:
rem
rem   Buildx64Dependencies.bat      1. pinned vcpkg setup + x64 ports
rem   Buildx86Dependencies.bat      2. x86 ports
rem   BuildArm64Dependencies.bat    3. arm64 ports
rem   BuildPackageDependencies.bat  4. both vcpkg exports + final nupkg
rem
rem Each script can also be triggered on its own (in that order) - a rerun
rem reuses the already-installed ports, so you can resume after a failure
rem without repeating the whole pipeline.
rem
rem Uses the pinned 2020 vcpkg (ed0df8e) for x86/x64 provenance (boost 1.72
rem vc142) and for arm64 protobuf/gtest/ctemplate; a modern-vcpkg instance
rem builds arm64 boost+zlib. The final three-arch nupkg is assembled by
rem Build\Dependencies\assemble-thirdparty-1.5.0.ps1 into packages\.
rem Poco arm64 is NOT produced by any script (needs its own modern-vcpkg port
rem set); InstallThirdPartyLibraries.ps1 merges a Poco arm64 subset after
rem install.
rem
rem VS2022-only machines are handled inside Buildx64Dependencies.bat: the
rem pinned vcpkg.exe is built from toolsrc (v143 toolset) and its toolset
rem detection is patched to recognize MSVC 14.3x/14.4x as v143.
rem ============================================================================

call "%~dp0Buildx64Dependencies.bat"
IF ERRORLEVEL 1 (echo ERROR: Buildx64Dependencies.bat failed & exit /b 1)

call "%~dp0Buildx86Dependencies.bat"
IF ERRORLEVEL 1 (echo ERROR: Buildx86Dependencies.bat failed & exit /b 1)

call "%~dp0BuildArm64Dependencies.bat"
IF ERRORLEVEL 1 (echo ERROR: BuildArm64Dependencies.bat failed & exit /b 1)

call "%~dp0BuildPackageDependencies.bat"
IF ERRORLEVEL 1 (echo ERROR: BuildPackageDependencies.bat failed & exit /b 1)

echo.
echo ALL DONE: packages\ThirdParty.1.5.0.nupkg
