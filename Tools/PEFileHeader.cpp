// OpenCppCoverage is an open source code coverage for C++.
// Copyright (C) 2017 OpenCppCoverage
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include "stdafx.h"
#include "PEFileHeader.hpp"
#include "ProcessMemory.hpp"
#include "ToolsException.hpp"

namespace Tools
{
	//-------------------------------------------------------------------------
	void PEFileHeader::Load(HANDLE hProcess,
	                        DWORD64 baseOfImage,
	                        IPEFileHeaderHandler& handler) const
	{
		auto dosHeader = Tools::ReadStructInProcessMemory<IMAGE_DOS_HEADER>(
		    hProcess, baseOfImage);
		if (dosHeader->e_magic != IMAGE_DOS_SIGNATURE)
			THROW("The image is not a valid DOS image.");
		auto ntHeader32 = Tools::ReadStructInProcessMemory<IMAGE_NT_HEADERS32>(
		    hProcess, baseOfImage + dosHeader->e_lfanew);
		auto machine = ntHeader32->FileHeader.Machine;

		if (machine == IMAGE_FILE_MACHINE_I386)
			handler.OnNtHeader32(hProcess, baseOfImage, *ntHeader32);
		else if (machine == IMAGE_FILE_MACHINE_AMD64
#ifdef _M_ARM64
		         // Only an ARM64-native build accepts 0xAA64 modules: an
		         // x86/x64 build cannot patch 4-byte ARM64 breakpoints into
		         // ARM64 code, so it must reject them with the
		         // unsupported-machine error below.
		         || machine == IMAGE_FILE_MACHINE_ARM64
#endif
		        )
		{
#ifdef _M_ARM64
			// An ARM64 build debugs ARM64 targets only: the target would run
			// emulated x64 code while the debugger patches 4-byte ARM64
			// breakpoints into it. Reject x64 targets with a clear message.
			if (machine == IMAGE_FILE_MACHINE_AMD64)
				THROW(L"PE file header machine is not supported: " +
				      std::to_wstring(machine) +
				      L" (this ARM64 build covers ARM64 targets only; use an x64 build for x64 targets)");
#endif
			// ARM64 Windows images are PE32+ (same optional header as AMD64).
			auto ntHeader64 = ReadStructInProcessMemory<IMAGE_NT_HEADERS64>(
			    hProcess, baseOfImage + dosHeader->e_lfanew);
			handler.OnNtHeader64(hProcess, baseOfImage, *ntHeader64);
		}
		else
			THROW(L"PE file header machine is not supported: " +
			      std::to_wstring(machine));
	}
}
