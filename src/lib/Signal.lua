--!strict

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

type SignalNode = {
	callback: (...any) -> (),
	once: boolean,
}

export type Signal<T... = ...any> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
	_connections: { SignalNode },
	_destroyed: boolean,
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_connections = {},
		_destroyed = false,
	} :: any, Signal) :: Signal<T...>
end

function Signal:Connect<T...>(fn: (T...) -> ()): Connection
	assert(not self._destroyed, "Cannot connect to destroyed Signal")

	local node: SignalNode = {
		callback = fn,
		once = false,
	}

	table.insert(self._connections, node)

	local connection: Connection = {
		Disconnect = function(conn: Connection)
			for i, n in ipairs(self._connections) do
				if n == node then
					table.remove(self._connections, i)
					break
				end
			end
		end,
	}

	return connection
end

function Signal:Once<T...>(fn: (T...) -> ()): Connection
	assert(not self._destroyed, "Cannot connect to destroyed Signal")

	local node: SignalNode = {
		callback = fn,
		once = true,
	}

	table.insert(self._connections, node)

	local connection: Connection = {
		Disconnect = function(conn: Connection)
			for i, n in ipairs(self._connections) do
				if n == node then
					table.remove(self._connections, i)
					break
				end
			end
		end,
	}

	return connection
end

function Signal:Fire<T...>(...: T...)
	if self._destroyed then
		return
	end

	local toRemove = {}
	for i, node in ipairs(self._connections) do
		local ok = pcall(node.callback, ...)
		if not ok then
			warn("Signal callback error:", debug.traceback())
		end
		if node.once then
			table.insert(toRemove, i)
		end
	end

	for i = #toRemove, 1, -1 do
		table.remove(self._connections, toRemove[i])
	end
end

function Signal:DisconnectAll()
	table.clear(self._connections)
end

function Signal:Destroy()
	self:DisconnectAll()
	self._destroyed = true
end

return Signal
