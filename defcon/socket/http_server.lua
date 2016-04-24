local socket_server = require "defcon.socket.socket_server"

local M = {}

local SERVER_HEADER = "Server: Simple Lua Server v1"

--- Return a properly formatted HTML response with the
-- appropriate response headers set
-- @param document HTML document
-- @param status HTTP response code
-- @return The response
function M.html(document, status)
	local resp = {
		"HTTP/1.1 " .. status or 200,
		SERVER_HEADER,
		"Content-Type: text/html",
		"Content-Length: " .. tostring(#document),
		"",
		document
	}
	return table.concat(resp, "\r\n")
end


function M.json(json, status)
	local resp = {
		"HTTP/1.1 " .. status or 200,
		SERVER_HEADER,
		"Content-Type: application/json; charset=utf-8",
		"Content-Length: " .. tostring(#json),
		"",
		json
	}
	return table.concat(resp, "\r\n")
end

--- Create a new HTTP server
-- @return Server instance
function M.create(port)
	local instance = {}

	local routes = {}

	local unhandled_route_fn = nil

	local ss = socket_server.create(port, function(data, send)
		if not data or #data == 0 then
			return
		end
		local ok, err = pcall(function()
			local request_line = data[1] or ""
			local method, uri, protocol_version = request_line:match("^(%S+)%s(%S+)%s(%S+)")
			local response
			if uri then
				print("http_server.on_data() Trying to find page for", uri)
				for _,route in ipairs(routes) do
					pprint(route)
					if not route.method or route.method == method then
						local matches = { uri:match(route.pattern) }
						if next(matches) then
							print("Serving page from", route.pattern)
							response = route.fn(unpack(matches))
							break
						end
					end
				end
			end
			if not response and unhandled_route_fn then
				response = unhandled_route_fn(method, uri)
			end
			send(response or "")
		end)
		if not ok then
			print(err)
		end
	end)

	-- Replace the underlying socket server's receive function
	function ss.receive(conn, on_data)
		assert(conn, "You must provide a connection")
		assert(on_data, "You must provide an on_data function")
		local request = {}
		local buf = ""
		while true do
			local data, err, buf = conn:receive("*l", buf)
			local closed = (err == "closed")
			if closed or (err ~= "timeout" and (not data or data == "\r\n" or data == "")) then
				for _,line in ipairs(request) do
					print(line)
				end
				local ok, err = pcall(on_data, request, function(response)
					conn:send(response or "/")
				end)
				break
			elseif data then
				table.insert(request, data)
				buf = ""
			end
			--coroutine.yield()
		end
	end

	instance.router = {}

	--- Route HTTP GET requests matching a specific pattern to a
	-- provided function. The function will receive any matches from
	-- the pattern as it's arguments
	-- TODO Add query arg handling
	-- @param pattern Standard Lua pattern
	-- @param fn Function to call
	function instance.router.get(pattern, fn)
		assert(pattern, "You must provide a route pattern")
		assert(fn, "You must provide a route handler function")
		table.insert(routes, { method = "GET", pattern = pattern, fn = fn })
	end

	--- Route HTTP POST requests matching a specific pattern to a
	-- provided function. The function will receive any matches from
	-- the pattern as it's arguments
	-- TODO Add POST data handling
	-- @param pattern Standard Lua pattern
	-- @param fn Function to call
	function instance.router.post(pattern, fn)
		assert(pattern, "You must provide a route pattern")
		assert(fn, "You must provide a route handler function")
		table.insert(routes, { method = "POST", pattern = pattern, fn = fn })
	end

	--- Route all HTTP requests matching a specific pattern to a
	-- provided function. The function will receive any matches from
	-- the pattern as it's arguments
	-- @param pattern Standard Lua pattern
	-- @param fn Function to call
	function instance.router.all(pattern, fn)
		assert(pattern, "You must provide a route pattern")
		assert(fn, "You must provide a route handler function")
		table.insert(routes, { method = nil, pattern = pattern, fn = fn })
	end

	--- Add a handler for unhandled routes. This is typically where
	-- you would return a 404 page
	-- @param fn The function to call when an unhandled route is encountered. The
	-- function will receive the method and uri of the unhandled route as
	-- arguments.
	function instance.router.unhandled(fn)
		assert(fn, "You must provide an unhandled route function")
		unhandled_route_fn = fn
	end

	--- Start the server
	function instance.start()
		ss.start()
	end

	--- Stop the server
	function instance.stop()
		ss.stop()
	end

	--- Stop the server
	function instance.update()
		ss.update()
	end

	return instance
end

return M
