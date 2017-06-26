local M = {}


local command = nil

local breakpoints = {}

local info = {}

local stack = {}

local locals = {}


local depth = 0
local stepout_depth = nil


function M.start(on_update, on_breakpoint)
	assert(on_update)
	assert(on_breakpoint)

	depth = 0
	stack = {}
	
	debug.sethook(function(event, line)
		info = debug.getinfo(2)
		if event == "call" then
			if info.what ~= "C" then
				table.insert(stack, info)
				depth = depth + 1
				if command == "stepover" then 
					command = "stepout"
					stepout_depth = depth - 1
				end
			end
		elseif event == "return" then
			if info.what ~= "C" then
				depth = depth - 1
				if #stack > 0 and stack[#stack].func == info.func then
					table.remove(stack)
					if command == "stepout" and depth == stepout_depth then
						command = "step"
					end
				end
			end
		elseif event == "line" then
			if breakpoints[info.short_src] and breakpoints[info.short_src][info.currentline] then
				command = "break"
			elseif command == "stepover" then
				command = "break"
			end
		end
		
		if not command then
			return
		end
		
		if command == "break" then
			locals = {}
			while true do
				local name, value = debug.getlocal(2, #locals + 1)
				if not name then
					break
				end
				locals[#locals + 1] = { name = name, value = value }
			end
			
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

function M.stepover()
	command = "stepover"
end

function M.stepout()
	command = "stepout"
	stepout_depth = depth - 1
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

function M.locals()
	local l = {}
	for _,var in ipairs(locals) do
		if var.name:sub(1, 1) ~= "(" then
			table.insert(l, ("%s = %s"):format(var.name, tostring(var.value)))
		end
	end
	return l
end

function M.run()
	command = "run"
end



return M