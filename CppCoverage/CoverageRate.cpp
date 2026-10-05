// OpenCppCoverage is an open source code coverage for C++.
// Copyright (C) 2014 OpenCppCoverage
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
#include "CoverageRate.hpp"

namespace CppCoverage
{
	//-------------------------------------------------------------------------
	CoverageRate::CoverageRate()
		: CoverageRate{ 0, 0}
	{
	}

	//-------------------------------------------------------------------------
	CoverageRate::CoverageRate(int executedLinesCount, int unexecutedLinesCount)
		: executedLinesCount_{ executedLinesCount }
		, unexecutedLinesCount_{ unexecutedLinesCount }
		, coveredBranchesCount_{ 0 }
		, uncoveredBranchesCount_{ 0 }
	{
	}

	//-------------------------------------------------------------------------
	CoverageRate::CoverageRate(int executedLinesCount,
	                           int unexecutedLinesCount,
	                           int coveredBranchesCount,
	                           int uncoveredBranchesCount)
		: executedLinesCount_{ executedLinesCount }
		, unexecutedLinesCount_{ unexecutedLinesCount }
		, coveredBranchesCount_{ coveredBranchesCount }
		, uncoveredBranchesCount_{ uncoveredBranchesCount }
	{
	}

	//-------------------------------------------------------------------------
	int CoverageRate::GetExecutedLinesCount() const
	{
		return executedLinesCount_;
	}

	//-------------------------------------------------------------------------
	int CoverageRate::GetUnExecutedLinesCount() const
	{
		return unexecutedLinesCount_;
	}

	//-------------------------------------------------------------------------
	int CoverageRate::GetTotalLinesCount() const
	{
		return executedLinesCount_ + unexecutedLinesCount_;
	}

	//-------------------------------------------------------------------------
	double CoverageRate::GetRate() const
	{
		auto totalLines = executedLinesCount_ + unexecutedLinesCount_;

		if (totalLines == 0)
			return 1.0;
		return static_cast<double>(executedLinesCount_) / totalLines;
	}

	//-------------------------------------------------------------------------
	int CoverageRate::GetPercentRate() const
	{
		return static_cast<int>(GetRate() * 100);
	}

	//-------------------------------------------------------------------------
	int CoverageRate::GetCoveredBranchesCount() const
	{
		return coveredBranchesCount_;
	}

	//-------------------------------------------------------------------------
	int CoverageRate::GetUncoveredBranchesCount() const
	{
		return uncoveredBranchesCount_;
	}

	//-------------------------------------------------------------------------
	int CoverageRate::GetTotalBranchesCount() const
	{
		return coveredBranchesCount_ + uncoveredBranchesCount_;
	}

	//-------------------------------------------------------------------------
	double CoverageRate::GetBranchRate() const
	{
		auto totalBranches = coveredBranchesCount_ + uncoveredBranchesCount_;

		if (totalBranches == 0)
			return 0.0;
		return static_cast<double>(coveredBranchesCount_) / totalBranches;
	}

	//-------------------------------------------------------------------------
	CoverageRate& CoverageRate::operator+=(const CoverageRate& coverageRate)
	{
		executedLinesCount_ += coverageRate.executedLinesCount_;
		unexecutedLinesCount_ += coverageRate.unexecutedLinesCount_;
		coveredBranchesCount_ += coverageRate.coveredBranchesCount_;
		uncoveredBranchesCount_ += coverageRate.uncoveredBranchesCount_;

		return *this;
	}

}
