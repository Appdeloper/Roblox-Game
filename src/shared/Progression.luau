--!strict
--[[
	Progression — pure rules for unlocks and the daily streak (no Roblox types; unit-tested).

	  ownsCosmetic   can this player use a cosmetic? (free / title / trophy / streak / game pass)
	  login          the daily-visit streak: +1 on the next UTC day, back to 1 after a gap
	  newlyUnlocked  which cosmetics a streak just unlocked (for the "daily reward" message)
]]

export type Unlock = { Kind: string, Key: any? }
export type Facts = {
	titles: { [string]: boolean },
	trophies: { [string]: boolean },
	bestStreak: number,
	passes: { [string]: boolean },
}

local Progression = {}

function Progression.unlocked(unlock: Unlock, facts: Facts): boolean
	local kind = unlock.Kind
	if kind == "Free" then
		return true
	elseif kind == "Title" then
		return facts.titles[unlock.Key :: string] == true
	elseif kind == "Trophy" then
		return facts.trophies[unlock.Key :: string] == true
	elseif kind == "Streak" then
		return facts.bestStreak >= (unlock.Key :: number)
	elseif kind == "GamePass" then
		return facts.passes[unlock.Key :: string] == true
	end
	return false
end

--- `catalog` is Config.Cosmetics.
function Progression.ownsCosmetic(catalog: any, category: string, id: string, facts: Facts): boolean
	local items = catalog[category]
	local item = items and items[id]
	return item ~= nil and Progression.unlocked(item.Unlock, facts)
end

export type Streak = { streak: number, best: number, lastDay: number?, isNewDay: boolean }

--- Updates the streak for a visit on `today` (UTC day number).
function Progression.login(lastDay: number?, streak: number, best: number, today: number): Streak
	if lastDay == today then
		return { streak = math.max(streak, 1), best = math.max(best, streak, 1), lastDay = today, isNewDay = false }
	end
	local nextStreak = if lastDay ~= nil and today == lastDay + 1 then streak + 1 else 1
	return { streak = nextStreak, best = math.max(best, nextStreak), lastDay = today, isNewDay = true }
end

--- Streak-unlocked cosmetics whose threshold is exactly `best` (so each is announced once).
function Progression.newlyUnlocked(catalog: any, best: number): { { category: string, id: string } }
	local out = {}
	for category, items in catalog do
		for id, item in items do
			if item.Unlock.Kind == "Streak" and item.Unlock.Key == best then
				table.insert(out, { category = category, id = id })
			end
		end
	end
	table.sort(out, function(a, b)
		return a.category .. a.id < b.category .. b.id
	end)
	return out
end

return Progression
