local M = {}


local command = nil

local breakpoints = {}

local info = {}

local stack = {}


function M.start(on_update, on_breakpoint)
	assert(on_update)
	assert(on_breakpoint)

	local depth = 0
	stack = {}
	
	debug.sethook(function(event, line)
		info = debug.getinfo(2)
		if event == "call" then
			if info.what ~= "C" then
				--pprint(info)
				table.insert(stack, info)
				depth = depth + 1
			end
		elseif event == "return" then
			if info.what ~= "C" then
				depth = depth - 1
				if #stack > 0 and stack[#stack].func == info.func then
					table.remove(stack)
				end
				--print(#stack)
			end
		end
		
		if event == "line" and breakpoints[info.short_src] and breakpoints[info.short_src][info.currentline] then
			command = "break"
		end
		
		if not command then
			return
		end
		
		if command == "break" then
			on_breakpoint()
			local next_update = socket.gettime()
			while command == "break" do
				local now = socket.gettime()
				if now > next_update then
					on_update()
					next_update = now + 0.016
				end
			end
		elseif command == "step" then
			command = "break"
		elseif command == "run" then
			command = nil
		end
	end, "crl")
end


function M.stop()
	debug.sethook()
	stack = {}
end


function M.step()
	command = "step"
end


function M.breaknow()
	command = "break"
end


function M.info()
	return info
end


function M.add_breakpoint(file, line)
	breakpoints[file] = breakpoints[file] or {}
	breakpoints[file][line] = true
end

function M.remove_breakpoint(file, line)
	breakpoints[file] = breakpoints[file] or {}
	breakpoints[file][line] = nil
end

function M.list_breakpoints()
	return breakpoints
end

function M.stack()
	local trace = {}
	for _,info in ipairs(stack) do
		table.insert(trace, ("%s:%d %s (%s)"):format(info.short_src, info.linedefined or 0, info.name or "?", tostring(info.func)))
	end
	return trace
end

function M.run()
	command = "run"
end



return M