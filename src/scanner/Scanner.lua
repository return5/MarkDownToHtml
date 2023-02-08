local HtmlElement <const> = require('elements.HtmlElement')
local SelfClosingHtml <const> = require('elements.SelfClosingHtml')
local Token <const> = require('tokens.Token')
local NestedHtml <const> = require('elements.NestedHtml')
local AttrToken <const> = require('tokens.AttrToken')
local AttrElement <const> = require('elements.AttrElement')

local rep <const> = string.rep
local concat <const> = table.concat
local match <const> = string.match

local io = io

local Scanner <const> = {}
Scanner.__index = Scanner

_ENV = Scanner

--list of html tags.
local htmlElements <const> = {
	LineBreak = SelfClosingHtml:new("br"),
	Paragraph = HtmlElement:new("p"),
	Bold = HtmlElement:new("b"),
	Strike = HtmlElement:new("s"),
	Code = HtmlElement:new("code"),
	Pre = HtmlElement:new("pre"),
	CodeBlock = NestedHtml:new("pre","code"),
	Img = SelfClosingHtml:new("img"),
	Url = AttrElement:new("a"),
	OrderList = HtmlElement:new("ol"),
	ListItem = HtmlElement:new("li"),
	UnorderedList = HtmlElement:new("ul"),
	Horizontal = SelfClosingHtml:new("hr"),
	Blockquote = NestedHtml:new("blockquote","span"),
	Italic = HtmlElement:new("i"),
	Mark = HtmlElement:new("mark"),
	Table = HtmlElement:new("table"),
	Row = HtmlElement:new("tr"),
	Cell = HtmlElement:new("td"),
	Tableheader = HtmlElement:new("th")
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

function Scanner:newLine()
	self:incrI()
end

--list of spaces characters.
local skipSpaceTbl <const> = {
	[" "] = true,
	['\t'] = true,
	['\r'] = true
}

function Scanner:skipSpaces()
	while skipSpaceTbl[self:current()] do
		self:incrI()
	end
end

local function handleBackSlash(self,char)
	return char == "\\" and backSlashTbl[self:peek(1)]
end

local function tblToStr(tbl)
	return concat(tbl)
end

--given a start and ending index, convert the chars form file into a string.
local function tblIJToStr(self,i,j)
	self:rewind(self.i - i)
	local str <const> = {}
	for k=i,j,1 do
		str[#str + 1] = self:advance()
	end
	return tblToStr(str)
end

local headersTbl <const> = {
	HtmlElement:new('h1'),
	HtmlElement:new('h2'),
	HtmlElement:new('h3'),
	HtmlElement:new('h4'),
	HtmlElement:new('h5'),
	HtmlElement:new('h6'),
}

function Scanner:countChar(char)
	local count = 0
	while not self:isAtEnd() and self:current() == char do
		count = count + 1
		self:incrI()
	end
	return count
end

function Scanner:previous(i)
	local results <const> = self.i - i
	if results < 1 then
		return self.file[1]
	end
	return self.file[results]
end

function Scanner:peek(i)
	local results <const> = self.i + i
	if results > #self.file then
		return self.file[#self.file]
	end
	return self.file[results]
end

function Scanner:checkForLineBreak()
	return #self.file - self.i > 2 and skipSpaceTbl[self:current()] and skipSpaceTbl[self:peek(1)] and self:peek(2) == "\n"
end

local endTbl <const> = {
	["\0"] = true,
	["\n"] = true
}

function Scanner:setI(val)
	self.i = val
end

function Scanner:rewind(val)
	self.i = self.i - val
end

--grab a string of characters stopping at char or at end of file or a newline character
local function grabString(self,char)
	local str <const> = {}
	while self:current() ~= char do
		--if we reach newline or end of file then we return the string. returning false to indicate we didnt find the char.
		if self:isAtEnd() or self:current() == "\n" then
			return tblToStr(str),false
		end
		str[#str + 1] = self:advance()
	end
	return tblToStr(str),true
end

--scan for image and url tags.
local function scanImgAndUrl(self)
	local start <const> = self.i --the start of the string we are currently scanning.
	local inner,cont <const> = grabString(self,"]")
	--if we didnt find a closing ] or the next char isnt a (
	if not cont or self:peek(1) ~= "(" then
		self:setI(start) --go back to the character right after the opening [
		return inner
	end
	self:incrI() -- skip over the ]
	self:incrI() -- skip over the (
	local src,completed <const> = grabString(self,")")
	--if we failed to find a closing )
	if not completed then
		self:setI(start) --go back to the character right after the opening [
		return "["
	end
	return src,completed,inner
end

local function createImgTag(inner,src)
	return Token:new('alt = "' .. inner .. '" src = "' .. src ..'"',htmlElements.Img)
end

local function createUrlTag(inner,src)
	return AttrToken:new('href="' .. src,inner,htmlElements.Url)
end

local function findImgOrUrl(self,chars,tokenFunc)
	self:incrI() -- skip over the [
	local src,cont,inner <const> = scanImgAndUrl(self)
	--if we dint find a closing ] then it failed
	if not cont then
		--if it wasnt a proper tag then we return the two skipped over chars
		return chars
	end
	--success, so return an <img> tag
	return tokenFunc(inner,src)
end

function Scanner:exclamation()
	self:incrI() -- skip over the !
	if self:current(1) == "[" then
		return findImgOrUrl(self,"![",createImgTag)
	end
	--if we dont have a following [ then just return the !
	return "!"
end

function Scanner:squareBracket()
	return findImgOrUrl(self,"[",createUrlTag)
end

local function countEndingChars(self,count1,char,str,html,alt)
	--count number of chars which end the tag
	local count2 <const> = self:countChar(char)
	self:rewind(1)
	if count2 == 0 then
		return rep(char,count1) .. tblToStr(str)
	end
	--if we start or end with only a single chars then we use alt html tag
	if count1 == 1 or count2 == 1 then
		html = alt or html
	end
	if count1 > count2 then
		return rep(char,count1 - count2) .. Token:new(tblToStr(str),html)
	end
	return Token:new(tblToStr(str),html) .. rep(char,count2 - count1)
end

local midleMidleTbl <const> = {
	['!'] = Scanner.exclamation,
	['['] = Scanner.squareBracket
}

local function handleMiddleChar(self,char,html,cond,alt)
	--count number of chars which start the tag
	local count1 <const> = self:countChar(char)
	self:skipSpaces()
	local str <const> = {}
	while cond(self,char) do
		local char1 <const> = self:current()
		if midleMidleTbl[char1] then
			str[#str + 1] = midleMidleTbl[char1](self)
			self:incrI()
		elseif handleBackSlash(self,char1) then
			self:incrI()
			str[#str + 1] = self:advance()
		else
			str[#str + 1] = self:advance()
		end
	end
	return countEndingChars(self,count1,char,str,html,alt)
end

local function checkMiddleCond(self,char)
	local current <const> = self:current()
	return not endTbl[current] and current ~= char
end

local function checkMiddleCondBlock(self,char)
	if self:isAtEnd() then
		return false
	end
	--if we reach a newline followed by the char we want to match
	if self:current() == "\n" and self:peek(1) == char then
		self:incrI()
		return false
	end
	return true
end

function Scanner:tilde()
	return handleMiddleChar(self,"~",htmlElements.Strike,checkMiddleCond)
end

function Scanner:asterisk()
	return handleMiddleChar(self,"*",htmlElements.Bold,checkMiddleCond,htmlElements.Italic)
end

function Scanner:backTick()
	return handleMiddleChar(self,"`",htmlElements.CodeBlock,checkMiddleCondBlock)
end

function Scanner:equals()
	return handleMiddleChar(self,"=",htmlElements.Mark,checkMiddleCond)
end

--if we have two spaced followed by a "\n" character.
function Scanner:makeLineBreak()
	self:incrI() --skip first space
	self:incrI() --skip second space
	return htmlElements.LineBreak:print()
end

local function handleSpaces(self)
	while skipSpaceTbl[self:peek(1)] do
		if self:checkForLineBreak() then
			return self:makeLineBreak()
		end
		self:incrI()
	end
	return self:current()
end

local function checkEndOfParagraph(self)
	local char <const> = self:current()
	local prev <const> = self:previous(1)
	return self:isAtEnd() or (self.charTbl[char] and prev == "\n") or (char == prev == "\n")
end

local function getStringBlock(self,condFunc)
	local str <const> = {}
	while not condFunc(self) do
		local char <const> = self:current()
		if skipSpaceTbl[char] then
			str[#str + 1] = handleSpaces(self)
		elseif handleBackSlash(self,char) then
			self:incrI()
			str[#str + 1] = self:current()
		elseif self.middleChars[char] then
			str[#str + 1] = self.middleChars[char](self)
		elseif char ~= "\n" then
			str[#str + 1] = char
		else
			str[#str + 1] = " "
		end
		self:incrI()
	end
	return tblToStr(str)
end

function Scanner:paragraph()
	return Token:new(getStringBlock(self,checkEndOfParagraph),htmlElements.Paragraph)
end

local function checkBlockQuote(self)
	return self:isAtEnd() or self:current() == "\n"
end

local function countBlockQuoteLevels(self)
	local level = 0
	while self:current() == ">" do
		level = level + 1
		self:incrI()
	end
	return level
end

local function blockQuotes(self,level)
	local str <const> = {}
	while not self:isAtEnd() and self:current() == ">" do
		local diff <const> = countBlockQuoteLevels(self)
		self:skipSpaces()
		if diff > level then
			self:rewind(diff)
			str[#str + 1] = blockQuotes(self,diff)
		elseif diff < level then
			self:rewind(diff)
			break
		elseif self:current() == "\n" then
			self:incrI()
		else
			str[#str + 1] = getStringBlock(self,checkBlockQuote)
			if self:current() == "\n" then
				str[#str + 1] = Token:new("",htmlElements.LineBreak)
				self:incrI()
			end
		end
	end
	return Token:new(tblToStr(str),htmlElements.Blockquote)
end

--handle block quotes
function Scanner:block()
	local level <const> = countBlockQuoteLevels(self)
	self:rewind(level)
	return blockQuotes(self,level)
end

function Scanner:literal()
	local str <const> = {}
	while not endTbl[self:current()] do
		local char <const> = self:current()
		while skipSpaceTbl[char] and skipSpaceTbl[self:peek(1)] do
			self:incrI()
		end
		str[#str + 1] = self:advance()
	end
	return str
end

local function handleListItem(self)
	local str <const> = {}
	while self:current() ~= "\0" and self:current() ~= "\n" do
		local char <const> = self:current()
		if handleBackSlash(self,char) then
			self:incrI()
			str[#str + 1] = self:current()
		elseif self.middleChars[char] then
			str[#str + 1] = self.middleChars[char](self)
		else
			str[#str + 1] = char
		end
		self:incrI()
	end
	return Token:new(tblToStr(str),htmlElements.ListItem)
end

--check if line matches a item inside of a list.
local function itemListCond(self,func)
	local startI <const> = self.i
	self:skipSpaces()
	local level <const> = self.i - startI
	local cont,element,offset <const> = func(self)
	return cont,element,offset,level
end

function Scanner:makeList(condFunc,level,listElement)
	local str <const> = {}
	local cont,newElement,offset,diff = itemListCond(self,condFunc)
	while cont do
		-- if we encounter a new level of increased tabbing
		if diff > level then
			self:rewind(offset + diff) --rewind back to the beginning of the line
			str[#str + 1] = self:makeList(condFunc,diff,newElement)
		elseif diff < level then  --if we encounter a new level of decreasing tabbing
			self:rewind(offset + diff)  --rewind back to the beginning of the line.
			break
		else
			str[#str + 1] = handleListItem(self)
		end
		if self:current() == "\n" then
			self:incrI()  --skip over the \n character
		end
		cont,newElement,offset,diff = itemListCond(self,condFunc)
	end
	return Token:new(tblToStr(str),listElement)
end

function Scanner:addToken(token)
	self.htmlArray[#self.htmlArray + 1] = token
end

local digits <const> = {
	["1"] = true,
	["2"] = true,
	["3"] = true,
	["4"] = true,
	["5"] = true,
	["6"] = true,
	["7"] = true,
	["8"] = true,
	["9"] = true
}

--check if line matches an ordered list
local function checkIfOrderList(self)
	if digits[self:current()] and self:peek(1) == "." and skipSpaceTbl[self:peek(2)] then
		self:incrI() -- skip over digit
		self:incrI() -- skip over the .
		self:skipSpaces() -- skip all space characters
		return true,htmlElements.OrderList,3
	end
	return false
end

--check to see if the line matches an unorders list item.
local function checkIfUnOrderList(self)
	if self:current() == "-" and skipSpaceTbl[self:peek(1)] then
		self:incrI() --skip over the -
		self:skipSpaces()  --skip over space characters
		return true,htmlElements.UnorderedList,2
	end
	return false
end

--check if line matches either an ordered or unordered list
local function checkIfList(self)
	local cont,element,offset = checkIfOrderList(self)
	if cont then return cont,element,offset end
	cont,element,offset = checkIfUnOrderList(self)
	if cont then return cont,element,offset end
	return false
end

function Scanner:digit()
	if self:peek(1) == "." and skipSpaceTbl[self:peek(2)] then
		return self:makeList(checkIfList,0,htmlElements.OrderList)
	end
	return self:paragraph()
end

function Scanner:hyphen()
	if self:peek(1) == "-" and self:peek(2) == "-" then
		self:countChar("-")
		return Token:new("",htmlElements.Horizontal)
	end
	if skipSpaceTbl[self:peek(1)] then
		return self:makeList(checkIfList,0,htmlElements.UnorderedList)
	end
	io.write("making paragraph\n")
	return self:paragraph()
end

local tableColumnTbl <const> = {
	["\0"] = true,
	["\n"] = true,
	["|"] = true
}

local function tableColumn(self)
	return tableColumnTbl[self:current()]
end

local function handleTableRow(self)
	local str <const> = {}
	while not self:isAtEnd() and self:current() ~= "\n" do
		str[#str + 1] = getStringBlock(self,tableColumn)
		if self:current() == "|" then
			self:incrI()
		end
	end
	return str
end

--go through the table to find the row which defined the headers of the table. return that index
local function handleTableHeader(str)
	local row = -1
	for i=1,#str,1 do
		for j=1,#str[i],1 do
			if not match(str[i][j],"%s*%-+%s*") then
				row = -1
				break
			end
			row = i
		end
		if row ~= -1 then return row end
	end
	return row
end

local function generateTable(str,headerRow)
	local tbl <const> = {}
	local headers <const> = {}
	--grab the headers and make them header tags.
	for i=1,#str[headerRow],1 do
		headers[#headers + 1] = Token:new(str[headerRow][i],htmlElements.Tableheader)
	end
	--wrap the headers inside a row tag
	tbl[#tbl + 1] = Token:new(tblToStr(headers),htmlElements.Row)
	--grab all the rows before the headers row, if any, and wrap them in row tags
	for i=1,headerRow - 1,1 do
		local row <const> = {}
		for j=1,#str[i],1 do
			row[#row + 1] = Token:new(str[i][j],htmlElements.Cell)
		end
		tbl[#tbl + 1] = Token:new(tblToStr(row),htmlElements.Row)
	end
	--grab all the rows after the headers row, if any, and wrap them in tags
	for i=headerRow + 2,#str,1 do
		local row <const> = {}
		for j=1,#str[i],1 do
			row[#row + 1] = Token:new(str[i][j],htmlElements.Cell)
		end
		tbl[#tbl + 1] = Token:new(tblToStr(row),htmlElements.Row)
	end
	return Token:new(tblToStr(tbl),htmlElements.Table)
end

function Scanner:pipe()
	local startI = self.i
	local str <const> = {}
	while not self:isAtEnd() and self:current() == "|" do
		self:incrI()
		str[#str + 1] = handleTableRow(self)
		if not self:isAtEnd() then
			self:incrI()
		end
	end
	--if we dont find a closing | for the table we treat the entire thing as a paragraph.
	if self:previous(1) ~= "|" and self:previous(2) ~= "|" then
		local stop <const> = self.i - 1
		return Token:new(tblIJToStr(self,startI,stop),htmlElements.Paragraph)
	end
	local headerRow <const> = handleTableHeader(str)
	return generateTable(str,headerRow - 1)
end

function Scanner:header()
	local count <const> = self:countChar("#")
	if count > 0 and count < 7 and skipSpaceTbl[self:current()] then
		self:skipSpaces()
		return Token:new(tblToStr(self:literal()),headersTbl[count])
	else
		return self:paragraph()
	end
end

function Scanner:advance()
	local char <const> = self:current()
	self:incrI()
	return char
end

function Scanner:current()
	return self.file[self.i]
end

function Scanner:incrI()
	self.i = self.i + 1
end

function Scanner:isAtEnd()
	return self:current() == "\0"
end

function Scanner:isMatch(expected)
	if self:isAtEnd() then
		self.cont = false
		return false
	end
	return self:current() == expected
end

function Scanner:scanChar()
	local char <const> = self:current()
	local func <const> = self.charTbl[char] or Scanner.paragraph
	self:addToken(func(self))
end

function Scanner:endScan()
	self.cont = false
end

--list of characters which represent tokens but have to be the start on their own line.
Scanner.charTbl = {
	['#'] = Scanner.header,
	['|'] = Scanner.pipe,
	['-'] = Scanner.hyphen,
	[' '] = Scanner.skipSpaces,
	["\0"] = Scanner.endScan,
	["\n"] = Scanner.newLine,
	["\r"] = Scanner.skipSpaces,
	["\t"] = Scanner.skipSpaces,
	["1"] = Scanner.digit,
	["2"] = Scanner.digit,
	["3"] = Scanner.digit,
	["4"] = Scanner.digit,
	["5"] = Scanner.digit,
	["6"] = Scanner.digit,
	["7"] = Scanner.digit,
	["8"] = Scanner.digit,
	["9"] = Scanner.digit,
	[">"] = Scanner.block
}

Scanner.middleChars = {
	['`'] = Scanner.backTick,
	['~'] = Scanner.tilde,
	['*'] = Scanner.asterisk,
	['!'] = Scanner.exclamation,
	['['] = Scanner.squareBracket,
	['='] = Scanner.equals
}

function Scanner:scanTokens(file)
	self.htmlArray = {
		"<!DOCTYPE html>","<html lang=\"en-US\">","<head><style>",
		"body {background-color: #1b1b1b; color: #e6e6e6}","pre {background-color: #999999; color: #0d0d0d;}",
		"td,th {border: 1px solid rgb(190, 190, 190);padding: 10px;}","td {text-align: center;}",
		"tr:nth-child(even) {background-color: #42494d;}", "th {background-color: #274d5f;}",
		"table {border-collapse: collapse;border: 2px solid rgb(200, 200, 200);letter-spacing: 1px;font-family: sans-serif;font-size: 0.8rem;}",
		"blockquote span {background-color: #909497; color: #000000;}","a {color: #0C85F6;}","</style></head><body>"
	}

	self.file = file
	self.i = 1
	self.cont = true
	while not self:isAtEnd() and self.cont do
		self:scanChar()
	end
	self.htmlArray[#self.htmlArray + 1] = "</body>"
	self.htmlArray[#self.htmlArray + 1] = "</html>"
	return self.htmlArray
end

return Scanner
