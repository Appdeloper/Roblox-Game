--!strict
--[[
	Stage 2 — The Painted Street.
	Climb the scenery ladder, cross four shopfront roofs, drop onto the slide mat, then slip
	under the descending backdrop. A painted street facade runs along the back (+Z) with
	upstairs windows — the stage-2 scare walks the mannequin past them.

	Painted door: entry is a rooftop door on roof A, exit is the shop door beside the landing.
	The mannequin's hidden path runs behind the facade, below the window sills.
	Pure data: no requires.
]]

local FACADE_Z = 13 -- centre of the facade wall (front face at z = 12)

return {
	name = "Stage2_PaintedStreet",
	room = { min = { -6, -12, -30 }, max = { 178, 60, 30 } },
	net = { center = { 86, -11, 0 }, size = { 184, 1, 60 } },
	spawn = { pos = { 6, 4, 0 }, facing = { 1, 0, 0 } },
	mannequinHome = { pos = { 2, 4, -8 }, facing = { 1, 0, 0 } },

	route = {
		{ id = "Deck", kind = "Platform", center = { 10, 0, 0 }, size = { 20, 2, 20 }, link = "Start" },
		{ id = "RoofA", kind = "Roof", center = { 32, 7, 0 }, size = { 20, 34, 20 }, link = "Climb" },
		{
			id = "RoofB",
			kind = "Roof",
			center = { 54.5, 7.75, 0 },
			size = { 16, 35.5, 20 },
			link = "Jump",
		},
		{ id = "RoofC", kind = "Roof", center = { 74.5, 7, 0 }, size = { 14, 34, 20 }, link = "Jump" },
		{ id = "RoofD", kind = "Roof", center = { 92.5, 8, 0 }, size = { 14, 36, 20 }, link = "Jump" },
		{
			id = "SlideMat",
			kind = "Slide",
			center = { 113, 8, 0 },
			size = { 24, 12, 14 },
			link = "Drop",
			slopeToward = "+X",
		},
		{ id = "Landing", kind = "Landing", center = { 137.5, 0, 0 }, size = { 25, 2, 22 }, link = "Slide" },
		{ id = "Backstage", kind = "Platform", center = { 163, 0, 0 }, size = { 26, 2, 22 }, link = "Walk" },
	},

	-- The scenery ladder up the front of shop A.
	trusses = {
		{ center = { 21, 13, 0 }, size = { 2, 24, 2 } },
	},

	solids = {
		-- Shopfront bodies under the roofs are the roof boxes themselves; these are the extras.
		{
			name = "SlideSupport",
			center = { 113, -4, 0 },
			size = { 24, 12, 14 },
			surface = "AgedWood",
		},
		-- Side flats force the player under the backdrop rather than around it.
		{
			name = "BackdropFlatLeft",
			center = { 146, 20, -20.5 },
			size = { 2, 64, 19 },
			surface = "Plaster",
		},
		{
			name = "BackdropFlatRight",
			center = { 146, 20, 20.5 },
			size = { 2, 64, 19 },
			surface = "Plaster",
		},
		{
			name = "BackdropHeader",
			center = { 146, 46, 0 },
			size = { 2, 28, 22 },
			surface = "Plaster",
		},
		-- Painted street facade (built with window holes by the Stage 2 dressing).
		{
			name = "StreetFacade",
			center = { 72, 24, FACADE_Z },
			size = { 152, 68, 2 },
			surface = "FacadeSage",
			tag = "StreetFacade",
			-- Upstairs windows (local X spans, one shared Y band) — the scare puppet walks behind them.
			windows = { y1 = 30, y2 = 37, spans = { { 48, 54 }, { 58, 64 }, { 68, 74 }, { 78, 84 } } },
		},
	},

	doors = {
		{
			id = "S2_RooftopDoor",
			entry = { pos = { 40, 24, 11.9 }, facing = { 0, 0, -1 } },
			exit = { pos = { 131, 1, 11.9 }, facing = { 0, 0, -1 } },
			trigger = { center = { 36, 29, 0 }, size = { 12, 10, 20 } },
			entryPoint = { 40, 27, 15 },
			-- Kept below the window sills (y = 30) so only the scare puppet is ever seen upstairs.
			path = { { 40, 27, 16.5 }, { 44, 22, 16.5 }, { 120, 22, 16.5 }, { 131, 4, 16.5 }, { 131, 4, 13.5 } },
			exitStep = { 131, 4, 7 },
			pathSpeed = 26,
		},
	},

	exitZone = { center = { 172, 5, 0 }, size = { 6, 8, 20 } },
	-- The scare fires as you reach roof A (same moment the rooftop door can trigger).
	scareZone = { center = { 34, 29, 0 }, size = { 16, 10, 20 } },

	backdrop = {
		-- Resting position (bottom edge at y = 9.5, comfortably above head height).
		panel = { center = { 146, 21.5, 0 }, size = { 1, 24, 22 } },
		trigger = { center = { 136, 5, 0 }, size = { 20, 10, 22 } },
	},

	-- The scare puppet walks behind the upstairs windows (root height).
	windowWalk = { from = { 48, 31, 15.5 }, to = { 84, 31, 15.5 } },
}
