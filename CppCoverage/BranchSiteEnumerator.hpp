// OpenCppCoverage is an open source code coverage for C++.
// Copyright (C) 2026 OpenCppCoverage
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

#pragma once

#include <cstdint>
#include <map>
#include <vector>

#include <Windows.h>

#include "BranchSiteDetector.hpp"

#include "CppCoverageExport.hpp"

namespace CppCoverage
{
	//-------------------------------------------------------------------------
	// BranchSiteEnumerator: computes which conditional-branch sites belong to
	// each monitored source line, for the branch coverage feature (--branch).
	//
	// Input is the set of selected line start addresses of one source file
	// (all within one module). Lines are grouped by symbol index; the byte
	// range of one line runs from its start address up to the start of the
	// next line record of the SAME symbol (DIA interleaves compilands).
	// Each range is read from the target process and decoded by
	// BranchSiteDetector.
	//
	// Output: per line, the ordered conditional branches starting a
	// "condition" (conditionIndex = position among the line's branches).
	//-------------------------------------------------------------------------
	class CPPCOVERAGE_DLL BranchSiteEnumerator
	{
	public:
		struct ConditionSite
		{
			std::uint64_t siteAddress_;
			std::uint64_t takenTarget_;
			std::uint64_t fallThrough_;
			int lineNumber_;
			unsigned int conditionIndex_;
		};

		// hProcess is used to read the instruction bytes. lineSymbols maps
		// each line to its DIA symbol index: a line's byte range ends at the
		// next line record of the SAME symbol, so ranges never cross a
		// function boundary (DIA interleaves compilands in the line table).
		std::vector<ConditionSite> Enumerate(
			HANDLE hProcess,
			std::uint64_t baseOfImage,
			const std::vector<int>& lineNumbers,
			const std::vector<DWORD64>& lineAddresses,
			const std::vector<ULONG>& lineSymbols) const;

	private:
		// Safety cap for a single line's decode range: skip absurdly long
		// ranges (a line record followed by a far-away next record usually
		// means a function boundary between them).
		static constexpr std::uint64_t MaxLineRange = 4096;
	};
}
