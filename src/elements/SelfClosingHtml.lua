local HtmlElement <const> = require('elements.HtmlElement')
local setmetatable <const> = setmetatable

local SelfClosing <const> = {}
SelfClosing.__index = SelfClosing
setmetatable(SelfClosing,HtmlElement)

function SelfClosing:print(literal)
	local lit <const> = literal or ""
	return self.opening .. lit .. self.closing
end

function SelfClosing:new(char)
	return setmetatable({opening = "<" .. char .. " ",closing = " >"},self)
end

return SelfClosing
