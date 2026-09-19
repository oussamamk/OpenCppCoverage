@echo off
rem Assemble the release layout for all architectures.
rem Prerequisites: build Release for Win32, x64 and ARM64 first:
rem   msbuild CppCoverage.sln /p:Configuration=Release /p:Platform=Win32
rem   msbuild CppCoverage.sln /p:Configuration=Release /p:Platform=x64
rem   msbuild CppCoverage.sln /p:Configuration=Release /p:Platform=ARM64
rem (TestCppCli is excluded from ARM64 configs by the solution.)
rem The bat must run from the solution root; outputs land in NewRelease\<arch>\.

setlocal
set ERROR=0

rem ---------------------------------------------------------------------------
rem x86 (source dir: Release\ -- the Win32 build lands in the solution root)
rem ---------------------------------------------------------------------------
set X86=Release
if not exist %X86%\OpenCppCoverage.exe (echo MISSING %X86%& set ERROR=1& goto :eof)

mkdir NewRelease\x86\Binaries
mkdir NewRelease\x86\Binaries\Template
xcopy /y /s /e %X86%\Template NewRelease\x86\Binaries\Template\
xcopy /y %X86%\OpenCppCoverage.exe NewRelease\x86\Binaries\
xcopy /y %X86%\Exporter.dll NewRelease\x86\Binaries\
xcopy /y %X86%\CppCoverage.dll NewRelease\x86\Binaries\
xcopy /y %X86%\Tools.dll NewRelease\x86\Binaries\
xcopy /y %X86%\FileFilter.dll NewRelease\x86\Binaries\
xcopy /y %X86%\Plugin.dll NewRelease\x86\Binaries\
xcopy /y %X86%\msdia140.dll NewRelease\x86\Binaries\
xcopy /y %X86%\libctemplate.dll NewRelease\x86\Binaries\
xcopy /y %X86%\libprotobuf.dll NewRelease\x86\Binaries\
xcopy /y %X86%\libprotobuf-lite.dll NewRelease\x86\Binaries\
xcopy /y %X86%\boost_date_time-vc142-mt-x32-1_72.dll NewRelease\x86\Binaries\
xcopy /y %X86%\boost_filesystem-vc142-mt-x32-1_72.dll NewRelease\x86\Binaries\
xcopy /y %X86%\boost_locale-vc142-mt-x32-1_72.dll NewRelease\x86\Binaries\
xcopy /y %X86%\boost_log-vc142-mt-x32-1_72.dll NewRelease\x86\Binaries\
xcopy /y %X86%\boost_iostreams.dll NewRelease\x86\Binaries\
xcopy /y %X86%\boost_program_options-vc142-mt-x32-1_72.dll NewRelease\x86\Binaries\
xcopy /y %X86%\boost_thread-vc142-mt-x32-1_72.dll NewRelease\x86\Binaries\
xcopy /y %X86%\bz2.dll NewRelease\x86\Binaries\
xcopy /y %X86%\zstd.dll NewRelease\x86\Binaries\
xcopy /y %X86%\zlib1.dll NewRelease\x86\Binaries\
xcopy /y %X86%\lzma.dll NewRelease\x86\Binaries\
mkdir NewRelease\x86\Binaries\Plugins\Exporter

mkdir NewRelease\x86\Pdb
xcopy /y %X86%\OpenCppCoverage.pdb NewRelease\x86\Pdb\
xcopy /y %X86%\Exporter.pdb NewRelease\x86\Pdb\
xcopy /y %X86%\CppCoverage.pdb NewRelease\x86\Pdb\
xcopy /y %X86%\Tools.pdb NewRelease\x86\Pdb\
xcopy /y %X86%\FileFilter.pdb NewRelease\x86\Pdb\

rem ---------------------------------------------------------------------------
rem x64
rem ---------------------------------------------------------------------------
set X64=x64\Release
if not exist %X64%\OpenCppCoverage.exe (echo MISSING %X64%& set ERROR=1& goto :eof)

mkdir NewRelease\x64\Binaries
mkdir NewRelease\x64\Binaries\Template
mkdir NewRelease\x64\Binaries\Plugins\Exporter
xcopy /y /s /e %X64%\Template NewRelease\x64\Binaries\Template\
xcopy /y %X64%\OpenCppCoverage.exe NewRelease\x64\Binaries\
xcopy /y %X64%\Exporter.dll NewRelease\x64\Binaries\
xcopy /y %X64%\CppCoverage.dll NewRelease\x64\Binaries\
xcopy /y %X64%\Tools.dll NewRelease\x64\Binaries\
xcopy /y %X64%\FileFilter.dll NewRelease\x64\Binaries\
xcopy /y %X64%\Plugin.dll NewRelease\x64\Binaries\
xcopy /y %X64%\msdia140.dll NewRelease\x64\Binaries\
xcopy /y %X64%\libctemplate.dll NewRelease\x64\Binaries\
xcopy /y %X64%\libprotobuf.dll NewRelease\x64\Binaries\
xcopy /y %X64%\libprotobuf-lite.dll NewRelease\x64\Binaries\
xcopy /y %X64%\boost_date_time-vc142-mt-x64-1_72.dll NewRelease\x64\Binaries\
xcopy /y %X64%\boost_filesystem-vc142-mt-x64-1_72.dll NewRelease\x64\Binaries\
xcopy /y %X64%\boost_locale-vc142-mt-x64-1_72.dll NewRelease\x64\Binaries\
xcopy /y %X64%\boost_log-vc142-mt-x64-1_72.dll NewRelease\x64\Binaries\
xcopy /y %X64%\boost_iostreams.dll NewRelease\x64\Binaries\
xcopy /y %X64%\boost_program_options-vc142-mt-x64-1_72.dll NewRelease\x64\Binaries\
xcopy /y %X64%\boost_thread-vc142-mt-x64-1_72.dll NewRelease\x64\Binaries\
xcopy /y %X64%\bz2.dll NewRelease\x64\Binaries\
xcopy /y %X64%\zstd.dll NewRelease\x64\Binaries\
xcopy /y %X64%\zlib1.dll NewRelease\x64\Binaries\
xcopy /y %X64%\lzma.dll NewRelease\x64\Binaries\

mkdir NewRelease\x64\Pdb
xcopy /y %X64%\OpenCppCoverage.pdb NewRelease\x64\Pdb\
xcopy /y %X64%\Exporter.pdb NewRelease\x64\Pdb\
xcopy /y %X64%\CppCoverage.pdb NewRelease\x64\Pdb\
xcopy /y %X64%\Tools.pdb NewRelease\x64\Pdb\
xcopy /y %X64%\FileFilter.pdb NewRelease\x64\Pdb\

rem ---------------------------------------------------------------------------
rem ARM64 (TestCppCli excluded from ARM64 configs; nothing else differs)
rem ---------------------------------------------------------------------------
set A64=ARM64\Release
if not exist %A64%\OpenCppCoverage.exe (echo MISSING %A64%& set ERROR=1& goto :eof)

mkdir NewRelease\ARM64\Binaries
mkdir NewRelease\ARM64\Binaries\Template
mkdir NewRelease\ARM64\Binaries\Plugins\Exporter
xcopy /y /s /e %A64%\Template NewRelease\ARM64\Binaries\Template\
xcopy /y %A64%\OpenCppCoverage.exe NewRelease\ARM64\Binaries\
xcopy /y %A64%\Exporter.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\CppCoverage.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\Tools.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\FileFilter.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\Plugin.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\msdia140.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\libctemplate.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\libprotobuf.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\libprotobuf-lite.dll NewRelease\ARM64\Binaries\
rem modern-vcpkg boost_iostreams is built against external zlib/bzip2/lzma/zstd
xcopy /y %A64%\z.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\bz2.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\liblzma.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\zstd.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\boost_filesystem-vc143-mt-a64-1_92.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\boost_locale-vc143-mt-a64-1_92.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\boost_log-vc143-mt-a64-1_92.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\boost_iostreams-vc143-mt-a64-1_92.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\boost_program_options-vc143-mt-a64-1_92.dll NewRelease\ARM64\Binaries\
xcopy /y %A64%\boost_thread-vc143-mt-a64-1_92.dll NewRelease\ARM64\Binaries\

mkdir NewRelease\ARM64\Pdb
xcopy /y %A64%\OpenCppCoverage.pdb NewRelease\ARM64\Pdb\
xcopy /y %A64%\Exporter.pdb NewRelease\ARM64\Pdb\
xcopy /y %A64%\CppCoverage.pdb NewRelease\ARM64\Pdb\
xcopy /y %A64%\Tools.pdb NewRelease\ARM64\Pdb\
xcopy /y %A64%\FileFilter.pdb NewRelease\ARM64\Pdb\

if %ERROR% neq 0 echo SOME RELEASE TREES WERE MISSING - layout is partial.
if %ERROR% equ 0 echo Done. Zip NewRelease and attach it to a GitHub release.
pause
