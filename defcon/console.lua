local prettify = require "defcon.util.prettify"
local http_server = require "defnet.http_server"
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

local function handle_command(command_string)
	-- split the command in it's parts
	-- run it if it's a known command
	-- try to run it as Lua code if it's not a known command
	local command_parts = utils.split(command_string, " ")
	local command = table.remove(command_parts, 1)
	local result
	if commands[command] then
		for k,v in pairs(command_parts) do
			command_parts[k] = handle_arg(v)
		end
		local command_data = commands[command]

		-- call command function and handle any error
		-- store command results in a table
		local ok, err = pcall(function()
			result = { command_data.fn(unpack(command_parts)) }
		end)
		
		if not ok then
			result = { err }
		end
	-- run it as Lua code
	else
		local ok, err = pcall(function()
			local fn = loadstring("return " .. command_string) or loadstring(command_string)
			if not fn then
				return "Error: Unable to run " .. command_string
			end
			result = { fn() }
		end)
		
		if not ok then
			result = { err }
		end
	end

	-- if only a single or no result then return it instead of inside the table
	if result and #result < 2 then
		result = result[1]
	end
	return prettify(result)
end


--- Start the console
-- @param port The port to listen for commands at
function M.start(port)
	port = port or 8098
	server = http_server.create(port)
	server.router.get("^/console/(.*)$", function(command)
		command = utils.urldecode(command)
		local response = handle_command(command)
		local jsonresponse = '{ "response": "' .. utils.urlencode(tostring(response)) .. '" }\r\n'
		return http_server.json(jsonresponse)
	end)
	server.router.get("^/$", function()
		return http_server.html(console_html)
	end)
	server.router.get("^/download/(.*)$", function(path)
		local parts = utils.split(utils.urldecode(path), "/")
		local filename = parts[#parts]
		local ok, content_or_err = pcall(function()
			local f = io.open(filename, "rb")
			local content = f:read("*a")
			return content
		end)
		if not ok then
			return http_server.html("NOT FOUND", "404 NOT FOUND")
		else
			return http_server.file(content_or_err, filename)
		end
	end)
	server.router.unhandled(function()
		return http_server.html("NOT FOUND", "404 NOT FOUND")
	end)
	server.start()

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

	M.register_command("toggle_profiler", "Toggle the on-screen profiler", function()
		msg.post("@system:", "toggle_profile")
		return "OK"
	end)
	
	M.register_command("toggle_physics_debug", "Toggle physics debug", function()
		msg.post("@system:", "toggle_physics_debug")
		return "OK"
	end)
	
	M.register_command("start_record", "Start recording video to specified file", function(filename)
		msg.post("@system:", "start_record", { file_name = filename, frame_period = 1 } )
	end)
	
	M.register_command("stop_record", "Stop recording video", function()
		msg.post("@system:", "stop_record")
	end)
end

--- Stop the server
function M.stop()
	if server then
		server.stop()
	end
end


--- Update the server
-- Preferably call this once per frame
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
