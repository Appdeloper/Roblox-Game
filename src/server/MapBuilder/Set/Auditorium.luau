--!strict
--[[
	Auditorium (Stage 1 set) — the toy-diorama school theatre:
	  * a sea of curved velvet seat rows in the mist under the route
	  * aisle carpets, a high back balcony, opera boxes on both walls
	  * gilded wall panels, a proscenium arch with gathered curtains and a valance
	  * a plank stage floor and a fly-loft rig above the stage
	All of it is decorative (non-colliding) and kept out of the jump corridor
	(tests/smoke/clearance.spec.luau proves it).
]]

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)
local SetPieces = require(script.Parent.Parent.SetPieces)
local Builders = require(script.Parent.Parent.Builders)

local Auditorium = {}

export type Ctx = {
	set: Instance,
	origin: Vector3,
	rng: Random,
	route: { [string]: BasePart },
}

local function L(ctx: Ctx, x: number, y: number, z: number): Vector3
	return ctx.origin + Vector3.new(x, y, z)
end

local function seating(ctx: Ctx)
	local o = ctx.origin
	SetPieces.seatArcs(ctx.set, ctx.rng, L(ctx, 128, 1, 0), o.Y + 1, 34, 128, 6, {
		minX = o.X - 3,
		maxX = o.X + 95,
		minZ = o.Z - 24,
		maxZ = o.Z + 24,
	}, { o.Z - 9, o.Z + 9 })
	for _, z in { -9, 9 } do
		SetPieces.tornCarpet(ctx.set, ctx.rng, L(ctx, -4, 1.03, z), L(ctx, 96, 1.03, z), 2.4)
	end
end

--- Back balcony: high (y 30) and only over x -6..2, behind the spawn, so the default camera
--- behind the player never ends up inside it.
local function balcony(ctx: Ctx)
	Builders.part({
		name = "Balcony",
		size = Vector3.new(8, 1, 52),
		cframe = CFrame.new(L(ctx, -2, 30, 0)),
		parent = ctx.set,
		surface = "AgedWood",
		decor = true,
	})
	Builders.part({
		name = "BalconyFascia",
		size = Vector3.new(0.3, 1.4, 52),
		cframe = CFrame.new(L(ctx, 2.15, 29.9, 0)),
		parent = ctx.set,
		surface = "Gilt",
		decor = true,
	})
	SetPieces.railing(ctx.set, L(ctx, 1.6, 30.5, -25), L(ctx, 1.6, 30.5, 25), 2.6, 3)
	for z = -23, 23, 2.1 do
		local pos = L(ctx, -2.5, 30.5, z)
		SetPieces.seat(ctx.set, CFrame.lookAt(pos, pos + Vector3.xAxis), ctx.rng)
	end
end

--- Opera box on a side wall. `side` = -1 for the left wall (z = -26), +1 for the right.
local function operaBox(ctx: Ctx, x: number, side: number)
	local wallZ = side * 26
	local depth = 3.5
	local inner = wallZ - side * depth
	local y = 27
	Builders.part({
		name = "OperaBoxFloor",
		size = Vector3.new(8, 0.6, depth),
		cframe = CFrame.new(L(ctx, x, y, wallZ - side * depth / 2)),
		parent = ctx.set,
		surface = "AgedWood",
		decor = true,
	})
	Builders.part({
		name = "OperaBoxFascia",
		size = Vector3.new(8.4, 1.6, 0.3),
		cframe = CFrame.new(L(ctx, x, y - 0.6, inner)),
		parent = ctx.set,
		surface = "Gilt",
		decor = true,
	})
	SetPieces.railing(ctx.set, L(ctx, x - 4, y + 0.3, inner), L(ctx, x + 4, y + 0.3, inner), 2.2, 2.6)
	for _, dx in { -3.6, 3.6 } do
		SetPieces.stripCurtain(
			ctx.set,
			"OperaBoxCurtain",
			L(ctx, x + dx, y + 4.5, inner + side * 0.3),
			Vector3.new(1.2, 7, 0.4),
			0.7
		)
	end
end

--- Three high windows on the house-left wall, each throwing a shaft of moonlight down into
--- the seats. The shafts land BEHIND the row of platforms (z < -13) so they never wash over
--- the jump path or hide a landing.
local function moonlight(ctx: Ctx)
	for _, x in { 26, 56, 86 } do
		local sill = L(ctx, x, 38, -25.8)
		local facing = CFrame.lookAt(sill, sill + Vector3.zAxis)
		SetPieces.windowFrame(ctx.set, facing, 7, 9, false)
		Builders.part({
			name = "MoonPane",
			size = Vector3.new(7, 9, 0.12),
			cframe = facing * CFrame.new(0, 0, -0.06),
			parent = ctx.set,
			surface = "MoonGlow",
			decor = true,
		})
		SetPieces.lightShaft(ctx.set, sill, L(ctx, x + 9, 1.1, -15), 7, "MoonShaft", nil, 5)
	end
end

--- The one seat in the front row someone should have been sitting in, picked out by a
--- narrow warm spot. Sits in the house, clear of the orchestra rail above it.
local function emptySeat(ctx: Ctx)
	local pos = L(ctx, 94, 1, -3)
	SetPieces.seat(ctx.set, CFrame.lookAt(pos, Vector3.new(ctx.origin.X + 128, pos.Y, pos.Z)), ctx.rng)
	SetPieces.narrowingBeam(ctx.set, L(ctx, 94, 26, -3), L(ctx, 94, 4.5, -3), 3.2, 1.7, 4, "WarmBeam")
end

local function wallPanels(ctx: Ctx)
	local o = ctx.origin
	-- Left wall (z = -26): skip the opera boxes at x 40 and 72.
	SetPieces.wallPanels(
		ctx.set,
		Vector3.new(o.X + 8, o.Y, o.Z - 25.85),
		Vector3.new(o.X + 100, o.Y, o.Z - 25.85),
		Vector3.zAxis,
		o.Y + 32,
		o.Y + 42,
		9,
		{ { 27, 37 }, { 59, 69 } }
	)
	-- Right wall (z = +26): skip the boxes at x 30 and 75 (doors are lower, under y 24).
	SetPieces.wallPanels(
		ctx.set,
		Vector3.new(o.X + 8, o.Y, o.Z + 25.85),
		Vector3.new(o.X + 100, o.Y, o.Z + 25.85),
		-Vector3.zAxis,
		o.Y + 32,
		o.Y + 42,
		9,
		{ { 17, 27 }, { 62, 72 } }
	)
end

local function proscenium(ctx: Ctx)
	local base = CFrame.lookAt(L(ctx, 104, 22, 0), L(ctx, 0, 22, 0))
	SetPieces.proscenium(ctx.set, base, 40, 20, 6, 2, 4)
	for _, z in { -18.4, 18.4 } do
		SetPieces.stripCurtain(ctx.set, "ProsceniumCurtain", L(ctx, 105.6, 32, z), Vector3.new(1.2, 20, 3.2), 1)
	end
	SetPieces.valance(ctx.set, L(ctx, 105.6, 40.6, 0), Vector3.new(1, 2.8, 40))
end

local function stageFloor(ctx: Ctx)
	local stage = ctx.route.Stage
	if stage then
		SetPieces.plankFloor(ctx.set, stage.CFrame, stage.Size, ctx.rng)
	end
	SetPieces.rigging(ctx.set, ctx.rng, ctx.origin.X + 107, ctx.origin.X + 156, {
		ctx.origin.Z - 16,
		ctx.origin.Z,
		ctx.origin.Z + 16,
	}, ctx.origin.Y + 44, 8, ctx.origin.Y + 35)
end

function Auditorium.build(ctx: Ctx)
	seating(ctx)
	balcony(ctx)
	for _, spec in { { 40, -1 }, { 72, -1 }, { 30, 1 }, { 75, 1 } } do
		operaBox(ctx, spec[1], spec[2])
	end
	wallPanels(ctx)
	proscenium(ctx)
	stageFloor(ctx)
	moonlight(ctx)
	emptySeat(ctx)
	-- Signature fill: the house reads cold and teal, so the warm stage pops against it.
	for _, x in { 30, 74 } do
		local fill = Builders.part({
			name = "HouseFill",
			size = Vector3.one,
			cframe = CFrame.new(L(ctx, x, 30, -6)),
			parent = ctx.set,
			surface = "Invisible",
			decor = true,
		})
		Builders.pointLight(fill, Theme.Colors.MoonTeal, 60, 0.75)
	end
end

return Auditorium
