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

#include <filesystem>
#include <fstream>
#include <cctype>

#include "TestCoverageConsole/TestCoverageConsole.hpp"
#include "TestHelper/TemporaryPath.hpp"

#include "CppCoverage/ExportOptionParser.hpp"
#include "CppCoverage/ProgramOptions.hpp"
#include "Plugin/Exporter/CoverageData.hpp"
#include "CppCoverage/OptionsParser.hpp"

#include "Exporter/binary/CoverageDataDeserializer.hpp"

#include "TestHelper/CoverageDataComparer.hpp"
#include "TestCoverageSharedLib/TestCoverageSharedLib.hpp"

#include "Tools/Tool.hpp"

#include "OpenCppCoverageTestTools.hpp"

namespace fs = std::filesystem;
namespace cov = CppCoverage;

namespace OpenCppCoverageTest
{
	namespace
	{		
		
		//---------------------------------------------------------------------
		void RunCoverage(
			std::vector<std::pair<std::string, std::string>> coverageArguments,
			const std::filesystem::path& output)
		{
			fs::path testCoverageConsole = TestCoverageConsole::GetOutputBinaryPath();						
			
			AddDefaultFilters(coverageArguments, testCoverageConsole);
			coverageArguments.emplace_back(cov::ProgramOptions::QuietOption, "");
			int exitCode = RunCoverageFor(coverageArguments, testCoverageConsole, {});
			
			ASSERT_EQ(0, exitCode);		
			ASSERT_TRUE(Tools::FileExists(output));
		}
		
		//---------------------------------------------------------------------
		void RunCoverage(const std::string& exportType)
		{
			TestHelper::TemporaryPath output;
			std::vector<std::pair<std::string, std::string>> coverageArguments;

			coverageArguments.push_back(BuildExportTypeString(exportType, output));
			RunCoverage(coverageArguments, output);
		}

		//---------------------------------------------------------------------
		Plugin::CoverageData ReadCoverageDataFromFile(const TestHelper::TemporaryPath& temporaryPath)
		{
			Exporter::CoverageDataDeserializer coverageDataDeserializer;
			
			return coverageDataDeserializer.Deserialize(temporaryPath.GetPath(), "");
		}
	}

	//-------------------------------------------------------------------------
	TEST(ImportExportTest, ExportHtml)
	{
		RunCoverage(cov::ExportOptionParser::ExportTypeHtmlValue);
	}

	//-------------------------------------------------------------------------
	TEST(ImportExportTest, ExportCobertura)
	{
		RunCoverage(cov::ExportOptionParser::ExportTypeCoberturaValue);
	}

	//-------------------------------------------------------------------------
	TEST(ImportExportTest, ExportCoberturaWithBranchCoverage)
	{
		TestHelper::TemporaryPath output;
		fs::path testCoverageConsole = TestCoverageConsole::GetOutputBinaryPath();

		std::vector<std::pair<std::string, std::string>> coverageArguments;
		AddDefaultFilters(coverageArguments, testCoverageConsole);
		coverageArguments.emplace_back(cov::ProgramOptions::BranchOption, "");
		coverageArguments.emplace_back(cov::ProgramOptions::QuietOption, "");
		coverageArguments.push_back(BuildExportTypeString(
			cov::ExportOptionParser::ExportTypeCoberturaValue, output.GetPath()));

		std::vector<std::wstring> arguments{ TestCoverageConsole::TestBranches };
		int exitCode = RunCoverageFor(coverageArguments, testCoverageConsole, arguments, nullptr);
		ASSERT_EQ(0, exitCode);
		ASSERT_TRUE(Tools::FileExists(output.GetPath()));

		// The report must carry real branch data: condition-coverage on a
		// line of the branchy scenario and non-zero root branch totals.
		std::ifstream ifs{ output.GetPath().string().c_str() };
		ASSERT_TRUE(ifs.good());
		std::string xml{ std::istreambuf_iterator<char>(ifs),
		                 std::istreambuf_iterator<char>() };

		ASSERT_NE(std::string::npos, xml.find("condition-coverage="));
		// branches-valid is non-zero (the character after the quote is a digit > 0).
		auto pos = xml.find("branches-valid=\"");
		ASSERT_NE(std::string::npos, pos);
		ASSERT_TRUE(std::isdigit(static_cast<unsigned char>(xml[pos + 16])));
		ASSERT_NE('0', xml[pos + 16]);
	}

	//-------------------------------------------------------------------------
	TEST(ImportExportTest, ExportImportBinary)
	{
		TestHelper::TemporaryPath initialOutput;
		RunCoverage({ BuildExportTypeString(cov::ExportOptionParser::ExportTypeBinaryValue, initialOutput) }, initialOutput);

		TestHelper::TemporaryPath finalOutput;

		RunCoverage(
		{ { cov::ProgramOptions::InputCoverageValue, initialOutput.GetPath().string() },
		{ BuildExportTypeString(cov::ExportOptionParser::ExportTypeBinaryValue, finalOutput )} },
		finalOutput);	

		auto initialCoverage = ReadCoverageDataFromFile(initialOutput);
		auto finalCoverage = ReadCoverageDataFromFile(finalOutput);

		TestHelper::CoverageDataComparer coverageDataComparer;

		coverageDataComparer.AssertEquals(initialCoverage, finalCoverage);
	}	

	//-------------------------------------------------------------------------
	TEST(ImportExportTest, ExportPlugin)
	{
		TestHelper::TemporaryPath tempPath{
		    TestHelper::TemporaryPathOption::CreateAsFolder};
		auto output = tempPath.GetPath() / "Output.txt";
		auto dllPath = TestCoverageSharedLib::GetOutputBinaryPath();
		auto pluginName = dllPath.stem().string();

		RunCoverage({BuildExportTypeString(pluginName, output)}, output);
		ASSERT_NE(0, std::filesystem::file_size(output));
	}
}
