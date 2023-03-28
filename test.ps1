#
#  Copyright 2022, Roger Brown
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

trap
{
	throw $PSItem
}

$Found = $False

foreach ($App in "${Env:ProgramFiles(x86)}\SQLite Tools\sqlite3.exe", "${Env:ProgramFiles}\SQLite Tools\sqlite3.exe") {
	if (Test-Path -Path "$App") {
		@"
CREATE TABLE MESSAGES (
	CONTENT VARCHAR(256)
);

INSERT INTO MESSAGES (CONTENT) VALUES ('Hello World');

SELECT * FROM MESSAGES;
"@ | & "$App"

		if ($LastExitCode -ne 0)
		{
			exit $LastExitCode
		}

		$Found = $true
	}
}

if (-not($Found))
{
	throw "sqlite3.exe not found"
}
