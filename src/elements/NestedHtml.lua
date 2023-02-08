local HtmlElement <const> = require('elements.HtmlElement')

local setmetatable <const> = setmetatable

local Nested <const> = {}
Nested.__index = Nested
setmetatable(Nested,HtmlElement)

_ENV = Nested

function Nested:new(outer,inner)
	return setmetatable({opening = "<" .. outer .. "><" .. inner ..">",closing = "</" .. inner .. "></" ..outer .. ">"},self)
end

return Nested
