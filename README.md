![](https://github.com/OpenCppCoverage/OpenCppCoverage/workflows/Unit%20tests/badge.svg)
# OpenCppCoverage

OpenCppCoverage is an open source code coverage tool for C++ under Windows.

The main usage is for unit testing coverage, but you can also use it to know the executed lines in a program for debugging purpose.

---------------------
## About this fork

This is an actively maintained fork of [OpenCppCoverage/OpenCppCoverage](https://github.com/OpenCppCoverage/OpenCppCoverage), which the original author retired (archived) around 2025. All credit for the original tool goes to them.

This fork continues from `0.9.9.0` with:

* **ARM64 support**: OpenCppCoverage now builds and runs natively on Windows ARM64 (in addition to x86 and x64). It debugs ARM64-native targets and produces the same HTML and Cobertura reports as on x64. See the notes below.
* Modern toolset builds (Visual Studio 2022, v143).
* Bug fixes surfaced by the toolset bump (e.g. a never-thrown `std::runtime_error` in the unified-diff filter, a dead `<cvt/wstring>` include that broke v143 builds).

### Building for ARM64

* Build with the `ARM64` platform (`msbuild CppCoverage.sln /p:Configuration=Debug /p:Platform=ARM64`). The C++/CLI test project (`TestCppCli`) is excluded from ARM64 configs — classic C++/CLI has no ARM64 target — and CI-style gtest filters still apply.
* Third-party libraries (x86, x64 and `arm64-windows`) ship in the `ThirdParty.1.5.0` NuGet package, hosted in the [OpenCppCoverageThirdParty](https://github.com/oussamamk/OpenCppCoverageThirdParty/releases) repository (the same pattern the upstream project used for its `1.4.0` package) and installed by `InstallThirdPartyLibraries.ps1`.
* Breakpoints use the 4-byte `BRK #0xF000` encoding and the ARM64 PC-adjustment semantics (the breakpoint exception reports the PC at the continuation address), mirroring x64's `--Rip` handling.
* `CreateRelease.bat` assembles a `NewRelease\<arch>\{Binaries,Pdb}` layout for x86, x64 and ARM64 after a Release build.

---------------------
## Original project status (upstream)

The upstream project is no longer actively maintained by its original author; the README below is preserved from upstream. Forks and independent continuation were explicitly welcomed by the original author under the project licence.

**Upstream notice:** the original author stopped active development and maintenance approximately seven years ago after moving away from C++ in their professional work, and formally retired the project: no further releases, bug fixes, or compatibility updates; issues and pull requests not reviewed; support questions may not receive a response; security fixes not expected. The upstream repository and its releases remain available for historical use.

---------------------
## Features:
- **Visual Studio support**: Support compiler with program database file (.pdb).
- **Non intrusive**: Just run your program with OpenCppCoverage, no need to recompile your application.
- **HTML reporting**
- **Line coverage**.
- **Run as Visual Studio Plugin**: See [here](https://github.com/OpenCppCoverage/OpenCppCoveragePlugin) for more information.
- **Jenkins support**: See [here](https://github.com/OpenCppCoverage/OpenCppCoverage/wiki/Jenkins) for more information.
- **Support optimized build**.
- **Exclude a line based on a regular expression**.
- **Child processes coverage**.
- **Coverage aggregation**: Run several code coverages and merge them into a single report.
 
## Requirements
- Windows Vista or higher.
- Microsoft Visual Studio 2008 or higher all editions **including Express edition**. It should also work with previous version of Visual Studio.

## Download
OpenCppCoverage can be downloaded from [here](../../releases).

## Usage
You can simply run the following command:

```OpenCppCoverage.exe --sources MySourcePath* -- YourProgram.exe arg1 arg2```

For example, *MySourcePath* can be *MyProject*, if your sources are located in *C:\Dev\MyProject*.

See [Getting Started](https://github.com/OpenCppCoverage/OpenCppCoverage/wiki) for more information about the usage.
You can also have a look at [Command-line reference](https://github.com/OpenCppCoverage/OpenCppCoverage/wiki/Command-line-reference).
