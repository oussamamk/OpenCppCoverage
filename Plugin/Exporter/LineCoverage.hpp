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

#pragma once

#include <vector>

#include "../PluginExport.hpp"

namespace Plugin
{
	class PLUGIN_DLL LineCoverage
	{
	public:
		// One conditional branch attributed to a line (branch coverage, --branch).
		// A condition is "covered" iff both outcomes were observed at least
		// once (Emma semantics).
		struct Condition
		{
			Condition() = default;
			Condition(unsigned int index, bool takenSeen, bool notTakenSeen)
				: index_{index}, takenSeen_{takenSeen}, notTakenSeen_{notTakenSeen}
			{
			}

			unsigned int index_ = 0;       // nth conditional branch on this line
			bool takenSeen_ = false;
			bool notTakenSeen_ = false;

			bool IsCovered() const { return takenSeen_ && notTakenSeen_; }
		};

		LineCoverage(unsigned int lineNumber, bool hasBeenExecuted);
		LineCoverage(unsigned int lineNumber, bool hasBeenExecuted,
		             std::vector<Condition> conditions);
		LineCoverage(const LineCoverage&) = default;

		unsigned int GetLineNumber() const;
		bool HasBeenExecuted() const;

		const std::vector<Condition>& GetConditions() const;
		// OR-merges outcome flags per condition index (used when aggregating
		// several runs / modules). Conditions missing on this line are added.
		void MergeConditions(const std::vector<Condition>& conditions);
		// True when branch coverage data exists for this line.
		bool HasConditions() const;

	private:
		unsigned int lineNumber_;
		bool hasBeenExecuted_;
		std::vector<Condition> conditions_;
	};
}
