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
#include "BranchStepTracker.hpp"

#include "tools/Log.hpp"

namespace CppCoverage
{
	//-------------------------------------------------------------------------
	void BranchStepTracker::ArmStep(DWORD threadId, const PendingStep& pendingStep)
	{
		pendingSteps_[threadId] = pendingStep;
	}

	//-------------------------------------------------------------------------
	const BranchStepTracker::PendingStep*
	BranchStepTracker::GetPendingStep(DWORD threadId) const
	{
		auto it = pendingSteps_.find(threadId);

		return it == pendingSteps_.end() ? nullptr : &it->second;
	}

	//-------------------------------------------------------------------------
	void BranchStepTracker::CancelStep(DWORD threadId)
	{
		pendingSteps_.erase(threadId);
	}

	//-------------------------------------------------------------------------
	void BranchStepTracker::OnExitThread(DWORD threadId)
	{
		CancelStep(threadId);
	}

	//-------------------------------------------------------------------------
	void BranchStepTracker::OnExitProcess(DWORD processId)
	{
		// Thread ids are process-global; on process exit drop every pending
		// step that could belong to it. A stale pending step can only cause
		// one mis-attributed outcome, but cleanliness is cheap here.
		pendingSteps_.clear();
	}
}
