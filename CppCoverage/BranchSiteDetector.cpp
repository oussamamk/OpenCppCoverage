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
#include "BranchSiteDetector.hpp"

#include <capstone/capstone.h>

#include "CppCoverageException.hpp"

namespace CppCoverage
{
	namespace
	{
		//---------------------------------------------------------------------
		struct CapstoneHandle
		{
			CapstoneHandle(csh handle) : handle_{handle} {}
			~CapstoneHandle() { cs_close(&handle_); }
			CapstoneHandle(const CapstoneHandle&) = delete;
			CapstoneHandle& operator=(const CapstoneHandle&) = delete;

			csh handle_;
		};

		//---------------------------------------------------------------------
		bool IsConditionalBranchX86(unsigned int id)
		{
			switch (id)
			{
				// Short and near conditional jumps share X86_INS_J* ids with
				// their unconditional relatives; capstone gives the
				// unconditional JMP its own id, and every other J* below is
				// conditional (Jcc family + jcxz/loopcc).
				case X86_INS_JE:
				case X86_INS_JNE:
				case X86_INS_JA:
				case X86_INS_JAE:
				case X86_INS_JB:
				case X86_INS_JBE:
				case X86_INS_JG:
				case X86_INS_JGE:
				case X86_INS_JL:
				case X86_INS_JLE:
				case X86_INS_JS:
				case X86_INS_JNS:
				case X86_INS_JO:
				case X86_INS_JNO:
				case X86_INS_JP:
				case X86_INS_JNP:
				case X86_INS_JCXZ:
				case X86_INS_JECXZ:
				case X86_INS_JRCXZ:
				case X86_INS_LOOP:
				case X86_INS_LOOPE:
				case X86_INS_LOOPNE:
					return true;
				default:
					return false;
			}
		}

		//---------------------------------------------------------------------
		bool IsConditionalBranchArm64(unsigned int id)
		{
			switch (id)
			{
				case ARM64_INS_B: // conditional only when cc != AL (checked by caller)
				case ARM64_INS_CBZ:
				case ARM64_INS_CBNZ:
				case ARM64_INS_TBZ:
				case ARM64_INS_TBNZ:
					return true;
				default:
					return false;
			}
		}
	}

	//-------------------------------------------------------------------------
	std::vector<BranchSiteDetector::Site> BranchSiteDetector::DetectSites(
		std::uint64_t begin,
		const std::uint8_t* bytes,
		std::size_t size)
	{
#ifdef _M_ARM64
		return DetectSitesArm64(begin, bytes, size);
#else
		return DetectSitesX86(begin, bytes, size);
#endif
	}

	//-------------------------------------------------------------------------
	std::vector<BranchSiteDetector::Site> BranchSiteDetector::DetectSitesX86(
		std::uint64_t begin, const std::uint8_t* bytes, std::size_t size)
	{
		std::vector<Site> sites;

		csh handle = 0;
		auto mode = cs_mode(CS_MODE_64);
#ifdef _M_IX86
		mode = cs_mode(CS_MODE_32);
#endif
		if (cs_open(CS_ARCH_X86, mode, &handle) != CS_ERR_OK)
			THROW("Capstone: cannot open x86 engine");

		CapstoneHandle guard{handle};
		// detail is required to read operands (and ARM64's condition code);
		// without it insn.detail stays null.
		cs_option(handle, CS_OPT_DETAIL, CS_OPT_ON);
		cs_option(handle, CS_OPT_SKIPDATA, CS_OPT_ON);

		cs_insn* insns = nullptr;
		auto count = cs_disasm(handle, bytes, size, begin, 0, &insns);
		if (count == 0)
			return sites;

		for (std::size_t i = 0; i < count; ++i)
		{
			const auto& insn = insns[i];
			if (IsConditionalBranchX86(insn.id))
			{
				Site site;
				site.address_ = insn.address;
				site.size_ = insn.size;
				site.fallThrough_ = insn.address + insn.size;
				// The single branch operand of Jcc/JCXZ/LOOPcc is the target.
				if (insn.detail && insn.detail->x86.op_count == 1 &&
					insn.detail->x86.operands[0].type == X86_OP_IMM)
				{
					site.takenTarget_ = static_cast<std::uint64_t>(
						insn.detail->x86.operands[0].imm);
				}
				else
				{
					// Without detail (or an unexpected encoding) the target
					// cannot be trusted: skip this site entirely rather than
					// plant a breakpoint whose outcome cannot be classified.
					continue;
				}
				sites.push_back(site);
			}
		}

		cs_free(insns, count);
		return sites;
	}

	//-------------------------------------------------------------------------
	std::vector<BranchSiteDetector::Site> BranchSiteDetector::DetectSitesArm64(
		std::uint64_t begin, const std::uint8_t* bytes, std::size_t size)
	{
		std::vector<Site> sites;

		csh handle = 0;
		if (cs_open(CS_ARCH_ARM64, CS_MODE_LITTLE_ENDIAN, &handle) != CS_ERR_OK)
			THROW("Capstone: cannot open ARM64 engine");

		CapstoneHandle guard{handle};
		cs_option(handle, CS_OPT_DETAIL, CS_OPT_ON);

		cs_insn* insns = nullptr;
		auto count = cs_disasm(handle, bytes, size, begin, 0, &insns);
		if (count == 0)
			return sites;

		for (std::size_t i = 0; i < count; ++i)
		{
			const auto& insn = insns[i];
			if (!IsConditionalBranchArm64(insn.id))
				continue;

			// B (0x14xxxxxx) is the unconditional branch; B.cond carries the
			// 4-bit condition field. capstone models B.cond as ARM64_INS_B
			// with cc != ARM64_CC_INVALID / AL, so filter here.
			if (insn.id == ARM64_INS_B)
			{
				auto cc = insn.detail->arm64.cc;
				if (cc == ARM64_CC_INVALID || cc == ARM64_CC_AL || cc == ARM64_CC_NV)
					continue;
			}

			// Branch target: the last IMM operand. B.cond has one operand;
			// CBZ/CBNZ/TBZ/TBNZ carry the target as operand[1] (after the
			// register operand).
			bool hasTarget = false;
			std::int64_t target = 0;
			if (insn.detail && insn.detail->arm64.op_count >= 1)
			{
				for (int op = static_cast<int>(insn.detail->arm64.op_count) - 1;
				     op >= 0; --op)
				{
					if (insn.detail->arm64.operands[op].type == ARM64_OP_IMM)
					{
						target = insn.detail->arm64.operands[op].imm;
						hasTarget = true;
						break;
					}
				}
			}
			if (!hasTarget)
				continue;

			Site site;
			site.address_ = insn.address;
			site.size_ = insn.size;
			site.takenTarget_ = static_cast<std::uint64_t>(target);
			site.fallThrough_ = insn.address + insn.size;
			sites.push_back(site);
		}

		cs_free(insns, count);
		return sites;
	}
}
