local prettify = require "defcon.util.prettify"
local http_server = require "defnet.http_server"
local utils = require "defcon.util.utils"

local console_html = require "defcon.html.console_html"


local M = {}

M.print = _G.print
M.pprint = _G.pprint

local co

local commands = {}

local modules = {}

local custom_env

local function handle_arg(arg)
	local ok, num = pcall(tonumber, arg)
	--return ok and num or arg:gsub("\"", "")
	return ok and num or arg
end

local function handle_command(command_string, stream)
	-- split the command in it's parts
	-- run it if it's a known command
	-- try to run it as Lua code if it's not a known command
	local command_parts = utils.split(command_string, " ")
	local command = table.remove(command_parts, 1)
	if commands[command] then
		local result
		for k,v in pairs(command_parts) do
			command_parts[k] = handle_arg(v)
		end
		local command_data = commands[command]

		local ok, err = pcall(function()
			result = command_data.fn(command_parts, stream)
		end)

		if not ok then
			result = err
		end

		local result_type = type(result)
		if result_type == "function" or result_type == "nil" then
			return result
		end
		if result_type == "table" and #result < 2 then
			result = result[1]
		end
		return prettify(result)
	-- run it as Lua code
	else
		local result
		local ok, err = pcall(function()
			local fn = loadstring("return " .. command_string) or loadstring(command_string)
			if not fn then
				return "Error: Unable to run " .. command_string
			end
			if custom_env then
				setfenv(fn, custom_env)
			end
			result = { fn() }
		end)

		if not ok then
			result = err
		end
		if type(result) == "table" and #result < 2 then
			result = result[1]
		end
		return prettify(result)
	end

end

local log_streams = {}

local function is_log_started()
	return _G.print ~= M.print
end

local function send_to_streams(s)
	for k,stream in pairs(log_streams) do
		local ok = stream(s)
		if not ok then
			log_streams[k] = nil
		end
	end
end

local function start_log()
	if not is_log_started() then
		_G.print = function(...)
			M.print(...)
			local s = ""
			for k,v in ipairs({...}) do
				s = s .. tostring(v) .. " "
			end
			send_to_streams(s)
		end
		_G.pprint = function(t)
			M.pprint(t)
			send_to_streams(prettify(t))
		end
	end
end

local function stop_log()
	_G.print = M.print
	_G.pprint = M.pprint
	log_streams = {}
end

--- Start the console
-- @param port The port to listen for commands at
function M.start(port)
	port = port or 8098
	M.server = http_server.create(port)

	-- send print logging as chunked html (for direct streaming to a browser)
	M.server.router.get("^/log/start$", function(matches, stream)
		table.insert(log_streams, function(s)
			return stream(M.server.to_chunk(s .. "</br>"))
		end)
		start_log()
		stream(M.server.html())
	end)

	-- handle a console command
	M.server.router.get("^/console/(.*)$", function(matches, stream)
		local command = utils.urldecode(matches[1])
		local response = handle_command(command, stream)
		if type(response) == "string" then
			return M.server.json('{ "response": "' .. utils.urlencode(tostring(response)) .. '" }\r\n')
		else
			return response or ""
		end
	end)

	-- serve the console
	M.server.router.get("^/$", function()
		return M.server.html(console_html)
	end)

	-- download a file
	M.server.router.get("^/download/(.*)$", function(matches)
		local path = matches[1]
		local ok, content_or_err = pcall(function()
			local f = io.open(path, "rb")
			local content = f:read("*a")
			return content
		end)
		if not ok then
			return M.server.html("NOT FOUND", http_server.NOT_FOUND)
		else
			local parts = utils.split(utils.urldecode(path), "/")
			local filename = parts[#parts]
			return M.server.file(content_or_err, filename)
		end
	end)

	M.server.router.unhandled(function()
		return M.server.html("NOT FOUND", http_server.NOT_FOUND)
	end)
	M.server.start()

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
				s = s .. " - " .. command .. "\n"
			end
		end
		return s
	end)

	M.register_command("help", "[command] Show help for a command", function(args)
		local command = args[1]
		if not command then
			return "Please specify a command to show help for"
		end
		return commands[command] and commands[command].description or "Command not found"
	end)

	M.register_command("inspect", "[table] Inspect the field of a registered module, a loaded package or a global value", function(args)
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

		local name = args[1]
		local search = { modules, custom_env or _G, package.loaded, { ["_G"] = _G }}
		for _,t in ipairs(search) do
			local found = find_in_table(t, name)
			if found then
				return prettify(found)
			end
		end
		return "Unable to find " .. name
	end)

	M.register_command("toggle_profiler", "Toggle the on-screen profiler", function()
		msg.post("@system:", "toggle_profile")
		return "OK"
	end)

	M.register_command("toggle_physics_debug", "Toggle physics debug", function()
		msg.post("@system:", "toggle_physics_debug")
		return "OK"
	end)

	M.register_command("start_record", "[filename] Start recording video to specified file", function(args)
		local filename = args[1]
		if not filename then
			return "You must provide a filename"
		end
		msg.post("@system:", "start_record", { file_name = filename, frame_period = 1 } )
	end)

	M.register_command("stop_record", "Stop recording video", function()
		msg.post("@system:", "stop_record")
	end)

	M.register_command("log", "[start|stop] Start/stop receiving client logging", function(args, stream)
		if args[1] == "stop" then
			stop_log()
		else
			if not is_log_started() then
				table.insert(log_streams, function(s)
					return stream(M.server.to_chunk('{ "response": "' .. utils.urlencode(s) .. '" }\r\n'))
				end)
				start_log()
				stream(M.server.json())
				stream(M.server.to_chunk('{ "response": "Log capture started" }\r\n'))
			end
		end
	end)
end

--- Stop the server
function M.stop()
	if M.server then
		M.server.stop()
	end
end


--- Update the server
-- Preferably call this once per frame
function M.update()
	if M.server then
		M.server.update()
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
			M.register_command(name .. "." .. k, "", function(args, fn)
				return { v(unpack(args)) }
			end)
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

--- Set the global environment table used for commands ran as Lua code and inspect.
-- @param env The table to set as environment when running Lua commands.
function M.set_environment(env)
	custom_env = env
end

return M
