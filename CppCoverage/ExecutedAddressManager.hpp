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

#include <cstdint>
#include <string>

#include <Windows.h>
#include <map>
#include <set>
#include <boost/optional.hpp>

#include "Plugin/Exporter/CoverageData.hpp"
#include "CppCoverageExport.hpp"
#include "BreakPoint.hpp"

namespace CppCoverage
{
	class FileCoverage;
	class Address;

	class CPPCOVERAGE_DLL ExecutedAddressManager
	{
	public:
		ExecutedAddressManager();
		~ExecutedAddressManager();

		void AddModule(const std::wstring& moduleName, void* dllBaseOfImage);
		void OnUnloadModule(HANDLE hProcess, void* dllBaseOfImage);

		bool RegisterAddress(
			const Address&,
			const std::wstring& filename,
			unsigned int line,
			BreakPoint::InstructionValue instruction);

		// Branch coverage (--branch): registers a conditional branch site.
		// The site shares the one-shot breakpoint of its address (merged into
		// the same initial batch by MonitoredLineRegister); hitting it marks
		// the owning line executed like any other address.
		// Idempotent per address: re-registration (module reload) keeps the
		// already-observed outcomes.
		void RegisterConditionSite(
			const Address&,
			const std::wstring& filename,
			unsigned int line,
			unsigned int conditionIndex,
			std::uint64_t takenTarget,
			std::uint64_t fallThrough);

		// Records the observed outcome of the pending single-step for the
		// condition planted at address. No-op if the address is unknown or
		// was unloaded (e.g. DLL freed between the breakpoint hit and the
		// single-step event).
		void MarkConditionOutcome(const Address&, bool taken);

		// Branch coverage: whether the site breakpoint at address should be
		// re-planted after the latest observation (an outcome is still
		// unseen and the observation cap is not reached). False when the
		// address is unknown.
		bool ShouldReplantConditionSite(const Address&) const;

		// Branch coverage runtime info of one site (all-zero targets mean
		// the address carries no conditional branch).
		struct ConditionSiteInfo
		{
			std::uint64_t takenTarget_ = 0;
			std::uint64_t fallThrough_ = 0;
		};
		ConditionSiteInfo GetConditionSite(const Address&) const;

		boost::optional<BreakPoint::InstructionValue> MarkAddressAsExecuted(const Address&);

		Plugin::CoverageData CreateCoverageData(const std::wstring& name, int exitCode) const;
		void OnExitProcess(HANDLE hProcess);

	private:
		struct Module;
		struct File;
		struct File;
		struct Line;
		struct ConditionRuntime;
		struct ConditionSiteInfo;
		struct LastModule
		{
			Module* module_;
			void* baseOfImage_;
		};
		ExecutedAddressManager(const ExecutedAddressManager&) = delete;
		ExecutedAddressManager& operator=(const ExecutedAddressManager&) = delete;

		Module& GetLastAddedModule();
		template <typename F>
		void RemoveAddressLineIf(F fct);
		template <typename F>
		void RemoveConditionSiteIf(F fct);

		std::map<std::wstring, Module> modules_;
		std::map<Address, Line> addressLineMap_;
		std::map<Address, ConditionRuntime> conditionSiteMap_;
		LastModule lastModule_;
	};
}
