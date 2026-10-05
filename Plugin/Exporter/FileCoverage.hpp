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

#include <filesystem>
#include <map>

#include "LineCoverage.hpp"
#include "../PluginExport.hpp"

namespace Plugin
{
	class PLUGIN_DLL FileCoverage
	{
	public:
		explicit FileCoverage(const std::filesystem::path& path);

		void AddLine(unsigned int lineNumber, bool hasBeenExecuted);
		void AddLine(const LineCoverage& line);
		void UpdateLine(unsigned int lineNumber, bool hasBeenExecuted);
		// OR-merges branch condition outcomes into an existing line.
		// Throws if the line does not exist.
		void MergeLineConditions(unsigned int lineNumber,
		                         const std::vector<LineCoverage::Condition>&);
		// Attaches a full condition list to an existing line (used when
		// coverage data is first built). Throws if the line does not exist
		// or already carries conditions.
		void AddLineConditions(unsigned int lineNumber,
		                       std::vector<LineCoverage::Condition>&&);

		const std::filesystem::path& GetPath() const;
		const LineCoverage* operator[](unsigned int line) const;
		std::vector<LineCoverage> GetLines() const;

		FileCoverage& operator=(const FileCoverage&) = default;

	private:
		FileCoverage(const FileCoverage&) = delete;
			
	private:
		std::filesystem::path path_;
		std::map<unsigned int, LineCoverage> lines_;	
	};
}


