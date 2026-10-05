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
#include <vector>

#include "CppCoverageExport.hpp"

namespace CppCoverage
{
	//-------------------------------------------------------------------------
	// BranchSiteDetector: finds conditional branch instructions in a code
	// range using the capstone disassembler. Used by the branch coverage
	// feature (--branch): each detected conditional branch becomes a
	// "condition" whose taken / not-taken outcomes are observed at runtime
	// via single-stepping.
	//
	// Conditional branches recognized:
	//   x86/x64: Jcc (rel8 / rel32), JCXZ/JECXZ, LOOPcc
	//   ARM64:   B.cond, CBZ/CBNZ, TBZ/TBNZ
	// Not recognized (documented limitation): indirect branches behind jump
	// tables (switch), XBEGIN, ARM64 branches testing flags only (B.cond IS
	// recognized; TBZ/TBNZ and CBZ/CBNZ are).
	//-------------------------------------------------------------------------
	class CPPCOVERAGE_DLL BranchSiteDetector
	{
	public:
		struct Site
		{
			std::uint64_t address_;       // absolute address of the branch instruction
			std::uint64_t size_;          // instruction size in bytes
			std::uint64_t takenTarget_;   // absolute address when the branch is taken
			std::uint64_t fallThrough_;   // absolute address of the next instruction
		};

		// Disassembles [begin, begin + size) and returns every conditional
		// branch instruction found. begin is the absolute address the bytes
		// were read from.
		static std::vector<Site> DetectSites(
			std::uint64_t begin,
			const std::uint8_t* bytes,
			std::size_t size);

	private:
		static std::vector<Site> DetectSitesX86(
			std::uint64_t begin, const std::uint8_t* bytes, std::size_t size);
		static std::vector<Site> DetectSitesArm64(
			std::uint64_t begin, const std::uint8_t* bytes, std::size_t size);
	};
}
