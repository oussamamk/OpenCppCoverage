r"""Patch the pinned-2020 vcpkg's toolset detection (visualstudio.cpp) so it
recognizes MSVC 14.3x/14.4x toolchains as v143. Invoked by
BuildThirdPartyDependencies.bat from the vcpkg root; patches the file at
toolsrc\src\vcpkg\visualstudio.cpp relative to the repo root given on the
command line (or CWD when omitted). Idempotent: skips if already patched.
"""
import sys, os

target = os.path.join(sys.argv[1] if len(sys.argv) > 1 else '', 'vcpkg', 'toolsrc', 'src', 'vcpkg', 'visualstudio.cpp')
if not os.path.exists(target):
    target = os.path.join('toolsrc', 'src', 'vcpkg', 'visualstudio.cpp')

src = open(target, encoding='utf-8').read()

if 'V_143' in src:
    print('visualstudio.cpp already patched - nothing to do')
    sys.exit(0)

orig = src
src = src.replace(
    'static constexpr CStringView V_142 = "v142";',
    'static constexpr CStringView V_142 = "v142";\n'
    '    static constexpr CStringView V_143 = "v143";')

src = src.replace(
    "else if (toolset_version_prefix[3] == '2')\n"
    "                    {\n"
    "                        toolset_version = V_142;\n"
    "                        vcvars_option = \"-vcvars_ver=14.2\";\n"
    "                    }\n"
    "                    else\n"
    "                    {\n"
    "                        // unknown toolset minor version\n"
    "                        continue;\n"
    "                    }",
    "else if (toolset_version_prefix[3] == '2')\n"
    "                    {\n"
    "                        toolset_version = V_142;\n"
    "                        vcvars_option = \"-vcvars_ver=14.2\";\n"
    "                    }\n"
    "                    else if (toolset_version_prefix[3] == '3' || toolset_version_prefix[3] == '4')\n"
    "                    {\n"
    "                        toolset_version = V_143;\n"
    "                        vcvars_option = \"\";\n"
    "                    }\n"
    "                    else\n"
    "                    {\n"
    "                        // unknown toolset minor version\n"
    "                        continue;\n"
    "                    }")

if src == orig:
    print('ERROR: no replacements applied - visualstudio.cpp layout differs from expectation')
    sys.exit(1)

open(target, 'w', encoding='utf-8', newline='\n').write(src)
print('patched', target)
