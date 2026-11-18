--!strict
--[[
	Retry — call a yielding function (DataStore, BadgeService, …) with exponential backoff.
	Returns (true, result) on success or (false, lastError) after `attempts` tries.
]]

local Retry = {}

function Retry.call<T>(label: string, attempts: number, baseDelay: number, fn: () -> T): (boolean, any)
	local lastError: any = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		warn(string.format("[Retry] %s failed (attempt %d/%d): %s", label, attempt, attempts, tostring(result)))
		if attempt < attempts then
			task.wait(baseDelay * 2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

return Retry
