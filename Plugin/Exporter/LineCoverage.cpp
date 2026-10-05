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
#include "LineCoverage.hpp"

#include <algorithm>

namespace Plugin
{
	//-------------------------------------------------------------------------
	LineCoverage::LineCoverage(unsigned int lineNumber, bool hasBeenExecuted)
		: lineNumber_(lineNumber)
		, hasBeenExecuted_(hasBeenExecuted)
	{
	}

	//-------------------------------------------------------------------------
	LineCoverage::LineCoverage(unsigned int lineNumber,
	                           bool hasBeenExecuted,
	                           std::vector<Condition> conditions)
		: lineNumber_(lineNumber)
		, hasBeenExecuted_(hasBeenExecuted)
		, conditions_{std::move(conditions)}
	{
	}

	//-------------------------------------------------------------------------
	unsigned int LineCoverage::GetLineNumber() const
	{
		return lineNumber_;
	}

	//-------------------------------------------------------------------------
	bool LineCoverage::HasBeenExecuted() const
	{
		return hasBeenExecuted_;
	}

	//-------------------------------------------------------------------------
	const std::vector<LineCoverage::Condition>& LineCoverage::GetConditions() const
	{
		return conditions_;
	}

	//-------------------------------------------------------------------------
	bool LineCoverage::HasConditions() const
	{
		return !conditions_.empty();
	}

	//-------------------------------------------------------------------------
	void LineCoverage::MergeConditions(const std::vector<Condition>& conditions)
	{
		for (const auto& condition : conditions)
		{
			auto it = std::find_if(conditions_.begin(), conditions_.end(),
				[&condition](const Condition& c) { return c.index_ == condition.index_; });

			if (it == conditions_.end())
			{
				conditions_.push_back(condition);
			}
			else
			{
				it->takenSeen_ = it->takenSeen_ || condition.takenSeen_;
				it->notTakenSeen_ = it->notTakenSeen_ || condition.notTakenSeen_;
			}
		}
	}
}
