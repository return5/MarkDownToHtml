local Token <const> = require('tokens.Token')

local setmetatable <const> = setmetatable

local AttrToken <const> = {}
AttrToken.__index = AttrToken
setmetatable(AttrToken,Token)
_ENV = AttrToken

function AttrToken:new(attr,inner,htmlElement)
	return htmlElement:print(attr,inner)
end

return AttrToken
