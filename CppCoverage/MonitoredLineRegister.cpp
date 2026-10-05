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

#include "MonitoredLineRegister.hpp"

#include "ICoverageFilterManager.hpp"
#include "Address.hpp"
#include "BreakPoint.hpp"
#include "BranchSiteEnumerator.hpp"
#include "ExecutedAddressManager.hpp"
#include "CppCoverageException.hpp"
#include "FilterAssistant.hpp"

#include "FileFilter/ModuleInfo.hpp"
#include "FileFilter/FileInfo.hpp"
#include "FileFilter/LineInfo.hpp"

#include "Tools/PEFileHeader.hpp"
#include "Tools/Log.hpp"

namespace CppCoverage
{
	namespace
	{
		struct ModuleKind : private Tools::IPEFileHeaderHandler
		{
			//----------------------------------------------------------------------------
			bool IsNativeModule(HANDLE hProcess, DWORD64 baseOfImage)
			{
				Tools::PEFileHeader fileHeader;

				fileHeader.Load(hProcess, baseOfImage, *this);
				return isNativeModule_;
			}

		  private:
			//-----------------------------------------------------------------
			template <typename T_IMAGE_NT_HEADERS>
			void OnNtHeader(const T_IMAGE_NT_HEADERS& ntHeaders)
			{
				const auto& optionalHeader = ntHeaders.OptionalHeader;
				auto dataDirectory =
				    optionalHeader
				        .DataDirectory[IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR];
				isNativeModule_ = dataDirectory.VirtualAddress == 0 &&
				                  dataDirectory.Size == 0;
			}

			//-----------------------------------------------------------------
			void OnNtHeader32(HANDLE,
			                  DWORD64,
			                  const IMAGE_NT_HEADERS32& ntHeader) override
			{
				OnNtHeader(ntHeader);
			}

			//-----------------------------------------------------------------
			void OnNtHeader64(HANDLE,
			                  DWORD64,
			                  const IMAGE_NT_HEADERS64& ntHeader) override
			{
				OnNtHeader(ntHeader);
			}

			bool isNativeModule_ = true;
		};
	}

	//----------------------------------------------------------------------------
	MonitoredLineRegister::MonitoredLineRegister(
	    std::shared_ptr<BreakPoint> breakPoint,
	    std::shared_ptr<ExecutedAddressManager> executedAddressManager,
	    std::shared_ptr<ICoverageFilterManager> coverageFilterManager,
	    std::unique_ptr<DebugInformationEnumerator> debugInformationEnumerator,
	    std::shared_ptr<FilterAssistant> filterAssistant,
	    bool branchCoverageEnabled)
	    : breakPoint_{breakPoint},
	      executedAddressManager_{executedAddressManager},
	      coverageFilterManager_{coverageFilterManager},
	      debugInformationEnumerator_{std::move(debugInformationEnumerator)},
	      filterAssistant_{std::move(filterAssistant)},
	      branchCoverageEnabled_{branchCoverageEnabled}
	{
		if (branchCoverageEnabled_)
			branchSiteEnumerator_ = std::make_unique<BranchSiteEnumerator>();
	}

	//----------------------------------------------------------------------------
	MonitoredLineRegister::~MonitoredLineRegister() = default;

	//----------------------------------------------------------------------------
	bool MonitoredLineRegister::RegisterLineToMonitor(
	    const std::filesystem::path& modulePath,
	    HANDLE hProcess,
	    void* baseOfImage)
	{
		if (!ModuleKind{}.IsNativeModule(
		        hProcess, reinterpret_cast<DWORD64>(baseOfImage)))
		{
			LOG_INFO << modulePath.wstring()
			         << " is skipped as it is a managed module.";
			return false;
		}

		executedAddressManager_->AddModule(modulePath.wstring(), baseOfImage);

		moduleInfo_ = std::make_unique<FileFilter::ModuleInfo>(
		    hProcess, modulePath, baseOfImage);

		return debugInformationEnumerator_->Enumerate(modulePath, *this);
	}

	//--------------------------------------------------------------------------
	bool MonitoredLineRegister::IsSourceFileSelected(
	    const std::filesystem::path& path)
	{
		auto isSelected = coverageFilterManager_->IsSourceFileSelected(path.wstring());
		filterAssistant_->OnNewSourceFile(path, isSelected);
		return isSelected;
	}

	//--------------------------------------------------------------------------
	void
	MonitoredLineRegister::OnSourceFile(const std::filesystem::path& path,
	                                    const std::vector<Line>& lines)
	{
		std::vector<FileFilter::LineInfo> lineInfos;

		for (const auto& line : lines)
		{
			lineInfos.emplace_back(
			    line.lineNumber_, line.virtualAddress_, line.symbolIndex_);
		}

		FileFilter::FileInfo fileInfo{path, std::move(lineInfos)};
		const auto& moduleInfo = GetModuleInfo();

		std::vector<DWORD64> addresses;
		LineNumberByAddress lineNumberByAddress;
		std::vector<int> conditionLineNumbers;
		std::vector<DWORD64> conditionLineAddresses;
		std::vector<ULONG> conditionLineSymbols;

		for (const auto& lineInfo : fileInfo.lineInfoColllection_)
		{
			auto lineNumber = lineInfo.lineNumber_;
			if (coverageFilterManager_->IsLineSelected(
			        moduleInfo, fileInfo, lineInfo))
			{
				auto addressValue =
				    lineInfo.virtualAddress_ +
				    reinterpret_cast<DWORD64>(moduleInfo.baseOfImage_);

				lineNumberByAddress[addressValue].push_back(lineNumber);
				addresses.push_back(addressValue);
				conditionLineNumbers.push_back(lineNumber);
				conditionLineAddresses.push_back(addressValue);
				conditionLineSymbols.push_back(lineInfo.symbolIndex_);
			}
		}

		// Branch coverage: decode the selected lines' byte ranges and plant
		// one breakpoint per conditional-branch site. Sites are merged into
		// the SAME batch as the line starts (SetBreakPoints below): planting
		// a second batch over an already-broken address would save the
		// breakpoint bytes as the "original instruction" and corrupt the
		// restore. The address-to-line bookkeeping deduplicates naturally
		// via lineNumberByAddress.
		if (branchSiteEnumerator_)
		{
			auto conditionSites = branchSiteEnumerator_->Enumerate(
			    moduleInfo.hProcess_,
			    reinterpret_cast<std::uint64_t>(moduleInfo.baseOfImage_),
			    conditionLineNumbers,
			    conditionLineAddresses,
			    conditionLineSymbols);

			for (const auto& site : conditionSites)
			{
				pendingConditionSites_.push_back(
				    PendingConditionSite{site.siteAddress_, site.takenTarget_,
				                         site.fallThrough_, site.lineNumber_,
				                         site.conditionIndex_});
				// A site can coincide with a line start (e.g. on ARM64 a
				// cbz/tbz is often the first instruction of the if). Then
				// the line's own breakpoint covers the site: adding a
				// second batch entry or a second RegisterAddress for the
				// same address would make RegisterAddress return false and
				// unplanted the just-planted breakpoint. RegisterCondition
				// Site below still attaches the condition to the address.
				if (!lineNumberByAddress.count(site.siteAddress_))
				{
					addresses.push_back(site.siteAddress_);
					lineNumberByAddress[site.siteAddress_].push_back(
					    site.lineNumber_);
				}
			}
		}

		SetBreakPoint(path,
		              moduleInfo.hProcess_,
		              std::move(addresses),
		              lineNumberByAddress);
	}

	//--------------------------------------------------------------------------
	void MonitoredLineRegister::SetBreakPoint(
	    const std::filesystem::path& path,
	    HANDLE hProcess,
	    std::vector<DWORD64>&& addressCollection,
	    const LineNumberByAddress& lineNumberByAddress)
	{
		auto oldInstructions =
		    breakPoint_->SetBreakPoints(hProcess, std::move(addressCollection));
		for (const auto& value : oldInstructions)
		{
			auto oldInstruction = value.first;
			const auto& addressValue = value.second;

			auto it = lineNumberByAddress.find(addressValue);
			if (it != lineNumberByAddress.end())
			{
				Address address{hProcess,
				                reinterpret_cast<void*>(addressValue)};
				const auto& lineNumbers = it->second;
				for (auto lineNumber : lineNumbers)
				{
					if (!executedAddressManager_->RegisterAddress(
					        address,
					        path.wstring(),
					        lineNumber,
					        oldInstruction))
					{
						breakPoint_->RemoveBreakPoint(address, oldInstruction);
					}
				}
			}
		}

		// Register the conditional-branch sites with the runtime target
		// bookkeeping (after the batch is planted; RegisterConditionSite
		// attaches to the same address entries without touching memory).
		for (const auto& site : pendingConditionSites_)
		{
			Address address{hProcess, reinterpret_cast<void*>(site.address_)};
			executedAddressManager_->RegisterConditionSite(
			    address, path.wstring(), site.lineNumber_, site.conditionIndex_,
			    site.takenTarget_, site.fallThrough_);
		}
		pendingConditionSites_.clear();
	}

	//--------------------------------------------------------------------------
	const FileFilter::ModuleInfo& MonitoredLineRegister::GetModuleInfo() const
	{
		if (!moduleInfo_)
			THROW("moduleInfo_ is null.");
		return *moduleInfo_;
	}
}
