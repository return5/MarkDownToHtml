
--[[
    Copyright (C) <2023>  <return5>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]


local ReadFile <const> = require('auxiliary.ReadFile')
local Scanner <const> = require('scanner.Scanner')

local function main()
	if #arg == 0 then
		io.write("error, please include file.\n")
		os.exit()
	end
	local file <const> = ReadFile:new(arg[1],".",true)
	local htmlArray <const> = Scanner:scanTokens(file)
	local f <const> = io.open(arg[2] or "output.md","w")
	for i=1,#htmlArray,1 do
		f:write(htmlArray[i])
	end
	f:close()
end

main()
