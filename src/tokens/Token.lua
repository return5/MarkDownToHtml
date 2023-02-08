

local Token <const> = {}
Token.__index = Token
_ENV = Token

function Token:print(htmlElement,literal)
	return htmlElement:print(literal)
end

function Token:new(literal,htmlElement)
	return self:print(htmlElement,literal)
end

return Token
