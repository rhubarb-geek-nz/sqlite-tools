#
#  Copyright 2023, Roger Brown
#
#  This file is part of rhubarb-geek-nz/sqlite-tools.
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

$SQLITEVERS = "3410000"
$Package = "sqlite-tools-win32-x86-$SQLITEVERS"
$Source = "sqlite-amalgamation-$SQLITEVERS"
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$SHA256BIN = "16AD3A028A89DFF6E5050A3CDAFB7B7F2473DD02DDC7717AEDF7CB58090B9C07"
$SHA256SRC = "146CE189B67FDBEFBF2D72CDC81E198D07FF643614CC9102E9BF063255E8E7E1"
$VCVARSDIR = "${Env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build"

$env:SQLITEVERS = "3.41.0.0"

trap
{
	throw $PSItem
}

if (-not(Test-Path -Path "$Package"))
{
	if (-not(Test-Path -Path "$Package.zip"))
	{
		Invoke-WebRequest -Uri "https://www.sqlite.org/2023/$Package.zip" -OutFile "$Package.zip"
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
		Invoke-WebRequest -Uri "https://www.sqlite.org/2023/$Source.zip" -OutFile "$Source.zip"
	}

	if ((Get-FileHash -LiteralPath "$Source.zip" -Algorithm "SHA256").Hash -ne $SHA256SRC)
	{
		throw "SHA256 mismatch for $Source.zip"
	}

	Expand-Archive -Path "$Source.zip" -DestinationPath .
}

(
	( "x64","$VCVARSDIR\vcvars64.bat"),
	( "arm","$VCVARSDIR\vcvarsamd64_arm.bat"),
	( "arm64","$VCVARSDIR\vcvarsamd64_arm64.bat")
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

	if (-not(Test-Path -Path "$Package.msi"))
	{
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
}

if (-not(Test-Path -Path "bundle"))
{
	$null = New-Item ./bundle -type Directory

	(
		( "x86","$VCVARSDIR\vcvars32.bat"),
		( "x64","$VCVARSDIR\vcvars64.bat"),
		( "arm","$VCVARSDIR\vcvarsamd64_arm.bat"),
		( "arm64","$VCVARSDIR\vcvarsamd64_arm64.bat")
	) | foreach {
		$ARCH = $_[0]
		$VCVARS = $_[1]
		$ZIP = "sqlite-tools-win32-$ARCH-$SQLITEVERS"

		$xmlDoc = [System.Xml.XmlDocument](Get-Content "Package.appxmanifest")

		$nsMgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList $xmlDoc.NameTable

		$nsmgr.AddNamespace("man", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")

		$xmlNode = $xmlDoc.SelectSingleNode("/man:Package/man:Identity", $nsmgr)

		$xmlNode.ProcessorArchitecture = $ARCH
		$xmlNode.Version = $env:SQLITEVERS

		$xmlDoc.Save("AppxManifest.xml")

		$MSI = "bundle\sqlite-tools-win32-$ARCH-$SQLITEVERS.msix"

		@"
CALL "$VCVARS"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
IF EXIST "bin" RMDIR /q /s "bin"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
MKDIR bin\assets
COPY assets\*.png bin\assets
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
COPY "$ZIP\sqlite3.exe" "bin\sqlite3.exe"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
IF EXIST "$MSI" DEL "$MSI"
makeappx pack /m AppxManifest.xml /f mapping.ini /p "$MSI"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
RMDIR /q /s "bin"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
EXIT %ERRORLEVEL%
"@ | & "$env:COMSPEC"

		If ( $LastExitCode -ne 0 )
		{
			Exit $LastExitCode
		}
	}
}

$BUNDLE = "sqlite-tools-win32-$SQLITEVERS.msixbundle"

If (-not(Test-Path -Path "$BUNDLE"))
{
		@"
CALL "$VCVARSDIR\vcvars32.bat"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
makeappx bundle /d bundle /p "$BUNDLE"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
EXIT %ERRORLEVEL%
"@ | & "$env:COMSPEC"

	If ( $LastExitCode -ne 0 )
	{
		Exit $LastExitCode
	}
}
