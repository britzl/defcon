--- Simple, non-blocking, socket server that listens for
-- connections on a specific port and for each connection
-- polls for data.

local socket = require("builtins.scripts.socket")
--local socket = require("dksdk.util.socket.socket_helper")
require("defcon.util.coxpcall")

local M = {}

--- Creates a new socket server
-- @param port
-- @param on_data Function to call when data is received. The
-- function must accept two values: data, reply_fn
function M.create(port, on_data)
	assert(port, "You must provide a port")
	assert(on_data, "You must provide an on_data function")

	local server = {}

	local co = nil
	local server_socket = nil

	local connections = {}

	local function remove_connection(connection)
		for k,v in pairs(connections) do
			if v == connection then
				connections[k] = nil
				break
			end
		end
	end

	--- Socket receive function that will try to read a line of text
	-- from the socket. If data exists it will be passed on to a
	-- callback function.
	-- @param client The client connection
	-- @param on_data Received data will be passed on to this function.
	-- If the function returns anything it will be sent back over the
	-- socket.
	function server.receive(client, on_data)
		assert(client, "You must provide a client")
		assert(on_data, "You must provide an on_data function")
		local data, err = client:receive("*l")
		if data then
			local response = on_data(data)
			if response then
				client:send(response)
			end
		end
		return err
	end

	--- Start the socket server and listen for connections
	-- Each connection is run in it's own coroutine
	function server.start()
		print("Starting server")
		local host = "*"
		server_socket = assert(socket.bind(host, port))
		if not server_socket then
			print("Unable to start server")
			return
		end

		co = coroutine.create(function()
			local ip, port = server_socket:getsockname()
			server_socket:settimeout(0)
			while true do
				local client, err = server_socket:accept()
				if client then
					print("got connection", client, err)
					client:settimeout(0)
					table.insert(connections, client)
				end
				coroutine.yield()
			end
		end)
		coroutine.resume(co)
	end

	--- Stop the socket server. The socket and all
	-- connections will be closed
	function server.stop()
		if server_socket then
			server_socket:close()
		end
		while #connections > 0 do
			local connection = table.remove(connections)
			connection:close()
		end
	end

	--- Update the socket server. This will resume all
	-- the spawned coroutines in order to check for new
	-- connections and data on existing connections
	function server.update()
		if not co then
			return
		end
		local status = coroutine.status(co)
		if status == "suspended" then
			coroutine.resume(co)
		elseif status == "dead" then
			co = nil
			return
		end

		--print("socket_server update", #connections)
		local read, write = socket.select(connections, nil, 0)
		if next(read) then
			for _,connection in ipairs(read) do
				local err = server.receive(connection, on_data)
				if err and err == "closed" then
					print("socket_server update closed")
					remove_connection(connection)
				end
			end
		end
	end

	return server
end

return M
