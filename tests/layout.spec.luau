--!strict
local Config = require("../src/shared/Config")
local JumpMath = require("../src/shared/JumpMath")
local Validator = require("../src/server/MapBuilder/LayoutValidator")

local layouts = {
	require("../src/server/MapBuilder/Layouts/Stage1"),
	require("../src/server/MapBuilder/Layouts/Stage2"),
	require("../src/server/MapBuilder/Layouts/Stage3"),
	require("../src/server/MapBuilder/Layouts/Stage4"),
	require("../src/server/MapBuilder/Layouts/Stage5"),
	require("../src/server/MapBuilder/Layouts/Stage6"),
}

local deps = {
	physics = Config.Movement,
	gapRatio = Config.Map.MaxGapRatio,
	riseRatio = Config.Map.MaxRiseRatio,
	killMargin = Config.Map.KillMargin,
	rootHeight = Config.Mannequin.RootHeight,
	jumpMath = JumpMath,
}

return function(T)
	T.suite("Layouts")

	T.test("one layout per stage", function()
		T.eq(#layouts, Config.Game.StageCount)
	end)

	for i, layout in layouts do
		T.test(string.format("stage %d (%s) passes fairness validation", i, layout.name), function()
			local errors = Validator.validate(layout, deps)
			T.expect(#errors == 0, table.concat(errors, "\n       "))
		end)
	end

	T.test("largest jump gap anywhere is under 70% of max jump", function()
		local limit = JumpMath.maxDistance(Config.Movement) * Config.Map.MaxGapRatio
		local largest = 0
		for _, layout in layouts do
			for i = 2, #layout.route do
				if layout.route[i].link == "Jump" then
					largest = math.max(largest, Validator.horizontalGap(layout.route[i - 1], layout.route[i]))
				end
			end
		end
		print(string.format("       largest gap %.2f / limit %.2f", largest, limit))
		T.expect(largest < limit, "gap over limit")
	end)

	T.test("validator rejects an unfair gap", function()
		local bad = {
			name = "Bad",
			net = { center = { 0, 0, 0 }, size = { 10, 1, 10 } },
			spawn = { pos = { 0, 13, 0 } },
			route = {
				{ id = "A", kind = "Platform", center = { 0, 9, 0 }, size = { 4, 2, 4 }, link = "Start" },
				{ id = "B", kind = "Platform", center = { 10, 9, 0 }, size = { 4, 2, 4 }, link = "Jump" },
			},
			trusses = {},
			doors = {},
		}
		T.expect(#Validator.validate(bad, deps) > 0, "6-stud gap should fail")
	end)

	T.test("each new stage has its signature twist", function()
		local s4, s5, s6 = layouts[4] :: any, layouts[5] :: any, layouts[6] :: any
		local kinds = {}
		for _, mover in s4.movers do
			kinds[mover.kind] = true
		end
		T.expect(kinds.Spinner and kinds.Pendulum, "the flies: light rigs and a rope swing")
		local climbs = 0
		for _, box in s4.route do
			if box.link == "Climb" then
				climbs += 1
			end
		end
		T.expect(climbs >= 1, "the flies: a rope ladder up a level")
		local pulses, conveyors = 0, 0
		for _, box in s5.route do
			pulses += if box.pulse then 1 else 0
			conveyors += if box.conveyor then 1 else 0
		end
		T.expect(pulses >= 3 and conveyors == 1, "prop room: shrinking crates and a conveyor")
		local sliders = 0
		for _, mover in s5.movers do
			sliders += if mover.kind == "Slider" then 1 else 0
		end
		T.expect(sliders >= 2, "prop room: moving shelves")
		local real = 0
		for _, exit in s6.exits do
			real += if exit.canBeReal then 1 else 0
		end
		T.expect(#s6.exits >= 5 and real >= 2, "opening night: many exits, one real per run")
		local collapse = 0
		for _, box in s6.route do
			collapse += if box.collapse then 1 else 0
		end
		T.expect(collapse >= 4, "opening night: the set collapses")
	end)

	T.test("pulsing props are fair at full size and never vanish", function()
		for _, box in (layouts[5] :: any).route do
			if box.pulse then
				T.expect(box.pulse.min >= 0.4, box.id .. " shrinks too far")
				T.expect(box.pulse.hold >= 0.4, box.id .. " is big for too little of the cycle")
			end
		end
	end)

	T.test("stage 3 has two exits and collapsing steps", function()
		local s3 = layouts[3] :: any
		T.expect(s3.exits ~= nil, "exits")
		local collapsing = 0
		for _, box in s3.route do
			if box.collapse then
				collapsing += 1
			end
		end
		T.expect(collapsing >= 10, "collapsing staircase")
	end)

	T.test("stage 2 has ladder, slide mat and backdrop", function()
		local s2 = layouts[2] :: any
		T.expect(#s2.trusses >= 1, "ladder")
		T.expect(s2.backdrop ~= nil, "backdrop")
		local hasSlide = false
		for _, box in s2.route do
			hasSlide = hasSlide or box.kind == "Slide"
		end
		T.expect(hasSlide, "slide mat")
	end)

	T.test("every Shortcut stage has a painted door", function()
		for i, layout in layouts do
			if table.find(Config.Behaviours[i], "Shortcut") then
				T.expect(#layout.doors >= 1, "stage " .. i)
			end
		end
		T.eq(#Config.Behaviours, Config.Game.StageCount, "behaviours per stage")
	end)
end
