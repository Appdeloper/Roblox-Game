--!strict
--[[
	Stage 3 — Curtain Call.
	A collapsing cardboard staircase drops from the fly gallery to the main stage, with one
	solid landing halfway. Two exits wait at the far wall: one is painted on the set, the
	other is real (light beneath it). RoundService picks which is real for each run.

	Painted door: entry beside the mid landing, exit beside the bottom of the stairs.
	Pure data: no requires.
]]

local STEP = { 4, 1.5, 10 }

local route = {
	{ id = "Gallery", kind = "Platform", center = { 10, 39, 0 }, size = { 20, 2, 16 }, link = "Start" },
}

-- Upper flight: six steps, 1-stud gaps, 2.5-stud drops.
for i = 1, 6 do
	local left = 21 + (i - 1) * 5
	local top = 40 - 2.5 * i
	table.insert(route, {
		id = "StepUpper" .. i,
		kind = "Step",
		center = { left + 2, top - 0.75, 0 },
		size = STEP,
		link = "Jump",
		collapse = true,
	})
end

table.insert(route, {
	id = "MidLanding",
	kind = "Landing",
	center = { 56, 22, 0 },
	size = { 10, 2, 14 },
	link = "Jump",
})

-- Lower flight.
for j = 1, 6 do
	local left = 62 + (j - 1) * 5
	local top = 23 - 2.5 * j
	table.insert(route, {
		id = "StepLower" .. j,
		kind = "Step",
		center = { left + 2, top - 0.75, 0 },
		size = STEP,
		link = "Jump",
		collapse = true,
	})
end

table.insert(route, {
	id = "MainStage",
	kind = "Floor",
	center = { 114, 5, 0 },
	size = { 44, 2, 40 },
	link = "Jump",
})

return {
	name = "Stage3_CurtainCall",
	room = { min = { -6, -6, -26 }, max = { 136, 56, 26 } },
	net = { center = { 66, -4.5, 0 }, size = { 148, 1, 52 } },
	spawn = { pos = { 5, 43, 0 }, facing = { 1, 0, 0 } },
	mannequinHome = { pos = { 3, 43, -6 }, facing = { 1, 0, 0 } },

	route = route,
	trusses = {},

	solids = {
		-- Flat the entry door is set into (left of the mid landing).
		{ name = "LandingFlat", center = { 56, 30, -9.2 }, size = { 10, 14, 1 }, surface = "Plaster" },
		-- Flat beside the foot of the stairs holding the exit door.
		{ name = "FootFlat", center = { 100, 13, -20.5 }, size = { 12, 14, 1 }, surface = "Plaster" },
		{
			name = "SideCurtainLeft",
			center = { 120, 28, -24 },
			size = { 30, 44, 1 },
			surface = "Curtain",
			collide = false,
			tag = "Curtain",
		},
		{
			name = "SideCurtainRight",
			center = { 120, 28, 24 },
			size = { 30, 44, 1 },
			surface = "Curtain",
			collide = false,
			tag = "Curtain",
		},
	},

	doors = {
		{
			id = "S3_LandingDoor",
			entry = { pos = { 56, 23, -8.6 }, facing = { 0, 0, 1 } },
			exit = { pos = { 100, 6, -19.9 }, facing = { 0, 0, 1 } },
			trigger = { center = { 56, 28, 0 }, size = { 10, 10, 14 } },
			entryPoint = { 56, 26, -10.6 },
			path = { { 56, 26, -11.6 }, { 100, 9, -22 }, { 100, 9, -21 } },
			exitStep = { 100, 9, -14 },
			pathSpeed = 22,
		},
	},

	scareZone = { center = { 98, 11, 0 }, size = { 10, 10, 40 } },

	exits = {
		left = { pos = { 135.9, 6, -8 }, facing = { -1, 0, 0 } },
		right = { pos = { 135.9, 6, 8 }, facing = { -1, 0, 0 } },
		leftZone = { center = { 133, 10, -8 }, size = { 5, 8, 6 } },
		rightZone = { center = { 133, 10, 8 }, size = { 5, 8, 6 } },
	},
}
