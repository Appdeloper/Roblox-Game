--!strict
--[[
	Stage 5 — The Prop Room.
	Crates that shrink and grow (jump while they're big), a conveyor belt of costumes running
	the wrong way, and an aisle where two shelves slide across your path.

	Signature scare (on the conveyor): every costume on the rail turns to look at you.
	Pure data: no requires.
]]

local route = {
	{ id = "PropDoor", kind = "Platform", center = { 10, 8, 0 }, size = { 16, 2, 14 }, link = "Start" },
	{
		id = "CrateA",
		kind = "Platform",
		center = { 26, 9, 0 },
		size = { 8, 2, 8 },
		link = "Jump",
		pulse = { period = 4, phase = 0, min = 0.45, hold = 0.5 },
	},
	{
		id = "CrateB",
		kind = "Platform",
		center = { 38, 10, 0 },
		size = { 8, 2, 8 },
		link = "Jump",
		pulse = { period = 4, phase = 0.33, min = 0.45, hold = 0.5 },
	},
	{
		id = "CrateC",
		kind = "Platform",
		center = { 50, 11, 0 },
		size = { 8, 2, 8 },
		link = "Jump",
		pulse = { period = 4, phase = 0.66, min = 0.45, hold = 0.5 },
	},
	{ id = "ShelfLanding", kind = "Landing", center = { 63, 11, 0 }, size = { 10, 2, 12 }, link = "Jump" },
	{
		id = "Conveyor",
		kind = "Platform",
		center = { 82, 11, 0 },
		size = { 26, 1, 8 },
		link = "Jump",
		-- Runs back toward the start: keep moving or it carries you off.
		conveyor = { -7, 0, 0 },
	},
	{ id = "Aisle", kind = "Platform", center = { 108, 11, 0 }, size = { 18, 2, 10 }, link = "Jump" },
	{ id = "WardrobeDoor", kind = "Landing", center = { 128, 11, 0 }, size = { 16, 2, 14 }, link = "Jump" },
}

return {
	name = "Stage5_PropRoom",
	room = { min = { -6, -6, -26 }, max = { 140, 40, 26 } },
	net = { center = { 67, -4.5, 0 }, size = { 150, 1, 54 } },
	spawn = { pos = { 5, 12, 0 }, facing = { 1, 0, 0 } },
	mannequinHome = { pos = { 3, 12, -5 }, facing = { 1, 0, 0 } },

	route = route,
	trusses = {},

	solids = {
		{ name = "BackShelves", center = { 67, 14, 25 }, size = { 140, 28, 1 }, surface = "Plaster" },
		{ name = "FrontShelves", center = { 67, 14, -25 }, size = { 140, 28, 1 }, surface = "Plaster" },
	},

	doors = {},

	movers = {
		{
			id = "ShelfA",
			kind = "Slider",
			center = { 104, 16, 0 },
			size = { 3, 8, 6 },
			axis = "Z",
			motion = { period = 3.4, phase = 0, amplitude = 9 },
		},
		{
			id = "ShelfB",
			kind = "Slider",
			center = { 112, 16, 0 },
			size = { 3, 8, 6 },
			axis = "Z",
			motion = { period = 3.4, phase = 0.5, amplitude = 9 },
		},
	},

	exitZone = { center = { 132, 15, 0 }, size = { 6, 8, 10 } },
	scareZone = { center = { 82, 15, 0 }, size = { 10, 10, 10 } },
}
