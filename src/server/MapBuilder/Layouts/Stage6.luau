--!strict
--[[
	Stage 6 — Opening Night.
	The finale on the main stage, in front of a full house. The whole cast chases you (your
	Copycat, three Understudies and your reflection), the set collapses under your feet as
	you cross the risers, and five exit doors wait at the back of the stage. Only one is real.

	Signature scare (on the main stage): the house lights come up and the audience is all
	mannequins. They stand.
	Pure data: no requires.
]]

local route = {
	{ id = "Wings", kind = "Platform", center = { 10, 10, 0 }, size = { 16, 2, 14 }, link = "Start" },
	{ id = "Riser1", kind = "Step", center = { 24, 11, 0 }, size = { 6, 2, 10 }, link = "Jump", collapse = true },
	{ id = "Riser2", kind = "Step", center = { 33, 12, 0 }, size = { 6, 2, 10 }, link = "Jump", collapse = true },
	{ id = "Riser3", kind = "Step", center = { 42, 13, 0 }, size = { 6, 2, 10 }, link = "Jump", collapse = true },
	{ id = "Bridge", kind = "Landing", center = { 54, 13, 0 }, size = { 10, 2, 12 }, link = "Jump" },
	{ id = "Flat1", kind = "Step", center = { 66, 12, 0 }, size = { 6, 2, 10 }, link = "Jump", collapse = true },
	{ id = "Flat2", kind = "Step", center = { 75, 11, 0 }, size = { 6, 2, 10 }, link = "Jump", collapse = true },
	{ id = "Flat3", kind = "Step", center = { 84, 10, 0 }, size = { 6, 2, 10 }, link = "Jump", collapse = true },
	{ id = "MainStage", kind = "Floor", center = { 109, 8, 0 }, size = { 40, 2, 44 }, link = "Jump" },
}

local exits = {}
for i, z in { -16, -8, 0, 8, 16 } do
	table.insert(exits, {
		name = "Finale" .. i,
		door = { pos = { 128.9, 9, z }, facing = { -1, 0, 0 } },
		zone = { center = { 126, 13, z }, size = { 5, 8, 6 } },
		canBeReal = true,
	})
end

return {
	name = "Stage6_OpeningNight",
	room = { min = { -6, -6, -30 }, max = { 130, 50, 30 } },
	net = { center = { 62, -4.5, 0 }, size = { 140, 1, 62 } },
	spawn = { pos = { 5, 14, 0 }, facing = { 1, 0, 0 } },
	mannequinHome = { pos = { 3, 14, -5 }, facing = { 1, 0, 0 } },

	route = route,
	trusses = {},
	solids = {
		-- Flat the wing door is set into (beside the bridge).
		{ name = "WingFlat", center = { 54, 20, -7.7 }, size = { 10, 14, 1 }, surface = "Plaster" },
		-- Flat at the side of the main stage holding the door it steps out of.
		{ name = "PortalFlat", center = { 100, 15, -23.5 }, size = { 12, 14, 1 }, surface = "Plaster" },
	},
	doors = {
		{
			id = "S6_WingDoor",
			entry = { pos = { 54, 14, -7.1 }, facing = { 0, 0, 1 } },
			exit = { pos = { 100, 9, -22.9 }, facing = { 0, 0, 1 } },
			trigger = { center = { 54, 19, 0 }, size = { 10, 10, 12 } },
			entryPoint = { 54, 17, -9.1 },
			path = { { 54, 17, -10.1 }, { 100, 12, -25 }, { 100, 12, -24 } },
			exitStep = { 100, 12, -16 },
			pathSpeed = 24,
		},
	},

	scareZone = { center = { 100, 12, 0 }, size = { 10, 10, 40 } },
	exits = exits,
}
