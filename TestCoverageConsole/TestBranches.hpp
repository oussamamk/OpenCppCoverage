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

#include <filesystem>

namespace TestCoverageConsole
{
	// Branch coverage test scenario (--branch): deterministic execution that
	// drives both outcomes of several conditional-branch shapes. Line
	// numbers of interest are asserted relative to this file; keep the
	// interesting ifs mid-function (ARM64 packed epilogues can lack line
	// records for trailing lines).
	void RunTestBranches();

	//-------------------------------------------------------------------------
	inline std::filesystem::path GetBranchesCppPath()
	{
		return std::filesystem::path(__FILE__).parent_path() / "TestBranches.cpp";
	}

	//-------------------------------------------------------------------------
	inline std::filesystem::path GetBranchesCppFilename()
	{
		return GetBranchesCppPath().filename();
	}

	//-------------------------------------------------------------------------
	inline int GetBranchesIfElseLine()
	{
		return 32; // "if (value)" in TestBranches.cpp
	}

	//-------------------------------------------------------------------------
	inline int GetBranchesTernaryLine()
	{
		return 67; // "sink = flagA ? 5 : 6;" in TestBranches.cpp
	}
}
