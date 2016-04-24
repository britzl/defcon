--- Utility functions for working with strings

local M = {}





--- Left pad string if it's less than the expected length
-- @param s The string to pad
-- @param expected_length The expected length of the string
-- @param padding Optional character to pad with, defaults to space
-- @return The padded string
function M.pad_left(s, expected_length, padding)
	assert(s, "You must provide a string to pad")
	assert(expected_length and expected_length > 0, "You must provide an expected length greater than 0")
	assert(not padding or #padding == 1, "You must provide a single character padding or none at all")
	padding = padding or " "
	local actual_length = #s
	if actual_length < expected_length then
		s = string.rep(padding, expected_length - actual_length) .. s
	end
	return s
end

--- Right pad string if it's less than the expected length
-- @param s The string to pad
-- @param expected_length The expected length of the string
-- @param padding Optional character to pad with, defaults to space
-- @return The padded string
function M.pad_right(s, expected_length, padding)
	assert(s, "You must provide a string to pad")
	assert(expected_length and expected_length > 0, "You must provide an expected length greater than 0")
	assert(not padding or #padding == 1, "You must provide a single character padding or none at all")
	padding = padding or " "
	local actual_length = #s
	if actual_length < expected_length then
		s = s .. string.rep(padding, expected_length - actual_length)
	end
	return s
end

--- Truncate string from the beginning if it's above a certain length
-- @param s The string to truncate
-- @param max_length
-- @return The truncated string
function M.truncate_beginning(s, max_length)
	assert(s, "You must provide a string to truncate")
	assert(max_length and max_length > 0, "You must provide a max length greater than 0")
	local actual_length = #s
	if actual_length > max_length then
		s = s:sub(1 + actual_length - max_length)
	end
	return s
end

--- Truncate string from the end if it's above a certain length
-- @param s The string to truncate
-- @param max_length
-- @return The truncated string
function M.truncate_end(s, max_length)
	assert(s, "You must provide a string to truncate")
	assert(max_length and max_length > 0, "You must provide a max length greater than 0")
	local actual_length = #s
	if actual_length > max_length then
		s = s:sub(1, max_length)
	end
	return s
end


return M