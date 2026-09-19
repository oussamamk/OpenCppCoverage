#!/usr/bin/env python3
r"""Build OpenCppCoverage Inno Setup installers for x86, x64, ARM64.

Based on the original OpenCppCoverageSetup-x64-0.9.9.0.exe layout
(extracted with innoextract):
  - {app} = all runtime DLLs/exe + Template\ tree, Plugins\Exporter dir created
  - silent vc_redist (<arch>) at install time (/install /quiet /norestart)
  - optional PATH task, wizard images, icon carried over

Usage: python CreateInstallers.py --release-root C:\dev\OpenCppCoverage4\NewRelease
Outputs: NewRelease\Installers\OpenCppCoverageSetup-<arch>-0.9.9.0.exe
"""
import argparse, os, shutil, subprocess, sys, io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

ISCC = None
for p in (r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
          r'C:\Program Files\Inno Setup 6\ISCC.exe'):
    if os.path.exists(p):
        ISCC = p
        break

VERSION = '0.9.9.0'
APPID = '{74933D3C-7641-4FA4-840E-313A4D076D87}'

# per-arch installer metadata
ARCHS = {
    'x86': {
        'setup_arch': 'x86',          # x86 installer runs on any arch
        'vc_redist': 'vc_redist.x86.exe',
        'install64bit': '',
        'vc_url': ('https://aka.ms/vs/17/release/vc_redist.x86.exe'),
    },
    'x64': {
        'setup_arch': 'x64',
        'vc_redist': 'vc_redist.x64.exe',
        'install64bit': 'x64',
        'vc_url': 'https://aka.ms/vs/17/release/vc_redist.x64.exe',
    },
    'ARM64': {
        'setup_arch': 'arm64',
        'vc_redist': 'vc_redist.arm64.exe',
        'install64bit': 'arm64',
        'vc_url': 'https://aka.ms/vs/17/release/vc_redist.arm64.exe',
    },
}

TEMPLATE_DIR = r'C:\Users\oussama\Documents\InnoExtractor Files\OpenCppCoverage 0_9_9_0'

# x86/x64: boost 1.72 vc142; ARM64: boost 1.92 vc143
X64_X86_BOOST = [
    'boost_date_time-vc142-mt-{T}-1_72.dll',
    'boost_filesystem-vc142-mt-{T}-1_72.dll',
    'boost_iostreams.dll',
    'boost_locale-vc142-mt-{T}-1_72.dll',
    'boost_log-vc142-mt-{T}-1_72.dll',
    'boost_program_options-vc142-mt-{T}-1_72.dll',
    'boost_thread-vc142-mt-{T}-1_72.dll',
]
A64_BOOST = [
    'boost_filesystem-vc143-mt-a64-1_92.dll',
    'boost_locale-vc143-mt-a64-1_92.dll',
    'boost_log-vc143-mt-a64-1_92.dll',
    'boost_iostreams-vc143-mt-a64-1_92.dll',
    'boost_program_options-vc143-mt-a64-1_92.dll',
    'boost_thread-vc143-mt-a64-1_92.dll',
]
COMMON = [
    'CppCoverage.dll', 'Exporter.dll', 'FileFilter.dll', 'Plugin.dll',
    'Tools.dll', 'OpenCppCoverage.exe', 'msdia140.dll', 'libctemplate.dll',
    'libprotobuf.dll', 'libprotobuf-lite.dll',
]
X86_X64_COMPR = ['bz2.dll', 'zstd.dll', 'zlib1.dll', 'lzma.dll']
A64_COMPR = ['z.dll', 'bz2.dll', 'liblzma.dll', 'zstd.dll']


def bin_dir(release_root, arch):
    return os.path.join(release_root, arch, 'Binaries')


def missing_files(release_root, arch):
    d = bin_dir(release_root, arch)
    meta = ARCHS[arch]
    names = list(COMMON)
    names += [n.replace('{T}', 'x32') for n in X64_X86_BOOST] if arch == 'x86' else \
             [n.replace('{T}', 'x64') for n in X64_X86_BOOST] if arch == 'x64' else A64_BOOST
    names += X86_X64_COMPR if arch in ('x86', 'x64') else A64_COMPR
    return [n for n in names if not os.path.exists(os.path.join(d, n))]


def vc_redist_path(release_root, arch):
    p = os.path.join(release_root, 'Installers', ARCHS[arch]['vc_redist'])
    if os.path.exists(p):
        return p
    return None


def make_iss(release_root, arch, workdir, vc_path):
    meta = ARCHS[arch]
    d = bin_dir(release_root, arch)
    names = list(COMMON)
    if arch == 'x86':
        names += [n.replace('{T}', 'x32') for n in X64_X86_BOOST]
        names += X86_X64_COMPR
    elif arch == 'x64':
        names += [n.replace('{T}', 'x64') for n in X64_X86_BOOST]
        names += X86_X64_COMPR
    else:
        names += A64_BOOST + A64_COMPR

    lines = []
    a = lines.append
    a('[Setup]')
    a('AppName=OpenCppCoverage')
    a(f'AppId={{{APPID}}}')
    a(f'AppVersion={VERSION}')
    a('AppPublisher=OpenCppCoverage')
    a('AppPublisherURL=https://github.com/oussamamk/OpenCppCoverage')
    a('AppSupportURL=https://github.com/oussamamk/OpenCppCoverage')
    a('AppUpdatesURL=https://github.com/oussamamk/OpenCppCoverage')
    a('DefaultDirName={pf}\\OpenCppCoverage')
    a('DefaultGroupName=OpenCppCoverage')
    a(f'OutputBaseFilename=OpenCppCoverageSetup-{arch}-{VERSION}')
    a('Compression=lzma')
    if meta['install64bit']:
        a(f"ArchitecturesInstallIn64BitMode={meta['install64bit']}")
    a('DisableProgramGroupPage=auto')
    a('ChangesAssociations=no')
    a('ShowLanguageDialog=yes')
    a('AllowNoIcons=yes')
    a('WizardStyle=classic')
    a('WizardImageFile=embedded\\WizardImage0.bmp')
    a('WizardSmallImageFile=embedded\\WizardSmallImage0.bmp')
    a('SetupIconFile=SetupIcon.ico')
    a('')
    a('[Files]')
    for n in names:
        src = os.path.join(d, n)
        if not os.path.exists(src):
            print(f'ERROR: missing in {arch} Binaries: {n}')
            sys.exit(1)
        rel = os.path.relpath(src, workdir)
        a(f'Source: "{rel}"; DestDir: "{{app}}"; Flags: ignoreversion')
    # Template tree (whole folder, recursive)
    a(f'Source: "{os.path.relpath(os.path.join(d, "Template"), workdir)}\\*"; DestDir: "{{app}}\\Template"; Flags: ignoreversion recursesubdirs')
    # vc_redist
    vc_rel = os.path.relpath(vc_path, workdir)
    a(f'Source: "{vc_rel}"; DestDir: "{{tmp}}"; Flags: deleteafterinstall')
    a('')
    a('[Dirs]')
    a('Name: "{app}\\Plugins\\Exporter";')
    a('')
    a('[Run]')
    a(f'Filename: "{{tmp}}\\{meta["vc_redist"]}"; Parameters: "/install /quiet /norestart"; WorkingDir: "{{tmp}}"; StatusMsg: "Installing vcredist ...";')
    a('')
    a('[Tasks]')
    a('Name: "modifypath"; Description: "Add application directory to your environmental path";')
    a('')
    a('[Code]')
    a('// modifypath implementation (adds {app} to the user PATH when selected)')
    a('#include "modpath.iss"')
    return '\n'.join(lines) + '\r\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--release-root', required=True)
    ap.add_argument('--out', default=None)
    args = ap.parse_args()

    if not ISCC:
        print('ERROR: Inno Setup 6 (ISCC.exe) not found; install via winget install JRSoftware.InnoSetup')
        sys.exit(2)

    root = args.release_root
    out = args.out or os.path.join(root, 'Installers')
    work = os.path.join(root, 'Installers-work')
    os.makedirs(work, exist_ok=True)

    # carry over the wizard images/icon from the extracted setup
    extracted = r'C:\Users\oussama\Documents\InnoExtractor Files\OpenCppCoverage 0_9_9_0'
    for f in ('SetupIcon.ico', 'embedded/WizardImage0.bmp', 'embedded/WizardSmallImage0.bmp'):
        src = os.path.join(extracted, f.replace('/', os.sep))
        dst = os.path.join(work, f.replace('/', os.sep))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)

    # fetch the modifypath implementation
    modpath = os.path.join(work, 'modpath.iss')
    if not os.path.exists(modpath):
        print(f'modpath.iss missing in {work}; write it there (Inno KB "ModPath" script) and rerun.')
        sys.exit(3)

    # download vc_redist per arch if absent
    os.makedirs(os.path.join(root, 'Installers'), exist_ok=True)
    for arch in ('x86', 'x64', 'ARM64'):
        p = os.path.join(root, 'Installers', ARCHS[arch]['vc_redist'])
        if not os.path.exists(p):
            print(f'downloading {ARCHS[arch]["vc_url"]} ...')
            subprocess.run(['curl', '-sSL', '-o', p, ARCHS[arch]['vc_url']], check=True)

    results = []
    for arch in ('x86', 'x64', 'ARM64'):
        vc = vc_redist_path(root, arch)
        if not vc:
            print(f'ERROR: {ARCHS[arch]["vc_redist"]} not found in {root}\\Installers')
            sys.exit(4)
        iss = os.path.join(work, f'setup-{arch}.iss')
        with open(iss, 'w', encoding='utf-8') as f:
            f.write(make_iss(root, arch, work, vc))
        print(f'compiling {arch} ...')
        r = subprocess.run([ISCC, '/Qp', f'/O{out}', iss], cwd=work)
        if r.returncode:
            print(f'ERROR: ISCC failed for {arch} (exit {r.returncode})')
            sys.exit(5)
        final = os.path.join(out, f'OpenCppCoverageSetup-{arch}-{VERSION}.exe')
        size = os.path.getsize(final) if os.path.exists(final) else 0
        print(f'OK  {final} ({size:,} bytes)')
    print('All installers built.')


if __name__ == '__main__':
    main()
