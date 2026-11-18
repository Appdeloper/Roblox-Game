--!strict
--[[
	Signal — tiny in-process event (no BindableEvent, no instance allocation).
	Handlers run synchronously in connection order; a handler error is reported and the
	remaining handlers still run.
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
				local ok, err = pcall(entry.fn, ...)
				if not ok then
					warn("[Signal] handler error: " .. tostring(err))
				end
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
