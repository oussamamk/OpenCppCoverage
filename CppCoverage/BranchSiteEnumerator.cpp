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

#include "stdafx.h"
#include "BranchSiteEnumerator.hpp"

#include <algorithm>
#include <map>

#include "Tools/Log.hpp"
#include "Tools/ProcessMemory.hpp"

namespace CppCoverage
{
	namespace
	{
		// Cap for the byte range of the last line record of a file (no next
		// record bounds it): a handful of instructions is enough for any
		// real conditional branch; more bytes risk decoding into unrelated
		// code or unmapped memory.
		constexpr std::uint64_t LastLineCap = 32;
	}

	//-------------------------------------------------------------------------
	std::vector<BranchSiteEnumerator::ConditionSite>
	BranchSiteEnumerator::Enumerate(
		HANDLE hProcess,
		std::uint64_t baseOfImage,
		const std::vector<int>& lineNumbers,
		const std::vector<DWORD64>& lineAddresses,
		const std::vector<ULONG>& lineSymbols) const
	{
		std::vector<ConditionSite> sites;

		if (lineNumbers.size() != lineAddresses.size() ||
		    lineNumbers.size() != lineSymbols.size() || lineNumbers.empty())
			return sites;

		struct LineRecord
		{
			std::uint64_t rva_;
			int lineNumber_;
			ULONG symbolIndex_;
		};

		std::vector<LineRecord> records;
		records.reserve(lineNumbers.size());
		for (std::size_t i = 0; i < lineNumbers.size(); ++i)
			records.push_back(LineRecord{lineAddresses[i] - baseOfImage,
			                             lineNumbers[i], lineSymbols[i]});

		std::sort(records.begin(), records.end(),
			[](const LineRecord& a, const LineRecord& b)
			{ return a.rva_ < b.rva_; });

		// Deduplicate identical RVAs (a line record can appear once per
		// compiland); keep the first (lowest) line number per RVA.
		std::vector<LineRecord> deduped;
		for (const auto& record : records)
		{
			if (!deduped.empty() && deduped.back().rva_ == record.rva_)
			{
				if (record.lineNumber_ < deduped.back().lineNumber_)
					deduped.back().lineNumber_ = record.lineNumber_;
				continue;
			}
			deduped.push_back(record);
		}

		if (deduped.empty())
			return sites;

		// Per-line byte range: [rva_i, rva_{i+1}) within the SAME symbol,
		// capped for the last one. Grouping by symbol keeps ranges from
		// crossing function boundaries when DIA interleaves compilands.
		std::vector<std::pair<std::uint64_t, std::uint64_t>> ranges;
		ranges.reserve(deduped.size());
		for (std::size_t i = 0; i < deduped.size(); ++i)
		{
			auto begin = deduped[i].rva_;
			std::uint64_t end = begin + LastLineCap;

			for (std::size_t j = i + 1; j < deduped.size(); ++j)
			{
				if (deduped[j].symbolIndex_ != deduped[i].symbolIndex_)
					continue;
				end = std::min(deduped[j].rva_, begin + MaxLineRange);
				break;
			}

			if (end <= begin)
				continue; // zero-length or reversed: nothing to decode
			ranges.emplace_back(begin, end);
		}

		// Decode one merged read per line range (they are disjoint and
		// sorted by construction).
		std::map<int, unsigned int> conditionCountPerLine;
		for (std::size_t i = 0; i < ranges.size(); ++i)
		{
			const auto begin = ranges[i].first;
			const auto size = ranges[i].second - begin;

			std::vector<std::uint8_t> bytes;
			try
			{
				bytes = Tools::ReadProcessMemory(
				    hProcess,
				    reinterpret_cast<void*>(baseOfImage + begin),
				    static_cast<size_t>(size));
			}
			catch (const std::exception& e)
			{
				// Unreadable tail (section boundary): retry capped to a small
				// window so the line itself still gets decoded.
				constexpr std::uint64_t RetryWindow = 32;
				try
				{
					auto retrySize = std::min<std::uint64_t>(size, RetryWindow);
					bytes = Tools::ReadProcessMemory(
					    hProcess,
					    reinterpret_cast<void*>(baseOfImage + begin),
					    static_cast<size_t>(retrySize));
				}
				catch (const std::exception&)
				{
					LOG_WARNING << "BranchSiteEnumerator: cannot read bytes at RVA 0x"
					            << std::hex << begin << std::dec << ": " << e.what();
					continue;
				}
			}

			auto detected = BranchSiteDetector::DetectSites(
			    baseOfImage + begin, bytes.data(), bytes.size());

			for (const auto& site : detected)
			{
				auto index = conditionCountPerLine[deduped[i].lineNumber_]++;

				ConditionSite conditionSite;
				conditionSite.siteAddress_ = site.address_;
				conditionSite.takenTarget_ = site.takenTarget_;
				conditionSite.fallThrough_ = site.fallThrough_;
				conditionSite.lineNumber_ = deduped[i].lineNumber_;
				conditionSite.conditionIndex_ = index;
				sites.push_back(conditionSite);
			}
		}

		return sites;
	}
}
