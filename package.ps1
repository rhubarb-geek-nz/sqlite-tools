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

$Package = "sqlite-tools-win32-x86-3390400"

$env:SQLITEVERS="3.39.04.00"

trap
{
	throw $PSItem
}

if (-not(Test-Path -Path "${Package}"))
{
	if (-not(Test-Path -Path "${Package}.zip"))
	{
		Invoke-WebRequest -Uri "https://www.sqlite.org/2022/${Package}.zip" -OutFile "${Package}.zip"
	}

	Expand-Archive -Path "${Package}.zip" -DestinationPath .
}

& "${env:WIX}bin\candle.exe" -nologo "sqlite-tools.wxs"

if ($LastExitCode -ne 0)
{
	exit $LastExitCode
}

& "${env:WIX}bin\light.exe" -nologo -cultures:null -out "${Package}.msi" "sqlite-tools.wixobj"

if ($LastExitCode -ne 0)
{
	exit $LastExitCode
}
