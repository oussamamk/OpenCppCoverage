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
* `CreateInstallers.py` builds per-arch Inno Setup installers (`OpenCppCoverageSetup-<arch>-0.9.9.0.exe`) from that layout.

### Build procedure from scratch (any machine)

Prerequisites:
* Visual Studio 2022 with the C++ toolset (the DIA SDK ships with VS).
* [Inno Setup 6](https://jrsoftware.org/isinfo.php) for the installers only: `winget install JRSoftware.InnoSetup`.
* Internet access on the first run: the third-party NuGet package (~500 MB) and the per-arch `vc_redist` binaries are downloaded once and cached.

One-shot deps + build + package (downloads the `ThirdParty.1.5.0` NuGet package from the [OpenCppCoverageThirdParty](https://github.com/oussamamk/OpenCppCoverageThirdParty/releases) release, builds, auto-retries transient PCH failures on memory-constrained machines, and assembles the `NewRelease` layout):

```powershell
.\BuildEnvironment.ps1 -Configuration Release -Platforms x64,ARM64 -Package
```

Add `-Platforms x86,x64,ARM64` to build all three architectures. Run the same script again after a fresh clone on any machine — it skips what is already installed.

Building Inno Setup installers from the assembled layout (requires Inno Setup 6, `ISCC.exe` is auto-detected; the first run downloads `vc_redist.x86/x64/arm64.exe` from `aka.ms` and caches them in `NewRelease\Installers\`):

```powershell
python CreateInstallers.py --release-root .\NewRelease
```

Outputs: `NewRelease\Installers\OpenCppCoverageSetup-{x86,x64,ARM64}-0.9.9.0.exe`. Each installer carries its arch's runtime files, the original wizard images/icon, a silent `vc_redist.<arch>` install, the `Plugins\Exporter` directory and an optional "add to PATH" task — the same layout as the original upstream setup.

Manual equivalent (what the scripts automate):

```powershell
.\InstallThirdPartyLibraries.ps1                     # deps once per clone
msbuild CppCoverage.sln /m /p:Configuration=Release /p:Platform=Win32
msbuild CppCoverage.sln /m /p:Configuration=Release /p:Platform=x64
msbuild CppCoverage.sln /m /p:Configuration=Release /p:Platform=ARM64
cmd /c "CreateRelease.bat < NUL"                     # NewRelease\<arch>\{Binaries,Pdb}
python CreateInstallers.py --release-root .\NewRelease
```

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
