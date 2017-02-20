--- Helper functions and utilities

local M = {}

--- Split a string containing a delimiter into the strings between the delimiter
-- from http://lua-users.org/wiki/SplitJoin
-- @param s The string to split
-- @param delimiter The delimiter to use. Note that if the delimiter contains a
-- special pattern matching character such as '.' it has to be escaped: '%.'. If
-- the delimiter is an empty string the result will be a split per character in
-- the string.
-- @return The split string
function M.split(s, delimiter)	
	assert(s, "You must provide a string to split")
	assert(delimiter, "You must provide a delimiter")
	-- Eliminate bad cases...
	if string.find(s, delimiter) == nil then
		return { s }
	end
	local result = {}
	if delimiter == "" then
		for char in string.gmatch(s, ".") do
			table.insert(result, char)
		end
	else
		local last_pos
		local pattern = "(.-)" .. delimiter .. "()"
		for part, pos in string.gmatch(s, pattern) do
			table.insert(result, part)
			last_pos = pos
		end
		if not last_pos then
			table.insert(result, s)
		else
			table.insert(result, string.sub(s, last_pos))
		end
	end
	return result
end

--- Convert a hex value to a character
-- @param x The hex value
-- @return The character
function M.hex_to_char(x)
	return string.char(tonumber(x, 16))
end

--- Converts a character to an hexadecimal code in the form %XX
-- @param c
-- @return
function M.char_to_hex(c)
	return string.format("%%%02X", string.byte(c))
end

--- Decode an URL-encoded string (see RFC 2396)
-- From: https://github.com/keplerproject/cgilua/blob/master/src/cgilua/urlcode.lua
-- @param s URL encoded string
-- @return Unescaped string
function M.urldecode(s)
	s = string.gsub(s, "+", " ")
	s = string.gsub(s, "%%(%x%x)", M.hex_to_char)
	s = string.gsub(s, "\r\n", "\n")
	return s
end

--- URL-encode a string (see RFC 2396)
-- From: https://github.com/keplerproject/cgilua/blob/master/src/cgilua/urlcode.lua
-- Modified so that underscore is left as-is (which is ok)
-- @param s String to URL encode
-- @return Escaped string
function M.urlencode(s, escape_pattern)
	escape_pattern = escape_pattern or "([^0-9a-zA-Z ])"
	s = string.gsub(s, "\n", "\r\n")
	s = string.gsub(s, escape_pattern, M.char_to_hex) -- locale independent
	s = string.gsub(s, " ", "+")
	return s
end

return M
