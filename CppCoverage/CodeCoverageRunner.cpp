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
#include "CodeCoverageRunner.hpp"

#include <sstream>
#include <vector>
#include <boost/optional.hpp>

#include "tools/Log.hpp"

#include "Plugin/Exporter/CoverageData.hpp"
#include "Debugger.hpp"
#include "ExecutedAddressManager.hpp"
#include "HandleInformation.hpp"
#include "BreakPoint.hpp"
#include "BranchStepTracker.hpp"
#include "CoverageFilterManager.hpp"
#include "StartInfo.hpp"
#include "ExceptionHandler.hpp"
#include "CppCoverageException.hpp"
#include "Address.hpp"
#include "RunCoverageSettings.hpp"
#include "MonitoredLineRegister.hpp"
#include "FilterAssistant.hpp"
#include "FileSystem.hpp"

#include "Tools/WarningManager.hpp"
#include "Tools/Tool.hpp"

namespace CppCoverage
{
	//-------------------------------------------------------------------------
	CodeCoverageRunner::CodeCoverageRunner(
	    std::shared_ptr<Tools::WarningManager> warningManager)
	    : warningManager_{warningManager},
	      filterAssistant_{
	          std::make_shared<FilterAssistant>(std::make_shared<FileSystem>())}
	{
		executedAddressManager_ = std::make_shared<ExecutedAddressManager>();
		exceptionHandler_ = std::make_unique<ExceptionHandler>();
		breakpoint_ = std::make_shared<BreakPoint>();
		branchStepTracker_ = std::make_unique<BranchStepTracker>();
	}

	//-------------------------------------------------------------------------
	CodeCoverageRunner::~CodeCoverageRunner()
	{
	}

	//-------------------------------------------------------------------------
	Plugin::CoverageData CodeCoverageRunner::RunCoverage(
		const RunCoverageSettings& settings)
	{
		Debugger debugger{ settings.GetCoverChildren(), settings.GetContinueAfterCppException(), settings.GetStopOnAssert()};

		branchCoverageEnabled_ = settings.GetBranchCoverage();

		coverageFilterManager_ = std::make_shared<CoverageFilterManager>(
			settings.GetCoverageFilterSettings(),
			settings.GetUnifiedDiffSettings(),
			settings.GetExcludedLineRegexes(),
			settings.GetOptimizedBuildSupport());

		monitoredLineRegister_ = std::make_unique<MonitoredLineRegister>(
		    breakpoint_,
		    executedAddressManager_,
		    coverageFilterManager_,
		    std::make_unique<DebugInformationEnumerator>(settings.GetSubstitutePdbSourcePaths()),
			filterAssistant_,
		    settings.GetBranchCoverage());

		const auto& startInfo = settings.GetStartInfo();
		int exitCode = debugger.Debug(startInfo, *this);
		const auto& path = startInfo.GetPath();

		auto warningMessageLines = coverageFilterManager_->ComputeWarningMessageLines(
			settings.GetMaxUnmatchPathsForWarning());
		for (const auto& line : warningMessageLines)
				LOG_WARNING << line;
		auto filterAdviceMessage = filterAssistant_->GetAdviceMessage();
		if (filterAdviceMessage)
			warningManager_->AddWarning(*filterAdviceMessage);
		return executedAddressManager_->CreateCoverageData(path.filename().wstring(), exitCode);
	}

	//-------------------------------------------------------------------------
	void CodeCoverageRunner::OnCreateProcess(const CREATE_PROCESS_DEBUG_INFO& processDebugInfo)
	{
		auto hProcess = processDebugInfo.hProcess;
		auto lpBaseOfImage = processDebugInfo.lpBaseOfImage;

		LoadModule(hProcess, processDebugInfo.hFile, lpBaseOfImage);
	}
	
	//-------------------------------------------------------------------------
	void CodeCoverageRunner::OnExitProcess(HANDLE hProcess, HANDLE, const EXIT_PROCESS_DEBUG_INFO&)
	{
		exceptionHandler_->OnExitProcess(hProcess);
		executedAddressManager_->OnExitProcess(hProcess);
		branchStepTracker_->OnExitProcess(::GetProcessId(hProcess));
	}

	//-------------------------------------------------------------------------
	void CodeCoverageRunner::OnLoadDll(
		HANDLE hProcess, 
		HANDLE hThread, 
		const LOAD_DLL_DEBUG_INFO& dllDebugInfo)
	{
		LoadModule(hProcess, dllDebugInfo.hFile, dllDebugInfo.lpBaseOfDll);
	}
	
	//-------------------------------------------------------------------------
	void CodeCoverageRunner::OnUnloadDll(
		HANDLE hProcess,
		HANDLE hThread,
		const UNLOAD_DLL_DEBUG_INFO& unloadDllDebugInfo)
	{
		executedAddressManager_->OnUnloadModule(hProcess, unloadDllDebugInfo.lpBaseOfDll);
	}

	//-------------------------------------------------------------------------
	IDebugEventsHandler::ExceptionType CodeCoverageRunner::OnException(
		HANDLE hProcess,
		HANDLE hThread,
		const EXCEPTION_DEBUG_INFO& exceptionDebugInfo)
	{
		std::wostringstream ostr;

		const auto& exceptionRecord = exceptionDebugInfo.ExceptionRecord;

		// Branch coverage single-step attribution: intercept the step we
		// armed BEFORE ExceptionHandler::HandleException, which would hand
		// the first-chance step to the debuggee (it has no handler for it).
		if (exceptionRecord.ExceptionCode == EXCEPTION_SINGLE_STEP)
		{
			return OnSingleStep(exceptionDebugInfo, hProcess, hThread);
		}

		auto status = exceptionHandler_->HandleException(hProcess, exceptionDebugInfo, ostr);

		switch (status)
		{
			case CppCoverage::ExceptionHandlerStatus::BreakPoint:
			{
				if (OnBreakPoint(exceptionDebugInfo, hProcess, hThread))
					return IDebugEventsHandler::ExceptionType::BreakPoint;
				return IDebugEventsHandler::ExceptionType::InvalidBreakPoint;
			}
			case CppCoverage::ExceptionHandlerStatus::FirstChanceException:
			{
				return IDebugEventsHandler::ExceptionType::NotHandled;
			}
			case CppCoverage::ExceptionHandlerStatus::Error:
			{
				LOG_ERROR << ostr.str();
				
				return IDebugEventsHandler::ExceptionType::Error;
			}
			case CppCoverage::ExceptionHandlerStatus::CppError:
			{
				LOG_ERROR << ostr.str();

				return IDebugEventsHandler::ExceptionType::CppError;
			}
		}

		return IDebugEventsHandler::ExceptionType::NotHandled;
	}
	
	//-------------------------------------------------------------------------
	bool CodeCoverageRunner::OnBreakPoint(
		const EXCEPTION_DEBUG_INFO& exceptionDebugInfo,
		HANDLE hProcess,
		HANDLE hThread)
	{
		const auto& exceptionRecord = exceptionDebugInfo.ExceptionRecord;
		auto addressValue = exceptionRecord.ExceptionAddress;
		Address address{ hProcess, addressValue };
		auto oldInstruction = executedAddressManager_->MarkAddressAsExecuted(address);

		if (oldInstruction)
		{
			// Branch coverage: when the hit address is a conditional-branch
			// site, request a single-step (in the same SetThreadContext as
			// the rewind) and arm the per-thread pending outcome.
			auto conditionSite = branchCoverageEnabled_
			    ? executedAddressManager_->GetConditionSite(address)
			    : ExecutedAddressManager::ConditionSiteInfo{};

			const bool isConditionSite = conditionSite.takenTarget_ != 0;

			LOG_TRACE << "BranchCoverage BP hit at 0x" << std::hex
			          << reinterpret_cast<std::uint64_t>(addressValue) << std::dec
			          << " isConditionSite=" << isConditionSite
			          << " taken=0x" << std::hex << conditionSite.takenTarget_
			          << " fallThrough=0x" << conditionSite.fallThrough_ << std::dec;

			if (isConditionSite)
			{
				BranchStepTracker::PendingStep pendingStep;
				pendingStep.siteAddress_ =
				    reinterpret_cast<std::uint64_t>(addressValue);
				pendingStep.takenTarget_ = conditionSite.takenTarget_;
				pendingStep.fallThrough_ = conditionSite.fallThrough_;
				branchStepTracker_->ArmStep(::GetThreadId(hThread), pendingStep);
			}

			breakpoint_->RemoveBreakPoint(address, *oldInstruction);
			breakpoint_->AdjustEipAfterBreakPointRemoval(
			    hThread, isConditionSite);
			return true;
		}

		return false;
	}

	//-------------------------------------------------------------------------
	IDebugEventsHandler::ExceptionType CodeCoverageRunner::OnSingleStep(
		const EXCEPTION_DEBUG_INFO& exceptionDebugInfo,
		HANDLE hProcess,
		HANDLE hThread)
	{
		auto threadId = ::GetThreadId(hThread);
		const auto* pendingStepPtr = branchStepTracker_->GetPendingStep(threadId);

		LOG_TRACE << "BranchCoverage SS event, pendingStep="
		          << (pendingStepPtr ? "yes" : "no");

		if (!pendingStepPtr)
		{
			// Not one of ours: a debuggee raising its own STATUS_SINGLE_STEP
			// gets swallowed (same trade-off as the initial breakpoint).
			LOG_WARNING << "Single step exception without pending branch step.";
			return IDebugEventsHandler::ExceptionType::SingleStep;
		}

		// Local copy: CancelStep below erases the map node this pointer
		// points into; anything read from it afterwards is freed memory.
		const BranchStepTracker::PendingStep pendingStep{*pendingStepPtr};

		// The landing address of the step (next instruction after the branch),
		// as a plain 64-bit value for comparison with the recorded targets.
#ifdef _M_ARM64
		// On ARM64 the software-step exception reports the landing PC in the
		// thread context, not reliably in ExceptionRecord.ExceptionAddress.
		CONTEXT stepContext;
		stepContext.ContextFlags = CONTEXT_CONTROL;
		if (!GetThreadContext(hThread, &stepContext))
			THROW_LAST_ERROR("Error in GetThreadContext", GetLastError());
		auto landingAddress = static_cast<std::uint64_t>(stepContext.Pc);
#else
		auto landingAddress =
		    reinterpret_cast<std::uint64_t>(
		        exceptionDebugInfo.ExceptionRecord.ExceptionAddress);
#endif

		bool isFallThrough = landingAddress == pendingStep.fallThrough_;
		bool isTaken = landingAddress == pendingStep.takenTarget_;

		LOG_TRACE << "BranchCoverage SS landing=0x" << std::hex << landingAddress
		          << " taken?=" << isTaken << " fall?=" << isFallThrough
		          << " (targets 0x" << pendingStep.takenTarget_ << " / 0x"
		          << pendingStep.fallThrough_ << ")" << std::dec;

		branchStepTracker_->CancelStep(threadId);

		if (isTaken || isFallThrough)
		{
			Address siteAddress{hProcess,
			                    reinterpret_cast<void*>(pendingStep.siteAddress_)};
			executedAddressManager_->MarkConditionOutcome(siteAddress, isTaken);

			// Re-plant the one-shot site breakpoint while an outcome is
			// still unseen (bounded by the observation cap): Emma semantics
			// need both outcomes. Safe because the site was restored after
			// its breakpoint fired; SetBreakPoints re-reads and re-saves the
			// restored original instruction.
			if (executedAddressManager_->ShouldReplantConditionSite(siteAddress))
			{
				std::vector<DWORD64> addresses{pendingStep.siteAddress_};
				breakpoint_->SetBreakPoints(hProcess, std::move(addresses));
			}

			return IDebugEventsHandler::ExceptionType::SingleStep;
		}

		// Mismatch: the step did not land on either target (unexpected event
		// ordering). The step flag is already consumed by this exception;
		// dropping the pending state keeps the thread from trapping forever.
		LOG_DEBUG << "Single step landed on unexpected address.";
		return IDebugEventsHandler::ExceptionType::SingleStep;
	}

	//-------------------------------------------------------------------------
	void CodeCoverageRunner::LoadModule(HANDLE hProcess,
	                                    HANDLE hFile,
	                                    void* baseOfImage)
	{
		HandleInformation handleInformation;

		std::wstring filename = handleInformation.ComputeFilename(hFile);

		auto isSelected = coverageFilterManager_->IsModuleSelected(filename);
		if (isSelected)
		{
			isSelected = monitoredLineRegister_->RegisterLineToMonitor(
			    filename, hProcess, baseOfImage);
		}
		filterAssistant_->OnNewModule(filename, isSelected);
	}
}
