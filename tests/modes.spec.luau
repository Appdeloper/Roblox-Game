--!strict
local Config = require("../src/shared/Config")
local Modes = require("../src/shared/Modes")

return function(T)
	T.suite("Modes")
	local N = Config.Game.StageCount

	T.test("mode list and validation", function()
		T.expect(Modes.isMode("Story") and Modes.isMode("Coop"), "known modes")
		T.expect(not Modes.isMode("story") and not Modes.isMode(3), "unknown modes rejected")
	end)

	T.test("daily run is the same for everyone that day and ends on the finale", function()
		local day = Modes.dayNumber(1795400000)
		local a = Modes.dailySequence(day, N, Config.Modes.Daily.Length)
		local b = Modes.dailySequence(day, N, Config.Modes.Daily.Length)
		T.eq(#a, Config.Modes.Daily.Length, "length")
		T.eq(table.concat(a, ","), table.concat(b, ","), "deterministic")
		T.eq(a[#a], N, "ends on the finale")
		local seen = {}
		for _, s in a do
			T.expect(not seen[s], "no repeats")
			T.expect(s >= 1 and s <= N, "valid stage")
			seen[s] = true
		end
		local other = Modes.dailySequence(day + 1, N, Config.Modes.Daily.Length)
		local same = 0
		for i = 1, #a do
			same += if a[i] == other[i] then 1 else 0
		end
		T.expect(same < #a, "a different day gives a different run")
	end)

	T.test("days roll over at UTC midnight", function()
		T.eq(Modes.dayNumber(86400 * 20000 - 1) + 1, Modes.dayNumber(86400 * 20000), "rollover")
	end)

	T.test("endless never repeats a stage back to back and covers every stage", function()
		local seq = Modes.endlessSequence(42, N, 60)
		T.eq(#seq, 60, "count")
		local counts = {}
		for i, s in seq do
			counts[s] = (counts[s] or 0) + 1
			if i > 1 then
				T.expect(seq[i - 1] ~= s, "back-to-back repeat at " .. i)
			end
		end
		for s = 1, N do
			T.eq(counts[s], 10, "stage " .. s .. " appears once per round")
		end
	end)

	T.test("endless gets faster but never unfair", function()
		local p = Config.Modes.Endless
		T.eq(Modes.endlessDelay(p, 0), p.BaseDelay, "starts at the story delay")
		T.expect(Modes.endlessDelay(p, 3) < p.BaseDelay, "faster after clears")
		T.eq(Modes.endlessDelay(p, 1000), p.MinDelay, "floor")
		T.expect(
			p.MinDelay * Config.Movement.WalkSpeed > Config.Catch.Distance * 3,
			"floor still escapable at walk speed"
		)
	end)
end
