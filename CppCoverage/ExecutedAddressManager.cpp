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
#include "ExecutedAddressManager.hpp"

#include <unordered_map>
#include <boost/container/small_vector.hpp>

#include "tools/Log.hpp"

#include "CppCoverageException.hpp"
#include "Plugin/Exporter/ModuleCoverage.hpp"
#include "Plugin/Exporter/FileCoverage.hpp"
#include "Address.hpp"
#include "BreakPoint.hpp"

namespace CppCoverage
{
	//-------------------------------------------------------------------------
	struct ExecutedAddressManager::Line
	{
		explicit Line(BreakPoint::InstructionValue instructionToRestore,
		              void* dllBaseOfImage)
			: instructionToRestore_{ instructionToRestore }
			, dllBaseOfImage_{ dllBaseOfImage }
		{
		}

		const BreakPoint::InstructionValue instructionToRestore_;
		void* const dllBaseOfImage_;
		boost::container::small_vector<bool*, 1> hasBeenExecutedCollection_;
	};

	//-------------------------------------------------------------------------
	// Persistent observed-outcome record of one conditional branch, owned by
	// the File entry (survives address-map cleanup like the line bools).
	struct ConditionState
	{
		bool takenSeen_ = false;
		bool notTakenSeen_ = false;
		unsigned int observationCount_ = 0;
	};

	//-------------------------------------------------------------------------
	// Runtime state of one conditional branch site (branch coverage, --branch).
	// condition_ points into the owning File's persistent condition records so
	// observed outcomes survive OnExitProcess/OnUnloadModule address-map
	// cleanup, exactly like the hasBeenExecutedCollection_ bool pointers.
	struct ExecutedAddressManager::ConditionRuntime
	{
		std::uint64_t takenTarget_;
		std::uint64_t fallThrough_;
		void* dllBaseOfImage_;
		ConditionState* condition_;
	};

	//-------------------------------------------------------------------------
	struct ExecutedAddressManager::File
	{
		// Use map to have iterator always valid
		std::map<unsigned int, bool> lines;
		// Persistent per-line branch condition records: key is
		// (lineNumber, conditionIndex). Iterator stability is required
		// (ConditionRuntime holds pointers into the mapped values).
		std::map<std::pair<unsigned int, unsigned int>, ConditionState> conditions;
	};

	//-------------------------------------------------------------------------
	struct ExecutedAddressManager::Module
	{
		explicit Module(const std::wstring& name) : name_{ name }
		{
		}

		const std::wstring name_;
		std::unordered_map<std::wstring, File> files_;
	};
	
	//-------------------------------------------------------------------------
	ExecutedAddressManager::ExecutedAddressManager()
	{
		lastModule_.baseOfImage_ = nullptr;
		lastModule_.module_ = nullptr;
	}

	//-------------------------------------------------------------------------
	ExecutedAddressManager::~ExecutedAddressManager()
	{
	}

	//-------------------------------------------------------------------------
	void ExecutedAddressManager::AddModule(
		const std::wstring& moduleName,
		void* dllBaseOfImage)
	{
		auto it = modules_.find(moduleName);

		if (it == modules_.end())
			it = modules_.emplace(moduleName, Module{ moduleName }).first;
		lastModule_.module_ = &it->second;
		lastModule_.baseOfImage_ = dllBaseOfImage;
	}
	
	//-------------------------------------------------------------------------
	bool ExecutedAddressManager::RegisterAddress(
		const Address& address,
		const std::wstring& filename,
		unsigned int lineNumber,
		BreakPoint::InstructionValue instructionValue)
	{
		auto& module = GetLastAddedModule();
		auto& file = module.files_[filename];

		LOG_TRACE << "RegisterAddress: " << address << " for " << filename << ":" << lineNumber;

		// Different {filename, line} can have the same address.
		// Same {filename, line} can have several addresses.		
		bool keepBreakpoint = false;
		auto itAddress = addressLineMap_.find(address);

		if (itAddress == addressLineMap_.end())
		{
			itAddress = addressLineMap_.emplace(address, 
				Line{ instructionValue, lastModule_.baseOfImage_ }).first;
			keepBreakpoint = true;
		}
		
		auto& line = itAddress->second;
		line.hasBeenExecutedCollection_.push_back(&file.lines[lineNumber]);
		
		return keepBreakpoint;
	}

	//-------------------------------------------------------------------------
	ExecutedAddressManager::Module& ExecutedAddressManager::GetLastAddedModule()
	{
		if (!lastModule_.module_)
			THROW("Cannot get last module.");

		return *lastModule_.module_;
	}

	//-------------------------------------------------------------------------
	boost::optional<BreakPoint::InstructionValue>
	ExecutedAddressManager::MarkAddressAsExecuted(const Address& address)
	{
		auto it = addressLineMap_.find(address);

		if (it == addressLineMap_.end())
			return boost::none;

		auto& line = it->second;

		for (bool* hasBeenExecuted : line.hasBeenExecutedCollection_)
		{
			if (!hasBeenExecuted)
				THROW("Invalid pointer");
			*hasBeenExecuted = true;
		}
		return line.instructionToRestore_;
	}

	//-------------------------------------------------------------------------
	void ExecutedAddressManager::RegisterConditionSite(
		const Address& address,
		const std::wstring& filename,
		unsigned int line,
		unsigned int conditionIndex,
		std::uint64_t takenTarget,
		std::uint64_t fallThrough)
	{
		auto& module = GetLastAddedModule();
		auto& file = module.files_[filename];

		LOG_TRACE << "RegisterConditionSite: " << address << " for " << filename
		          << ":" << line << " condition " << conditionIndex;

		// The persistent condition record keeps observed outcomes across
		// module unload/reload (same sharing pattern as the line bools).
		auto& condition =
		    file.conditions[{line, conditionIndex}];

		auto itSite = conditionSiteMap_.find(address);
		if (itSite == conditionSiteMap_.end())
		{
			conditionSiteMap_.emplace(
			    address,
			    ConditionRuntime{takenTarget, fallThrough,
			                     lastModule_.baseOfImage_, &condition});
		}
		else
		{
			// Re-registration of the same site (e.g. the DLL was unloaded and
			// reloaded): refresh the targets, keep the record pointer and the
			// observed outcomes.
			itSite->second.takenTarget_ = takenTarget;
			itSite->second.fallThrough_ = fallThrough;
			itSite->second.dllBaseOfImage_ = lastModule_.baseOfImage_;
			itSite->second.condition_ = &condition;
		}
	}

	//-------------------------------------------------------------------------
	ExecutedAddressManager::ConditionSiteInfo
	ExecutedAddressManager::GetConditionSite(const Address& address) const
	{
		auto it = conditionSiteMap_.find(address);

		if (it == conditionSiteMap_.end())
			return ConditionSiteInfo{};
		return ConditionSiteInfo{it->second.takenTarget_,
		                         it->second.fallThrough_};
	}

	//-------------------------------------------------------------------------
	void ExecutedAddressManager::MarkConditionOutcome(
		const Address& address, bool taken)
	{
		auto itSite = conditionSiteMap_.find(address);

		if (itSite == conditionSiteMap_.end())
			return;

		auto* condition = itSite->second.condition_;
		if (!condition)
			THROW("Condition state pointer is null.");

		if (taken)
			condition->takenSeen_ = true;
		else
			condition->notTakenSeen_ = true;
		++condition->observationCount_;

		LOG_TRACE << "BranchCoverage outcome credited " << address
		          << " taken=" << taken
		          << " takenSeen=" << condition->takenSeen_
		          << " notTakenSeen=" << condition->notTakenSeen_
		          << " obsCount=" << condition->observationCount_;
	}

	//-------------------------------------------------------------------------
	bool ExecutedAddressManager::ShouldReplantConditionSite(
		const Address& address) const
	{
		auto itSite = conditionSiteMap_.find(address);

		if (itSite == conditionSiteMap_.end())
			return false;

		const auto* condition = itSite->second.condition_;
		if (!condition)
			return false;

		// Re-observe while an outcome is missing, bounded by the cap. The
		// count grows by one per observation (MarkConditionOutcome); each
		// plant yields exactly one more observation.
		static constexpr unsigned int MaxObservationsPerCondition = 100;

		return (!condition->takenSeen_ || !condition->notTakenSeen_) &&
		       condition->observationCount_ < MaxObservationsPerCondition;
	}
	
	//-------------------------------------------------------------------------
	Plugin::CoverageData ExecutedAddressManager::CreateCoverageData(
		const std::wstring& name,
		int exitCode) const
	{
		Plugin::CoverageData coverageData{ name, exitCode };

		for (const auto& pair : modules_)
		{
			const auto& module = pair.second;
			auto& moduleCoverage = coverageData.AddModule(module.name_);

			for (const auto& file : module.files_)
			{
				const std::wstring& name = file.first;
				const File& fileData = file.second;

				auto& fileCoverage = moduleCoverage.AddFile(name);

				for (const auto& pair : fileData.lines)
				{
					auto lineNumber = pair.first;
					bool hasLineBeenExecuted = pair.second;

					fileCoverage.AddLine(lineNumber, hasLineBeenExecuted);
				}

				// Attach branch conditions (grouped per line, index order).
				unsigned int currentLine = 0;
				std::vector<Plugin::LineCoverage::Condition> conditions;
				auto flush = [&]()
				{
					if (!conditions.empty())
						fileCoverage.AddLineConditions(currentLine, std::move(conditions));
					conditions.clear();
				};
				for (const auto& pair : fileData.conditions)
				{
					if (pair.first.first != currentLine)
					{
						flush();
						currentLine = pair.first.first;
					}
					conditions.emplace_back(
					    pair.first.second,
					    pair.second.takenSeen_,
					    pair.second.notTakenSeen_);
				}
				flush();
			}
		}

		return coverageData;
	}

	//-------------------------------------------------------------------------
	template <typename Condition>
	void ExecutedAddressManager::RemoveAddressLineIf(Condition condition)
	{
		auto it = addressLineMap_.begin();

		while (it != addressLineMap_.end())
		{
			if (condition(*it))
				it = addressLineMap_.erase(it);
			else
				++it;
		}
	}

	//-------------------------------------------------------------------------
	template <typename Condition>
	void ExecutedAddressManager::RemoveConditionSiteIf(Condition condition)
	{
		auto it = conditionSiteMap_.begin();

		while (it != conditionSiteMap_.end())
		{
			if (condition(*it))
				it = conditionSiteMap_.erase(it);
			else
				++it;
		}
	}

	//-------------------------------------------------------------------------
	void ExecutedAddressManager::OnExitProcess(HANDLE hProcess)
	{
		RemoveAddressLineIf([=](const auto& pair)
		{
			return pair.first.GetProcessHandle() == hProcess;
		});

		RemoveConditionSiteIf([=](const auto& pair)
		{
			return pair.first.GetProcessHandle() == hProcess;
		});
	}

	//-------------------------------------------------------------------------
	void ExecutedAddressManager::OnUnloadModule(HANDLE hProcess, void* dllBaseOfImage)
	{
		RemoveAddressLineIf([=](const auto& pair)
		{
			return pair.first.GetProcessHandle() == hProcess
				&& pair.second.dllBaseOfImage_ == dllBaseOfImage;
		});

		RemoveConditionSiteIf([=](const auto& pair)
		{
			return pair.first.GetProcessHandle() == hProcess
				&& pair.second.dllBaseOfImage_ == dllBaseOfImage;
		});
	}
}
