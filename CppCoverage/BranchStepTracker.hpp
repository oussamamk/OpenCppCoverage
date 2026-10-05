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

#pragma once

#include <cstdint>
#include <map>

#include <Windows.h>

#include "CppCoverageExport.hpp"

namespace CppCoverage
{
	//-------------------------------------------------------------------------
	// BranchStepTracker: per-thread pending single-step state for the branch
	// coverage feature (--branch).
	//
	// Cycle: a breakpoint hit at a conditional-branch site arms a pending
	// step for that thread; the debugger then single-steps the branch
	// instruction and the resulting EXCEPTION_SINGLE_STEP reports the
	// landing address - the taken target or the fall-through - which is the
	// observed outcome.
	//
	// Re-observation: a one-shot breakpoint yields at most one outcome per
	// plant; to see BOTH outcomes (Emma semantics) the site breakpoint is
	// re-planted until both outcomes are seen or the per-condition
	// observation cap is reached (see ExecutedAddressManager::
	// ShouldReplantConditionSite, which owns that decision).
	//
	// Safety rule (leak guard): if anything other than the expected
	// single-step arrives while a step is pending (an unrelated exception on
	// the same thread, a lost step), CancelStep clears the pending state; the
	// caller must also clear the single-step flag from the thread context so
	// the thread does not trap forever.
	//-------------------------------------------------------------------------
	class CPPCOVERAGE_DLL BranchStepTracker
	{
	public:
		struct PendingStep
		{
			std::uint64_t siteAddress_;
			std::uint64_t takenTarget_;
			std::uint64_t fallThrough_;
		};

		void ArmStep(DWORD threadId, const PendingStep& pendingStep);

		// Returns the armed step for a thread without disarming it.
		const PendingStep* GetPendingStep(DWORD threadId) const;

		// Disarms the step for a thread.
		void CancelStep(DWORD threadId);

		void OnExitThread(DWORD threadId);
		void OnExitProcess(DWORD processId);

	  private:
		std::map<DWORD, PendingStep> pendingSteps_;
	};

}
