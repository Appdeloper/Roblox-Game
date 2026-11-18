--!strict
--[[
	RemoteGuard — the only way client→server remotes are handled.

	Every request passes three gates before the handler runs:
	  1. rate limit: a token bucket per player per remote (Config.Remotes)
	  2. shape check: exact argument count and types (validator)
	  3. handler runs inside pcall so a bad request can never break the server loop
	Anything that fails is dropped silently (no feedback to probe with).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RemoteGuard = {}

type Bucket = { tokens: number, updated: number }

local buckets: { [Player]: { [string]: Bucket } } = {}

local function allow(player: Player, name: string): boolean
	local now = Clock.now()
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local bucket = perPlayer[name]
	if not bucket then
		bucket = { tokens = Config.Remotes.Burst, updated = now }
		perPlayer[name] = bucket
	end
	bucket.tokens =
		math.min(Config.Remotes.Burst, bucket.tokens + (now - bucket.updated) * Config.Remotes.RatePerSecond)
	bucket.updated = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

--- Builds a validator from expected Luau type names, e.g. args("string", "boolean").
--- Rejects extra arguments, NaN numbers and overly long strings.
function RemoteGuard.args(...: string): (...any) -> boolean
	local expected = { ... }
	return function(...: any): boolean
		local count = select("#", ...)
		if count ~= #expected then
			return false
		end
		for i, kind in expected do
			local value = select(i, ...)
			if typeof(value) ~= kind then
				return false
			end
			if kind == "number" and (value ~= value or math.abs(value) == math.huge) then
				return false
			end
			if kind == "string" and #value > 64 then
				return false
			end
		end
		return true
	end
end

function RemoteGuard.connect(name: string, validator: (...any) -> boolean, handler: (Player, ...any) -> ())
	local remote = Remotes.get(name)
	assert(table.find(Remotes.ClientToServer, name), name .. " is not a client→server remote")
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not allow(player, name) then
			return
		end
		local okShape, valid = pcall(validator, ...)
		if not okShape or not valid then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[RemoteGuard] %s handler error for %d: %s", name, player.UserId, tostring(err)))
		end
	end)
end

function RemoteGuard.init()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return RemoteGuard
