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

#include "TestBranches.hpp"

// Scenario code must live in the .cpp (see TestBasic.cpp comment): the
// tests rely on line records of this translation unit in release mode too.
namespace TestCoverageConsole
{
	namespace
	{
		volatile int sink = 0;
		volatile bool flagA = true;
		volatile bool flagB = false;

		//---------------------------------------------------------------------
		void IfElse(bool value)
		{
			if (value)                     // both outcomes driven
				sink = 1;
			else
				sink = 2;
		}

		//---------------------------------------------------------------------
		void LogicalAnd()
		{
			// Second operand of && executes only when the first is true:
			// exercises the short-circuit conditional branch.
			if (flagA && !flagB)
				sink = 3;
		}

		//---------------------------------------------------------------------
		void LogicalOr()
		{
			if (flagB || flagA)
				sink = 4;
		}

		//---------------------------------------------------------------------
		void LoopWithEarlyExit()
		{
			// Loop condition observed taken and not-taken.
			for (int i = 0; i < 3; ++i)
			{
				sink += i;
			}
		}

		//---------------------------------------------------------------------
		void Ternary()
		{
			sink = flagA ? 5 : 6;
		}
	}

	//-------------------------------------------------------------------------
	void ResetBranchFlags()
	{
		flagA = true;
		flagB = false;
	}

	//-------------------------------------------------------------------------
	void RunTestBranches()
	{
		// Drives BOTH outcomes of every conditional branch below: branch
		// coverage (Emma semantics) credits a condition only when the taken
		// and not-taken paths were both observed.
		IfElse(true);
		IfElse(false);

		// LogicalAnd: flagA=true, flagB=false -> both && conditions fall
		// through (sink = 3).
		LogicalAnd();
		// flagA=false: the first && condition is taken (short-circuit).
		flagA = false;
		LogicalAnd();
		// flagA=true, flagB=true: the second && condition is taken.
		flagA = true;
		flagB = true;
		LogicalAnd();

		// LogicalOr: flagB=true -> first || condition taken.
		LogicalOr();
		// flagB=false, flagA=true -> both || conditions fall through.
		flagB = false;
		LogicalOr();
		// flagB=false, flagA=false -> second || condition taken (else arm).
		flagA = false;
		LogicalOr();

		LoopWithEarlyExit();

		// Ternary: flagA=false -> else arm; flagA=true -> then arm.
		Ternary();
		flagA = true;
		Ternary();

		ResetBranchFlags();
	}
}
