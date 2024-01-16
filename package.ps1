#
#  Copyright 2024, Roger Brown
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

param(
	$CertificateThumbprint = '601A8B683F791E51F647D34AD102C38DA4DDB65F',
	$BundleThumbprint = '5F88DFB53180070771D4507244B2C9C622D741F8'
)

$SQLITEVERS = '3450000'
$Package = "sqlite-tools-win-x64-$SQLITEVERS"
$Source = "sqlite-amalgamation-$SQLITEVERS"
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$SHA256BIN = '771D3442164BC3B38C88365F5305B8E2EFD9EDDD10D59AEAB114AC2EF99E2784'
$SHA256SRC = 'BDE30D13EBDF84926DDD5E8B6DF145BE03A577A48FD075A087A5DD815BCDF740'
$VCVARSDIR = "${Env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build"

$SQLITEVERSMAJOR=[Int32]::Parse($SQLITEVERS.Substring(0,1))
$SQLITEVERSMINOR=[Int32]::Parse($SQLITEVERS.Substring(1,2))
$SQLITEVERSBUILD=[Int32]::Parse($SQLITEVERS.Substring(3,2))
$SQLITEVERSREVISION=[Int32]::Parse($SQLITEVERS.Substring(5,2))
$env:SQLITEVERS = "$SQLITEVERSMAJOR.$SQLITEVERSMINOR.$SQLITEVERSBUILD.$SQLITEVERSREVISION"

trap
{
	throw $PSItem
}

if (-not(Test-Path -Path "$Package"))
{
	if (-not(Test-Path -Path "$Package.zip"))
	{
		Invoke-WebRequest -Uri "https://www.sqlite.org/2024/$Package.zip" -OutFile "$Package.zip"
	}

	if ((Get-FileHash -LiteralPath "$Package.zip" -Algorithm "SHA256").Hash -ne $SHA256BIN)
	{
		throw "SHA256 mismatch for $Package.zip"
	}

	Expand-Archive -Path "$Package.zip" -DestinationPath "$Package"
}

if (-not(Test-Path -Path "$Source"))
{
	if (-not(Test-Path -Path "$Source.zip"))
	{
		Invoke-WebRequest -Uri "https://www.sqlite.org/2024/$Source.zip" -OutFile "$Source.zip"
	}

	if ((Get-FileHash -LiteralPath "$Source.zip" -Algorithm "SHA256").Hash -ne $SHA256SRC)
	{
		throw "SHA256 mismatch for $Source.zip"
	}

	Expand-Archive -Path "$Source.zip" -DestinationPath .
}

$VCVARSARM = 'vcvarsarm.bat'
$VCVARSARM64 = 'vcvarsarm64.bat'
$VCVARSAMD64 = 'vcvars64.bat'
$VCVARSX86 = 'vcvars32.bat'
$VCVARSHOST = 'vcvars32.bat'

switch ($Env:PROCESSOR_ARCHITECTURE)
{
	'AMD64' {
		$VCVARSX86 = 'vcvarsamd64_x86.bat'
		$VCVARSARM = 'vcvarsamd64_arm.bat'
		$VCVARSARM64 = 'vcvarsamd64_arm64.bat'
		$VCVARSHOST = $VCVARSAMD64
	}
	'ARM64' {
		$VCVARSX86 = 'vcvarsarm64_x86.bat'
		$VCVARSARM = 'vcvarsarm64_arm.bat'
		$VCVARSAMD64 = 'vcvarsarm64_amd64.bat'
		$VCVARSHOST = $VCVARSARM64
	}
	'X86' {
		$VCVARSXARM64 = 'vcvarsx86_arm64.bat'
		$VCVARSARM = 'vcvarsx86_arm.bat'
		$VCVARSAMD64 = 'vcvarsx86_amd64.bat'
	}
	Default {
		throw "Unknown architecture $Env:PROCESSOR_ARCHITECTURE"
	}
}

$VCVARSARCH = @{'arm' = $VCVARSARM; 'arm64' = $VCVARSARM64; 'x86' = $VCVARSX86; 'x64' = $VCVARSAMD64}

$VCVARSARCH | Format-Table -Property @{ l='Architecture'; e={$_.Name}},@{ l='Environment'; e={$_.Value}}

foreach ($ARCH in 'x86', 'arm', 'arm64' )
{
	$VCVARS = ( '{0}\{1}' -f $VCVARSDIR, $VCVARSARCH[$ARCH] )

	$OutputDir = "sqlite-tools-win-$ARCH-$SQLITEVERS"

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
RC.EXE /r "/DSQLITEVERSINT4=$SQLITEVERSMAJOR,$SQLITEVERSMINOR,$SQLITEVERSBUILD,$SQLITEVERSREVISION" "/DSQLITEVERSSTR3NULL=\""$SQLITEVERSMAJOR.$SQLITEVERSMINOR.$SQLITEVERSBUILD\0\""" /fosqlite3.res sqlite3.rc
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
CL.EXE /MT /DWINVER=0x600 /D_WIN32_WINNT=0x600 "$Source\shell.c" "$Source\sqlite3.c" "-I$Source" "/Fe$OutputDir\sqlite3.exe" /link /VERSION:1.0 /SUBSYSTEM:CONSOLE sqlite3.res
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
signtool sign /a /sha1 "$CertificateThumbprint" /fd SHA256 /t http://timestamp.digicert.com "$OutputDir\sqlite3.exe"
EXIT %ERRORLEVEL%
"@ | & "$env:COMSPEC"

		If ( $LastExitCode -ne 0 )
		{
			Exit $LastExitCode
		}

		foreach ($Name in 'shell.obj', 'sqlite3.obj', 'sqlite3.res')
		{
			if (Test-Path "$Name")
			{
				Remove-Item "$Name" -Force -Recurse
			} 
		}
	}

	if (-not(Test-Path -Path "$OutputDir.zip"))
	{
		Compress-Archive -DestinationPath "$OutputDir.zip" -LiteralPath "$OutputDir"
	}
}

foreach ($ARCH in 'x86', 'x64', 'arm', 'arm64')
{
	$Package = "sqlite-tools-win-$ARCH-$SQLITEVERS"

	if (-not(Test-Path -Path "$Package.msi"))
	{
		$env:SOURCEDIR="$Package"

		& "${env:WIX}bin\candle.exe" -nologo "sqlite-tools-win-$ARCH.wxs"

		if ($LastExitCode -ne 0)
		{
			exit $LastExitCode
		}

		& "${env:WIX}bin\light.exe" -nologo -cultures:null -out "$Package.msi" "sqlite-tools-win-$ARCH.wixobj"

		if ($LastExitCode -ne 0)
		{
			exit $LastExitCode
		}

		$VCVARS = ( '{0}\{1}' -f $VCVARSDIR, $VCVARSARCH[$ARCH] )

		@"
CALL "$VCVARS"
signtool sign /a /sha1 "$CertificateThumbprint" /fd SHA256 /t http://timestamp.digicert.com "$Package.msi"
EXIT %ERRORLEVEL%
"@ | & "$env:COMSPEC"

		If ( $LastExitCode -ne 0 )
		{
			Exit $LastExitCode
		}

	}
}

if (-not(Test-Path -Path "bundle"))
{
	$null = New-Item ./bundle -type Directory

	foreach ($ARCH in 'x86', 'x64' , 'arm', 'arm64')
	{
		$VCVARS = ( '{0}\{1}' -f $VCVARSDIR, $VCVARSARCH[$ARCH] )
		$ZIP = "sqlite-tools-win-$ARCH-$SQLITEVERS"

		$xmlDoc = [System.Xml.XmlDocument](Get-Content "Package.appxmanifest")

		$nsMgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList $xmlDoc.NameTable

		$nsmgr.AddNamespace("man", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")

		$xmlNode = $xmlDoc.SelectSingleNode("/man:Package/man:Identity", $nsmgr)

		$xmlNode.ProcessorArchitecture = $ARCH
		$xmlNode.Version = $env:SQLITEVERS

		$xmlDoc.Save("AppxManifest.xml")

		$MSI = "bundle\sqlite-tools-win-$ARCH-$SQLITEVERS.msix"

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
signtool sign /a /sha1 "$BundleThumbprint" /fd SHA256 /t http://timestamp.digicert.com "$MSI"
EXIT %ERRORLEVEL%
"@ | & "$env:COMSPEC"

		If ( $LastExitCode -ne 0 )
		{
			Exit $LastExitCode
		}
	}
}

$BUNDLE = "sqlite-tools-win-$SQLITEVERS.msixbundle"

If (-not(Test-Path -Path "$BUNDLE"))
{
	@"
CALL "$VCVARSDIR\$VCVARSHOST"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
makeappx bundle /d bundle /p "$BUNDLE"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
signtool sign /a /sha1 "$BundleThumbprint" /fd SHA256 /t http://timestamp.digicert.com "$BUNDLE"
EXIT %ERRORLEVEL%
"@ | & "$env:COMSPEC"

	If ( $LastExitCode -ne 0 )
	{
		Exit $LastExitCode
	}
}

('arm', 'arm64', 'x86', 'x64') | ForEach-Object {
	$ARCH = $_
	$VCVARS = ( '{0}\{1}' -f $VCVARSDIR, $VCVARSARCH[$ARCH] )
	$ARCHDIR = "sqlite-tools-win-$ARCH-$SQLITEVERS"
	$EXE = "$ARCHDIR\sqlite3.exe"

	$MACHINE = ( @"
@CALL "$VCVARS" > NUL:
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
dumpbin /headers $EXE
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
EXIT %ERRORLEVEL%
"@ | & "$env:COMSPEC" /nologo /Q | Select-String -Pattern " machine " )

	$MACHINE = $MACHINE.ToString().Trim()

	$MACHINE = $MACHINE.Substring($MACHINE.LastIndexOf(' ')+1)

	New-Object PSObject -Property @{
			Architecture=$ARCH;
			Executable=$EXE;
			Machine=$MACHINE;
			FileVersion=(Get-Item $EXE).VersionInfo.FileVersion;
			ProductVersion=(Get-Item $EXE).VersionInfo.ProductVersion
	}
} | Format-Table -Property Architecture, Executable, Machine, FileVersion, ProductVersion
