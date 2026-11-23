--!strict
--[[
	Stage 4 — The Flies.
	High above the stage, on the narrow catwalks where scenery hangs. Two rotating light rigs
	sweep their beams across the catwalks (cross while the beam is pointed away: the server
	judges the beam), and a sandbag on a rope swings across the upper catwalk. A rope ladder
	(truss) takes you up a level halfway.

	Signature scare (catwalk D): a light rig drops on its chain and the spot lands on you.
	Pure data: no requires.
]]

local route = {
	{ id = "FlyGallery", kind = "Platform", center = { 10, 40, 0 }, size = { 16, 2, 14 }, link = "Start" },
	{ id = "CatwalkA", kind = "Platform", center = { 28, 40, 0 }, size = { 16, 1, 5 }, link = "Jump" },
	{ id = "CatwalkB", kind = "Platform", center = { 48, 40, 0 }, size = { 16, 1, 5 }, link = "Jump" },
	{ id = "RopeLanding", kind = "Landing", center = { 63, 40, 0 }, size = { 8, 1, 8 }, link = "Jump" },
	{ id = "UpperCatwalk", kind = "Platform", center = { 77, 48, 0 }, size = { 16, 1, 5 }, link = "Climb" },
	{ id = "CatwalkD", kind = "Platform", center = { 95, 46, 0 }, size = { 14, 1, 5 }, link = "Jump" },
	{ id = "PipeBatten", kind = "Platform", center = { 110, 43, 0 }, size = { 10, 1, 4 }, link = "Jump" },
	{ id = "LoadingRail", kind = "Landing", center = { 124, 40, 0 }, size = { 16, 2, 14 }, link = "Jump" },
}

return {
	name = "Stage4_TheFlies",
	room = { min = { -6, -6, -24 }, max = { 140, 70, 24 } },
	net = { center = { 67, -4.5, 0 }, size = { 150, 1, 50 } },
	spawn = { pos = { 5, 44, 0 }, facing = { 1, 0, 0 } },
	mannequinHome = { pos = { 3, 44, -5 }, facing = { 1, 0, 0 } },

	route = route,
	-- Rope ladder from the landing up to the upper catwalk.
	trusses = {
		{ center = { 68, 44.5, 0 }, size = { 2, 9, 2 } },
	},

	solids = {
		-- The stage far below: scenery only (below the kill line, so falls still count).
		{
			name = "StageFloorBelow",
			center = { 67, -3, 0 },
			size = { 140, 1, 44 },
			surface = "Plank",
			collide = false,
		},
		-- The fly rail: a wall of rope locks along one side.
		{ name = "FlyRail", center = { 67, 30, 23.5 }, size = { 140, 40, 1 }, surface = "Plaster" },
	},

	doors = {},

	movers = {
		{
			id = "RigA",
			kind = "Spinner",
			center = { 48, 52, -9 },
			size = { 3, 2, 3 },
			axis = "X",
			motion = { period = 4.2, phase = 0, aim = 90, halfWidth = 28 },
			gate = { center = { 48, 43, 0 }, size = { 6, 6, 5 } },
		},
		{
			id = "Sandbag",
			kind = "Pendulum",
			center = { 80, 62, 0 },
			size = { 3, 3, 3 },
			axis = "Z",
			ropeLength = 11,
			motion = { period = 3.2, phase = 0.25, amplitude = 55 },
		},
		{
			id = "RigB",
			kind = "Spinner",
			center = { 95, 58, 9 },
			size = { 3, 2, 3 },
			axis = "X",
			motion = { period = 3.6, phase = 0.5, aim = 270, halfWidth = 28 },
			gate = { center = { 95, 49, 0 }, size = { 6, 6, 5 } },
		},
	},

	exitZone = { center = { 128, 44, 0 }, size = { 6, 8, 10 } },
	scareZone = { center = { 95, 50, 0 }, size = { 10, 10, 10 } },
}
