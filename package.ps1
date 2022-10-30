#
#  Copyright 2022, Roger Brown
#
#  This file is part of rhubarb-geek-pi/sqlite-tools.
#
#  This program is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#

$SQLITEVERS = "3390400"
$Package = "sqlite-tools-win32-x86-$SQLITEVERS"
$Source = "sqlite-amalgamation-$SQLITEVERS"
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$SHA256BIN = "5FAF62F2C75B32ED9B795607FD29E82E6105BC8AEEB1E13DC80E67BE373C5ED3"
$SHA256SRC = "9C99955B21D2374F3A385D67A1F64CBACB1D4130947473D25C77AD609C03B4CD"

$env:SQLITEVERS="3.39.04.00"

trap
{
	throw $PSItem
}

if (-not(Test-Path -Path "$Package"))
{
	if (-not(Test-Path -Path "$Package.zip"))
	{
		Invoke-WebRequest -Uri "https://www.sqlite.org/2022/$Package.zip" -OutFile "$Package.zip"
	}

	if ((Get-FileHash -LiteralPath "$Package.zip" -Algorithm "SHA256").Hash -ne $SHA256BIN)
	{
		throw "SHA256 mismatch for $Package.zip"
	}

	Expand-Archive -Path "$Package.zip" -DestinationPath .
}

if (-not(Test-Path -Path "$Source"))
{
	if (-not(Test-Path -Path "$Source.zip"))
	{
		Invoke-WebRequest -Uri "https://www.sqlite.org/2022/$Source.zip" -OutFile "$Source.zip"
	}

	if ((Get-FileHash -LiteralPath "$Source.zip" -Algorithm "SHA256").Hash -ne $SHA256SRC)
	{
		throw "SHA256 mismatch for $Source.zip"
	}

	Expand-Archive -Path "$Source.zip" -DestinationPath .
}

(
	( "x64","${Env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"),
	( "arm","${Env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsamd64_arm.bat"),
	( "arm64","${Env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsamd64_arm64.bat")
) | foreach {
	$ARCH = $_[0]
	$VCVARS = $_[1]

	$OutputDir = "sqlite-tools-win32-$ARCH-$SQLITEVERS"

	if (-not(Test-Path -Path "$OutputDir"))
	{
		$null = New-Item -Path "." -Name "$OutputDir" -ItemType "directory"
	}

	if (-not(Test-Path -Path "$OutputDir\sqlite3.exe"))
	{
		foreach ($Name in "shell.obj", "sqlite3.obj", "sqlite3.res") {
			if (Test-Path "$Name") {
				Remove-Item "$Name" -Force -Recurse
			} 
		}

		@"
CALL "$VCVARS"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
RC.EXE /r /fosqlite3.res sqlite3.rc
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
CL.EXE /MT /DWINVER=0x600 /D_WIN32_WINNT=0x600 "$Source\shell.c" "$Source\sqlite3.c" "-I$Source" "/Fe$OutputDir\sqlite3.exe" /link /VERSION:1.0 /SUBSYSTEM:CONSOLE sqlite3.res
EXIT %ERRORLEVEL%
"@ | & "$env:COMSPEC"

		If ( $LastExitCode -ne 0 )
		{
			Exit $LastExitCode
		}

		foreach ($Name in "shell.obj", "sqlite3.obj", "sqlite3.res") {
			if (Test-Path "$Name") {
				Remove-Item "$Name" -Force -Recurse
			} 
		}
	}

	if (-not(Test-Path -Path "$OutputDir.zip"))
	{
		Compress-Archive -DestinationPath "$OutputDir.zip" -LiteralPath "$OutputDir"
	}
}

foreach ($ARCH in "x86", "x64", "arm64") {
	$Package = "sqlite-tools-win32-$ARCH-$SQLITEVERS"

	$env:SOURCEDIR="$Package"

	& "${env:WIX}bin\candle.exe" -nologo "sqlite-tools-win32-$ARCH.wxs"

	if ($LastExitCode -ne 0)
	{
		exit $LastExitCode
	}

	& "${env:WIX}bin\light.exe" -nologo -cultures:null -out "$Package.msi" "sqlite-tools-win32-$ARCH.wixobj"

	if ($LastExitCode -ne 0)
	{
		exit $LastExitCode
	}
}


