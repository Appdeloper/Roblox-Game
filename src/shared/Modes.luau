--!strict
--[[
	Modes — the pure rules behind each game mode (no Roblox types; unit-tested offline).

	  Story    the six stages in order
	  Daily    the same seeded list of stages for everyone on a UTC day; only your first finish
	           of the day goes on the Daily board
	  Endless  stages as shuffled set pieces, looping forever; every clear shortens the
	           mannequin's delay (it gets faster). Lives run out → your score is stages cleared
	  Coop     Story for up to four players: clears are shared, a caught player is "downed"
	           until a teammate revives them, and the stage restarts only if everyone is down
]]

export type Mode = "Story" | "Daily" | "Endless" | "Coop"

local Modes = {}

Modes.list = { "Story", "Daily", "Endless", "Coop" } :: { Mode }

function Modes.isMode(value: any): boolean
	return type(value) == "string" and table.find(Modes.list, value :: any) ~= nil
end

--- Days since the Unix epoch (UTC). Everyone on Earth shares the same Daily Run.
function Modes.dayNumber(unixSeconds: number): number
	return math.floor(unixSeconds / 86400)
end

--- A small deterministic PRNG (LCG), so a seed means the same thing on every server.
local function rng(seed: number): () -> number
	local state = (math.floor(seed) % 2147483647 + 2147483647) % 2147483647
	if state == 0 then
		state = 1
	end
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

--- Fisher–Yates shuffle of 1..n with a seeded generator.
local function shuffled(n: number, next: () -> number): { number }
	local out = {}
	for i = 1, n do
		out[i] = i
	end
	for i = n, 2, -1 do
		local j = math.floor(next() * i) + 1
		out[i], out[j] = out[j], out[i]
	end
	return out
end

--- `length` distinct stages for the day, in a seeded order, always ending on the finale
--- (so every Daily Run ends at a door choice).
function Modes.dailySequence(day: number, stageCount: number, length: number): { number }
	local next = rng(day * 7919 + 17)
	local pool = shuffled(stageCount - 1, next)
	local out = {}
	for i = 1, math.min(length - 1, #pool) do
		table.insert(out, pool[i])
	end
	table.insert(out, stageCount)
	return out
end

--- The first `count` stages of an Endless run: shuffled rounds of every stage, never the same
--- stage twice in a row.
function Modes.endlessSequence(seed: number, stageCount: number, count: number): { number }
	local next = rng(seed)
	local out = {}
	while #out < count do
		local round = shuffled(stageCount, next)
		if #out > 0 and round[1] == out[#out] then
			round[1], round[#round] = round[#round], round[1]
		end
		for _, s in round do
			table.insert(out, s)
		end
	end
	while #out > count do
		table.remove(out)
	end
	return out
end

export type EndlessParams = { BaseDelay: number, DelayStep: number, MinDelay: number }

--- Copycat delay after `cleared` stages: it gets closer every stage, down to a floor.
function Modes.endlessDelay(params: EndlessParams, cleared: number): number
	return math.max(params.MinDelay, params.BaseDelay - params.DelayStep * cleared)
end

return Modes
