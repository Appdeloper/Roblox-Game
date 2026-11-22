--!strict
--[[
	Stage 1 — The Empty Auditorium.
	Route runs along +X from the back of the house to the stage. The floor is a fog-covered
	safety net. Tipped-over seat rows are the stepping stones; prop trunks climb onto the stage.

	Painted door: entry on the right-hand wall beside the aisle landing, exit on the same wall
	beside the orchestra rail — the mannequin cuts through the wall corridor while you hop rows.
	Pure data: no requires (loaded by the offline tests too).
]]

local ROW = { 3, 2, 22 }

return {
	name = "Stage1_Auditorium",
	room = { min = { -6, -2, -26 }, max = { 160, 46, 26 } },
	net = { center = { 77, 0.5, 0 }, size = { 166, 1, 52 } },
	spawn = { pos = { 5, 13, 0 }, facing = { 1, 0, 0 } },
	mannequinHome = { pos = { 3, 13, -11 }, facing = { 1, 0, 0 } },

	route = {
		{ id = "Entrance", kind = "Platform", center = { 8, 9, 0 }, size = { 16, 2, 14 }, link = "Start" },
		{ id = "Row1", kind = "SeatRow", center = { 21.5, 9, 0 }, size = ROW, tilt = 12, link = "Jump" },
		{ id = "Row2", kind = "SeatRow", center = { 29, 9.5, 0 }, size = ROW, tilt = -10, link = "Jump" },
		{ id = "Row3", kind = "SeatRow", center = { 36.5, 10, 0 }, size = ROW, tilt = 14, link = "Jump" },
		{ id = "Row4", kind = "SeatRow", center = { 44.5, 10, 2 }, size = ROW, tilt = -12, link = "Jump" },
		{ id = "AisleLanding", kind = "Landing", center = { 54, 10.5, 14.75 }, size = { 8, 2, 21.5 }, link = "Jump" },
		{ id = "Row5", kind = "SeatRow", center = { 62.5, 11, 6 }, size = ROW, tilt = 10, link = "Jump" },
		{ id = "Row6", kind = "SeatRow", center = { 70, 11.5, 4 }, size = ROW, tilt = -14, link = "Jump" },
		{ id = "Row7", kind = "SeatRow", center = { 77.5, 12, 4 }, size = ROW, tilt = 12, link = "Jump" },
		{ id = "Row8", kind = "SeatRow", center = { 85, 12.5, 6 }, size = ROW, tilt = -10, link = "Jump" },
		{ id = "OrchestraRail", kind = "Landing", center = { 93.5, 13, 13.25 }, size = { 6, 2, 24.5 }, link = "Jump" },
		{ id = "Trunk1", kind = "Platform", center = { 99, 15.5, 10 }, size = { 5, 3, 5 }, link = "Jump" },
		{ id = "Trunk2", kind = "Platform", center = { 99, 18.5, 3.5 }, size = { 5, 3, 5 }, link = "Jump" },
		{ id = "Stage", kind = "Floor", center = { 130, 11, 0 }, size = { 57, 22, 52 }, link = "Jump" },
	},

	trusses = {},

	solids = {
		-- Where the mannequin waits, half-hidden in the dark wings.
		{
			name = "PropCloset",
			center = { 3, 9, -11 },
			size = { 6, 2, 6 },
			surface = "AgedWood",
		},
		{
			name = "ClosetCurtain",
			center = { 3, 18, -14.5 },
			size = { 7, 16, 0.4 },
			surface = "Curtain",
			collide = false,
			tag = "Curtain",
		},
		-- Back curtain on the stage: the "screen" the shadow-bow scare is cast on.
		{
			name = "BackCurtain",
			center = { 157.5, 34, 0 },
			size = { 1, 24, 50 },
			surface = "Curtain",
			collide = true,
			tag = "ShadowScreen",
		},
		-- Proscenium side curtains.
		{
			name = "ProsceniumLeft",
			center = { 104, 34, -21 },
			size = { 1.5, 24, 8 },
			surface = "Curtain",
			collide = false,
			tag = "Curtain",
		},
		{
			name = "ProsceniumRight",
			center = { 104, 34, 21 },
			size = { 1.5, 24, 8 },
			surface = "Curtain",
			collide = false,
			tag = "Curtain",
		},
		{
			name = "ProsceniumArch",
			center = { 104, 44, 0 },
			size = { 2, 4, 52 },
			surface = "Curtain",
			collide = false,
		},
	},

	doors = {
		{
			id = "S1_SideDoor",
			entry = { pos = { 54, 11.5, 25.6 }, facing = { 0, 0, -1 } },
			exit = { pos = { 93.5, 14, 25.6 }, facing = { 0, 0, -1 } },
			trigger = { center = { 54, 16, 14 }, size = { 8, 10, 20 } },
			entryPoint = { 54, 14.5, 28.5 },
			path = { { 54, 14.5, 29.5 }, { 93.5, 17, 29.5 }, { 93.5, 17, 27 } },
			exitStep = { 93.5, 17, 20 },
			pathSpeed = 22,
		},
	},

	exitZone = { center = { 154, 27, 0 }, size = { 7, 10, 12 } },
	scareZone = { center = { 122, 27, 0 }, size = { 10, 10, 50 } },
}
