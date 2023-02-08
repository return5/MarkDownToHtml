
local HtmlElement <const> = require('elements.HtmlElement')
local SelfClosingHtml <const> = require('elements.SelfClosingHtml')
local Token <const> = require('tokens.Token')
local Utils <const> = require('auxiliary.Utils')
local StringLib <const> = require('auxiliary.StringLib')

local concat <const> = table.concat
local Parser <const> = {}
Parser.__index = Parser

_ENV = Parser

--list of html tags.
local htmlElements <const> = {
	LineBreak = SelfClosingHtml:new("br"),
	Paragraph = HtmlElement:new("p"),
	Bold = HtmlElement:new("b")
}

--list of characters which can be escaped by a backslash character.
local backSlashTbl <const> = {
	["\\"] = "\\",
	["`"] = "`",
	["*"] = "*",
	["_"] = "_",
	["{"] = "{",
	["}"] = "}",
	["["] = "[",
	["]"] = "]",
	["<"] = "<",
	[">"] = ">",
	["("] = "(",
	[")"] = ")",
	["#"] = "#",
	["+"] = "+",
	["-"] = "-",
	["."] = ".",
	["!"] = "!",
	["|"] = "|",
}

--list of spaces characters.
local skipSpaceTbl <const> = {
	[" "] = true,
	['\t'] = true,
	['\r'] = true
}

local headersTbl <const> = {
	HtmlElement:new('h1'),
	HtmlElement:new('h2'),
	HtmlElement:new('h3'),
	HtmlElement:new('h4'),
	HtmlElement:new('h5'),
	HtmlElement:new('h6'),
}


return Parser