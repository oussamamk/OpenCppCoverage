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

#include "CppCoverage/BranchSiteDetector.hpp"

namespace ts = CppCoverage;

#ifndef _M_ARM64
// x64-engine tests: DetectSites dispatches by compile-time architecture, so
// they only run in x86/x64 builds.
TEST(BranchSiteDetectorTest, X64_JeShort)
{
	// je rel8 (short, +2): 74 02 ; nop ; nop
	const std::uint8_t bytes[] = { 0x74, 0x02, 0x90, 0x90 };
	auto sites = ts::BranchSiteDetector::DetectSites(0x1000, bytes, sizeof(bytes));

	ASSERT_EQ(1, sites.size());
	if (sites.size() == 1)
	{
		EXPECT_EQ(0x1000, sites[0].address_);
		EXPECT_EQ(2, sites[0].size_);
		EXPECT_EQ(0x1004, sites[0].takenTarget_);
		EXPECT_EQ(0x1002, sites[0].fallThrough_);
	}
}

//-----------------------------------------------------------------------------
TEST(BranchSiteDetectorTest, X64_JneNear)
{
	// nop ; jne rel32 (-4): 90 0f 85 fc ff ff ff ; nop
	const std::uint8_t bytes[] = { 0x90, 0x0F, 0x85, 0xFC, 0xFF, 0xFF, 0xFF, 0x90 };
	auto sites = ts::BranchSiteDetector::DetectSites(0x2000, bytes, sizeof(bytes));

	ASSERT_EQ(1, sites.size());
	if (sites.size() == 1)
	{
		EXPECT_EQ(0x2001, sites[0].address_);
		EXPECT_EQ(6, sites[0].size_);
		EXPECT_EQ(0x2001 + 6 + (-4), sites[0].takenTarget_);
		EXPECT_EQ(0x2007, sites[0].fallThrough_);
	}
}

//-----------------------------------------------------------------------------
TEST(BranchSiteDetectorTest, X64_UnconditionalJmpIgnored)
{
	// jmp rel8: eb 02 ; nop ; nop
	const std::uint8_t bytes[] = { 0xEB, 0x02, 0x90, 0x90 };
	auto sites = ts::BranchSiteDetector::DetectSites(0x3000, bytes, sizeof(bytes));

	EXPECT_EQ(0, sites.size());
}

//-----------------------------------------------------------------------------
TEST(BranchSiteDetectorTest, X64_Loop)
{
	// loop rel8 (-2): e2 fe ; nop
	const std::uint8_t bytes[] = { 0xE2, 0xFE, 0x90 };
	auto sites = ts::BranchSiteDetector::DetectSites(0x4000, bytes, sizeof(bytes));

	ASSERT_EQ(1, sites.size());
	if (sites.size() == 1)
	{
		EXPECT_EQ(0x4000, sites[0].address_);
		EXPECT_EQ(0x4000, sites[0].takenTarget_);
		EXPECT_EQ(0x4002, sites[0].fallThrough_);
	}
}
#endif

#ifdef _M_ARM64
//-----------------------------------------------------------------------------
TEST(BranchSiteDetectorTest, Arm64_BCond)
{
	// b.eq +16: 0x54000101 (imm19=8) ; nop ; nop ; nop
	const std::uint8_t bytes[] = { 0x81, 0x00, 0x00, 0x54, 0x1F, 0x20, 0x03, 0xD5,
	                               0x1F, 0x20, 0x03, 0xD5, 0x1F, 0x20, 0x03, 0xD5 };
	auto sites = ts::BranchSiteDetector::DetectSites(0x1000, bytes, sizeof(bytes));

	ASSERT_EQ(1, sites.size());
	if (sites.size() == 1)
	{
		EXPECT_EQ(0x1000, sites[0].address_);
		EXPECT_EQ(4, sites[0].size_);
		EXPECT_EQ(0x1010, sites[0].takenTarget_);
		EXPECT_EQ(0x1004, sites[0].fallThrough_);
	}
}

//-----------------------------------------------------------------------------
TEST(BranchSiteDetectorTest, Arm64_Cbz)
{
	// cbz x0, +8: 0xB4000040 ; nop ; nop ; nop
	const std::uint8_t bytes[] = { 0x40, 0x00, 0x00, 0xB4, 0x1F, 0x20, 0x03, 0xD5,
	                               0x1F, 0x20, 0x03, 0xD5, 0x1F, 0x20, 0x03, 0xD5 };
	auto sites = ts::BranchSiteDetector::DetectSites(0x2000, bytes, sizeof(bytes));

	ASSERT_EQ(1, sites.size());
	if (sites.size() == 1)
	{
		EXPECT_EQ(0x2000, sites[0].address_);
		EXPECT_EQ(0x2008, sites[0].takenTarget_);
		EXPECT_EQ(0x2004, sites[0].fallThrough_);
	}
}

//-----------------------------------------------------------------------------
TEST(BranchSiteDetectorTest, Arm64_UnconditionalBIgnored)
{
	// b +4 (unconditional): 0x14000001 ; nop
	const std::uint8_t bytes[] = { 0x01, 0x00, 0x00, 0x14, 0x1F, 0x20, 0x03, 0xD5 };
	auto sites = ts::BranchSiteDetector::DetectSites(0x3000, bytes, sizeof(bytes));

	EXPECT_EQ(0, sites.size());
}
#endif
