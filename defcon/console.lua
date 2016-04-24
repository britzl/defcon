local prettify = require "defcon.util.prettify"
local socket_server = require "defcon.socket.socket_server"
local http_server = require "defcon.socket.http_server"
local utils = require "defcon.util.utils"

local console_html = require "defcon.html.console_html"


local M = {}

local co

local commands = {}

local modules = {}

local server

local function handle_arg(arg)
	local ok, num = pcall(tonumber, arg)
	--return ok and num or arg:gsub("\"", "")
	return ok and num or arg
end



function M.handle_command(command)
	-- split the command in it's parts
	-- get the command and check if it's a know command
	local command_parts = utils.split(command, " ")
	local command = table.remove(command_parts, 1)
	for k,v in pairs(command_parts) do
		command_parts[k] = handle_arg(v)
	end
	local command_data = commands[command]
	if not command_data then
		return "Unknown command"
	end

	-- call command function and handle any error
	-- store command results in a table
	local result
	local ok, err = pcall(function()
		result = { command_data.fn(unpack(command_parts)) }
	end)

	-- if only a single result then return it instead of inside the table
	if result and #result == 1 then
		result = result[1]
	end
	return prettify(result)
end


function M.start()
	print("http_server start")
	server = http_server.create(8098)
	server.router.get("^/console/(.*)$", function(command)
		command = utils.unescape(command)
		local response = M.handle_command(command)
		local jsonresponse = '{ "response": "' .. utils.escape(tostring(response)) .. '" }\r\n'
		return http_server.json(jsonresponse, 200)
	end)
	server.router.get("^/foo/(%d+)$", function(id)
		return http_server.html("foo " .. id, 200)
	end)
	server.router.get("^/$", function()
		return http_server.html(console_html, 200)
	end)
	server.router.unhandled(function()
		return http_server.html("NOT FOUND", 404)
	end)
	server.start()

	-- register a command to list all modules
	M.register_command("modules", "Show all modules", function()
		local s = ""
		for name,_ in pairs(modules) do
			s = s .. name .. "\n"
		end
		return s
	end)

	M.register_command("commands", "Show all commands", function()
		local s = ""
		for command,command_data in pairs(commands) do
			if command:match(".*%..*") ~= command then
				s = s .. command .. " - \"" .. command_data.description .. "\"\n"
			end
		end
		return s
	end)
	

	M.register_command("run", "Run arbitrary Lua code", function(...)
		local s = table.concat({...}, " ")
		print("Running command " .. s)
		local fn = loadstring(s)
		return fn() or "OK"
	end)

	M.register_command("inspect", "Inspect the field of a registered module, a loaded package or a global value", function(name)
		local function find_in_table(t, what)
			if t[what] then
				return t[what]
			end
			for k,v in pairs(t) do
				if what:find(k .. ".") == 1 then
					local rest = what:gsub(k .. ".", "", 1)
					local parts = utils.split(rest, "%.")
					for _,part in ipairs(parts) do
						v = v[part]
					end
					return v
				end
			end
		end

		for _,t in ipairs({ modules, _G, package.loaded }) do
			local found = find_in_table(t, name)
			if found then
				return prettify(found)
			end
		end
	end)
	
end

function M.stop()
	if server then
		server.stop()
	end
end


function M.update()
	if server then
		server.update()
	end
end

--- Register a console command
-- @param command
-- @param description
-- @param fn The function to execute
function M.register_command(command, description, fn)
	assert(command, "You must provide a command")
	assert(description, "You must provide a command description")
	assert(fn, "You must provide a command function")
	commands[command] = { fn = fn, description = description }
end


--- Register a module. All functions on the module will be exposed to
-- the console
-- @param module
-- @param name Optional name to use for the module. If none is provided
-- the function will try to find the module in package.loaded and use
-- the module filename as name
function M.register_module(module, name)
	assert(module, "You must provide a module")

	-- if no name is provided then try to get it from the
	-- loaded packages
	if not name then
		for k,v in pairs(package.loaded) do
			if v == module then
				local parts = utils.split(k, "%.")
				name = parts[#parts]
				break
			end
		end
	end
	assert(name, "You must provide a name since the module wasn't found among the loaded packages")

	-- add all the functions of the module as commands
	modules[name] = module
	for k,v in pairs(module) do
		if type(v) == "function" then
			M.register_command(name .. "." .. k, "", v)
		end
	end

	-- add a command to list all the commands of the module
	M.register_command(name, ("Show the available commands of the %s module"):format(name), function()
		local s = ""
		for command,_ in pairs(commands) do
			if command:match(name .. "%..*") == command then
				s = s .. command .. "\n"
			end
		end
		return s
	end)
end

return M
