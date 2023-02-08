local setmetatable <const> = setmetatable

local AttrElement <const> = {}
AttrElement.__index = AttrElement
_ENV = AttrElement

function AttrElement:print(attr,inner)
	return self.opening .. attr .. '" >' .. inner .. self.closing
end

function AttrElement:new(char)
	return setmetatable({opening = "<" .. char.." ",closing = "</" .. char ..">"},self)
end

return AttrElement
