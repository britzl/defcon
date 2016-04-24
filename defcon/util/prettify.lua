--- Module to prettify/format structured data in a way that makes it easier to
-- read for a human.
-- The module can currently prettify Lua tables.
-- @usage
-- require "prettify"
-- local foo = { some = "data" }
-- print(prettify(foo))

local M = {}

M.indentation = "  "

--- Prettify a table
-- @param data
-- @return Prettified table
function M.prettify_table(data)
	local encountered_tables = {}
	local indentation = M.indentation
	local current_indentation = ""
	local result = ""

	local function indent_more()
		current_indentation = current_indentation .. indentation
	end

	local function indent_less()
		current_indentation = current_indentation:sub(1, #current_indentation - #indentation)
	end

	local function add_line(line)
		result = result .. current_indentation .. line .. "\n"
	end

	local function format_table(value)
		add_line("{")
		indent_more()
		for name,data in pairs(value) do
			if type(name) == "string" then
				name = '"'..name..'"'
			else
				name = tostring(name)
			end
			local dt = type(data)
			if dt == "table" then
				if not encountered_tables[data] then
					encountered_tables[data] = true
					add_line(name .. " = [".. tostring(data) .. "]")
					format_table(data)
				else
					add_line(name .. " = [".. tostring(data) .. "] (Circular reference)")
				end
			elseif dt == "string" then
				add_line(name .. ' = "' .. tostring(data) .. '"')
			else
				add_line(name .. " = " .. tostring(data))
			end
		end
		indent_less()
		add_line("}")
	end

	if type(data) == "table" then
		format_table(data)
	else
		result = tostring(data)
	end
	return result
end


return setmetatable(M, {
	__call = function(self, ...)
		return M.prettify_table(...)
	end,
})
