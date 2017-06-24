local M = {}


local command = nil

local command_cb = nil

local breakpoints = {}

local info = {}


function M.start(breakcb)
	debug.sethook(function(event, line)
		info = debug.getinfo(2)
		if breakpoints[info.short_src] and breakpoints[info.short_src][info.currentline] then
			command = "break"
		end
		
		if not command then
			return
		end
		
		if command == "break" then
			if command_cb then
				command_cb(info)
			end
			local next_update = socket.gettime()
			while command == "break" do
				local now = socket.gettime()
				if now > next_update then
					breakcb()
					next_update = now + 0.016
				end
			end
		elseif command == "step" then
			command = "break"
		elseif command == "run" then
			command = nil
		end
	end, "l")
end


function M.stop()
	debug.sethook()
end


function M.step(cb)
	command = "step"
	command_cb = cb
end


function M.breaknow(cb)
	command = "break"
	command_cb = cb
end


function M.info()
	return info
end


function M.add_breakpoint(file, line, cb)
	breakpoints[file] = breakpoints[file] or {}
	breakpoints[file][line] = true
	command_cb = cb
end

function M.remove_breakpoint(file, line)
	breakpoints[file] = breakpoints[file] or {}
	breakpoints[file][line] = nil
end

function M.list_breakpoints()
	return breakpoints
end

function M.run()
	command = "run"
end



return M