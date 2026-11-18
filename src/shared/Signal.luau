--!strict
--[[
	Signal — tiny in-process event (no BindableEvent, no instance allocation).
	Like Roblox events, every handler runs on its own thread (task.spawn): handlers start
	immediately in connection order, but one that yields (e.g. a DataStore call) never blocks
	the code that fired the signal, and an error in one handler can't stop the others.
]]

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

-- task.spawn in Roblox (and the Lune harness); a plain call in the offline Luau test runner,
-- which has no `task` library.
local function spawnHandler(fn: (...any) -> (), ...: any)
	if typeof(task) == "table" then
		task.spawn(fn, ...)
	else
		fn(...)
	end
end

function Signal.new<T...>(): Signal<T...>
	local handlers: { { fn: (T...) -> (), conn: Connection } } = {}
	local self = {} :: any

	function self:Connect(handler: (T...) -> ()): Connection
		local conn = { Connected = true } :: any
		local entry = { fn = handler, conn = conn }
		function conn:Disconnect()
			if not conn.Connected then
				return
			end
			conn.Connected = false
			local index = table.find(handlers, entry)
			if index then
				table.remove(handlers, index)
			end
		end
		table.insert(handlers, entry)
		return conn
	end

	function self:Fire(...: T...)
		-- Copy so handlers may disconnect themselves while firing.
		local snapshot = table.clone(handlers)
		for _, entry in snapshot do
			if entry.conn.Connected then
				spawnHandler(entry.fn, ...)
			end
		end
	end

	function self:DisconnectAll()
		for _, entry in table.clone(handlers) do
			entry.conn:Disconnect()
		end
	end

	return self :: Signal<T...>
end

return Signal
