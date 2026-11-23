--!strict
local Config = require("../src/shared/Config")
local LookRule = require("../src/shared/LookRule")

return function(T)
	T.suite("LookRule")
	local P = Config.Mannequin.Look

	local function run(state: LookRule.State, looking: boolean, from: number, to: number): { LookRule.Result }
		local out = {}
		local t = from
		while t < to - 1e-9 do
			t += 0.05
			table.insert(out, LookRule.step(state, P, looking, t))
		end
		return out
	end

	T.test("a glance freezes it without a penalty", function()
		local s = LookRule.new()
		LookRule.step(s, P, false, 0)
		local r = run(s, true, 0, P.StareSeconds * 0.5)
		T.expect(r[#r].frozen, "frozen while looking")
		for _, x in r do
			T.expect(not x.lunge, "no lunge on a short glance")
		end
	end)

	T.test("staring past the limit lunges exactly once, then cooldown", function()
		local s = LookRule.new()
		LookRule.step(s, P, false, 0)
		local r = run(s, true, 0, P.StareSeconds + P.CooldownSeconds * 0.9)
		local lunges = 0
		for _, x in r do
			if x.lunge then
				lunges += 1
			end
		end
		T.eq(lunges, 1, "lunges")
		T.expect(not r[#r].frozen, "gaze ignored during the cooldown")
	end)

	T.test("looking away drains the meter", function()
		local s = LookRule.new()
		LookRule.step(s, P, false, 0)
		run(s, true, 0, P.StareSeconds * 0.6)
		local r = run(s, false, P.StareSeconds * 0.6, P.StareSeconds * 0.6 + 2 / P.DrainRate)
		T.eq(r[#r].meter, 0, "meter after looking away")
	end)

	T.test("the stare limit leaves time to react on a phone", function()
		T.expect(P.StareSeconds >= 1.5, "StareSeconds too short to read the meter")
		T.expect(
			P.MinGapSeconds * Config.Movement.WalkSpeed > Config.Catch.Distance * 2,
			"lunge lands within catch range"
		)
	end)

	T.test("view cone", function()
		T.expect(LookRule.inCone(1, 10, P.MaxAngleDegrees, P.MaxRange), "dead ahead")
		T.expect(not LookRule.inCone(0, 10, P.MaxAngleDegrees, P.MaxRange), "90 degrees off")
		T.expect(not LookRule.inCone(1, P.MaxRange + 1, P.MaxAngleDegrees, P.MaxRange), "too far")
	end)
end
