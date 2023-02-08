
local setmetatable <const> = setmetatable

local HtmlElement <const> = {}
HtmlElement.__index = HtmlElement
_ENV = HtmlElement

function HtmlElement:print(literal)
	return self.opening .. literal .. self.closing
end

function HtmlElement:new(char)
	return setmetatable({opening = "<" .. char .. ">",closing = "</" .. char ..">"},self)
end

return HtmlElement
