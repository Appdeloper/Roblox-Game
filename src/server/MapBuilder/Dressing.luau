--!strict
--[[
	Dressing — per-stage set decoration (signs, lights, props). Nothing here changes the
	walkable route; everything decorative is non-colliding. Keep light counts low for mobile:
	roughly 6–10 active lights per room.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local LayoutTypes = require(script.Parent.LayoutTypes)
local Builders = require(script.Parent.Builders)
local Props = require(script.Parent.Props)
local Auditorium = require(script.Parent.Set.Auditorium)
local Backstage = require(script.Parent.Set.Backstage)
local CurtainCall = require(script.Parent.Set.CurtainCall)
local Story = require(script.Parent.Set.Story)
local Street = require(script.Parent.Set.Street)

type Layout = LayoutTypes.Layout

local Dressing = {}

--- Deterministic per-stage randomness for set dressing.
local function rngFor(stage: number): Random
	return Random.new(Config.Map.VisualSeed + stage * 101)
end

local function roomCenterAndSize(layout: Layout, origin: Vector3): (Vector3, Vector3)
	local min = origin + Builders.v(layout.room.min)
	local max = origin + Builders.v(layout.room.max)
	return (min + max) / 2, max - min
end

local function dust(model: Model, layout: Layout, origin: Vector3)
	local center, size = roomCenterAndSize(layout, origin)
	Props.dust(model, center, size * 0.9, Config.Effects.DustRate, Assets.uri(Assets.Images.DustParticle.Id))
end

--- A teal "moonlight" disc high on a wall: the cool key light of every room.
local function moonWindow(parent: Instance, position: Vector3, facing: Vector3, range: number)
	local disc = Builders.part({
		name = "MoonWindow",
		size = Vector3.new(0.4, 9, 9),
		cframe = CFrame.lookAt(position, position + facing) * CFrame.Angles(0, math.rad(90), 0),
		parent = parent,
		surface = "MoonGlow",
		decor = true,
	})
	disc.Shape = Enum.PartType.Cylinder
	Builders.pointLight(disc, Theme.Colors.MoonTeal, range, 1.6)
end

local function exitArch(parent: Instance, base: CFrame, label: string)
	for _, side in { -1, 1 } do
		Builders.part({
			name = "ArchPost",
			size = Vector3.new(0.4, 9, 0.4),
			cframe = base * CFrame.new(side * 3.2, 4.5, 0),
			parent = parent,
			surface = "WarmGlow",
			decor = true,
		})
	end
	Props.sign(parent, base * CFrame.new(0, 10, 0), Vector3.new(7, 1.6, 0.3), label, Theme.Colors.WarmSpot, "Iron")
end

function Dressing.stage1(model: Model, layout: Layout, origin: Vector3, route: { [string]: BasePart })
	local set = Builders.folder("Dressing", model)
	local story = Builders.folder("Story", model)
	Auditorium.build({ set = set, origin = origin, rng = rngFor(1), route = route })
	Story.byStage[1]({ set = story, origin = origin, rng = rngFor(1 + 10) })
	-- Footlights along the stage lip (inside the proscenium pillars); warm spots above.
	-- Two runs with a deliberate gap where the prop trunks meet the stage: the missing
	-- footlights read as "this is the way up" and keep the climb visually clear.
	-- Centre stage, with the empty house behind you.
	if route.Stage then
		Props.photoSpot(set, route.Stage, 6, -12, Vector3.new(-14, 7, 6))
	end
	Props.footlights(set, origin + Vector3.new(102.2, 21.4, -19), origin + Vector3.new(102.2, 21.4, -1), 11, 4)
	Props.footlights(set, origin + Vector3.new(102.2, 21.4, 15), origin + Vector3.new(102.2, 21.4, 19), 4, 3)
	for _, z in { -14, 14 } do
		Props.stageSpot(
			set,
			origin + Vector3.new(118, 43, z),
			origin + Vector3.new(128, 22, 0),
			Theme.Colors.WarmSpot,
			60
		)
	end
	-- Above the back balcony (y 30..33).
	moonWindow(set, origin + Vector3.new(-5.6, 39, 0), Vector3.xAxis, 120)
	-- Exit glows in the back curtain.
	exitArch(set, CFrame.lookAt(origin + Vector3.new(156.8, 22, 0), origin + Vector3.new(0, 22, 0)), "BACKSTAGE")
	Props.sign(
		set,
		CFrame.lookAt(origin + Vector3.new(8, 16, -6.9), origin + Vector3.new(8, 16, 10)),
		Vector3.new(8, 2, 0.3),
		"HOP THE SEATS →",
		Theme.Colors.Paper,
		"DarkWood"
	)
	dust(model, layout, origin)
end

local SHOP_SIGNS = { "BAKERY", "HATS & CAPS", "BOOKS", "TOY SHOP" }

function Dressing.stage2(model: Model, layout: Layout, origin: Vector3, route: { [string]: BasePart })
	local set = Builders.folder("Dressing", model)
	local story = Builders.folder("Story", model)
	Street.build({ set = set, origin = origin, rng = rngFor(2), route = route })
	Story.byStage[2]({ set = story, origin = origin, rng = rngFor(2 + 10) })
	for i, id in { "RoofA", "RoofB", "RoofC", "RoofD" } do
		local roof = route[id]
		if roof then
			local front = roof.CFrame.Position + Vector3.new(0, -4, -roof.Size.Z / 2 - 0.3)
			Props.sign(
				set,
				CFrame.lookAt(front, front - Vector3.zAxis),
				Vector3.new(math.min(12, roof.Size.X - 2), 2.4, 0.3),
				SHOP_SIGNS[i],
				Theme.Colors.Paper,
				"DarkWood"
			)
		end
	end
	-- Warm glass in the upstairs windows (non-colliding, see-through).
	for _, x in { 51, 61, 71, 81 } do
		Builders.part({
			name = "WindowGlass",
			size = Vector3.new(6, 7, 0.1),
			cframe = CFrame.new(origin + Vector3.new(x, 33.5, 12.2)),
			parent = set,
			surface = "Glass",
			transparency = 0.75,
			decor = true,
		})
	end
	-- Wall lanterns on the painted facade (the roofs you run across stay completely clear).
	for _, x in { 46, 86 } do
		local bracket = origin + Vector3.new(x, 27.5, 11.4)
		Builders.part({
			name = "LanternBracket",
			size = Vector3.new(0.3, 0.3, 1.6),
			cframe = CFrame.new(bracket),
			parent = set,
			surface = "Iron",
			decor = true,
		})
		local lamp = Builders.part({
			name = "StreetLamp",
			size = Vector3.new(1.1, 1.4, 1.1),
			cframe = CFrame.new(bracket - Vector3.new(0, 0.9, 0.7)),
			parent = set,
			surface = "WarmGlow",
			decor = true,
			tag = "FlickerLamp",
		})
		Builders.pointLight(lamp, Theme.Colors.WarmSpot, 26, 1.5)
	end
	Props.stageSpot(set, origin + Vector3.new(137, 40, -14), origin + Vector3.new(140, 1, 0), Theme.Colors.WarmSpot, 50)
	moonWindow(set, origin + Vector3.new(72, 50, 11.8), -Vector3.zAxis, 140)
	Props.sign(
		set,
		CFrame.lookAt(origin + Vector3.new(19.6, 8, -2.5), origin + Vector3.new(0, 8, -2.5)),
		Vector3.new(0.3, 2, 4),
		"UP ↑",
		Theme.Colors.Paper,
		"DarkWood"
	)
	exitArch(set, CFrame.lookAt(origin + Vector3.new(175.8, 1, 0), origin + Vector3.new(0, 1, 0)), "STAGE DOOR")
	dust(model, layout, origin)
end

local function staircaseStringers(set: Instance, origin: Vector3)
	-- Two slanted beams per flight make the cardboard steps read as a staircase.
	for _, flight in { { 21, 40, 50, 25 }, { 62, 23, 91, 8 } } do
		local a = origin + Vector3.new(flight[1], flight[2] - 1.5, 0)
		local b = origin + Vector3.new(flight[3], flight[4] - 1.5, 0)
		for _, z in { -5.9, 5.9 } do
			local pa, pb = a + Vector3.new(0, 0, z), b + Vector3.new(0, 0, z)
			Builders.part({
				name = "Stringer",
				size = Vector3.new(0.4, 0.8, (pb - pa).Magnitude),
				cframe = CFrame.lookAt((pa + pb) / 2, pb),
				parent = set,
				surface = "DarkWood",
				decor = true,
			})
		end
	end
end

function Dressing.stage3(model: Model, layout: Layout, origin: Vector3, route: { [string]: BasePart })
	local set = Builders.folder("Dressing", model)
	-- In front of the two doors: which one is real? (the photo doesn't tell)
	if route.MainStage then
		Props.photoSpot(set, route.MainStage, 6, -14, Vector3.new(-12, 6, 4))
	end
	local story = Builders.folder("Story", model)
	CurtainCall.build({ set = set, origin = origin, rng = rngFor(3), route = route })
	Story.byStage[3]({ set = story, origin = origin, rng = rngFor(3 + 10) })
	staircaseStringers(set, origin)
	Props.footlights(set, origin + Vector3.new(91.2, 5.4, -19), origin + Vector3.new(91.2, 5.4, 19), 14, 5)
	Props.stageSpot(set, origin + Vector3.new(110, 50, 0), origin + Vector3.new(134, 6, 0), Theme.Colors.WarmSpot, 70)
	Props.stageSpot(set, origin + Vector3.new(30, 54, 0), origin + Vector3.new(56, 23, 0), Theme.Colors.WarmSpot, 60)
	moonWindow(set, origin + Vector3.new(-5.6, 46, 0), Vector3.xAxis, 140)
	Props.sign(
		set,
		CFrame.lookAt(origin + Vector3.new(135.8, 30, 0), origin + Vector3.new(0, 30, 0)),
		Vector3.new(0.3, 4, 24),
		"CURTAIN CALL",
		Theme.Colors.Brass,
		"Curtain"
	)
	dust(model, layout, origin)
end

--- Acts IV–VI share one shape: a set builder, a moon window and dust.
local function backstageStage(index: number, build: (Backstage.Ctx) -> ())
	return function(model: Model, layout: Layout, origin: Vector3, route: { [string]: BasePart })
		local set = Builders.folder("Dressing", model)
		-- Each act's last platform gets a photo spot, facing back over the stage you crossed.
		local last = route[layout.route[#layout.route].id]
		if last then
			Props.photoSpot(set, last, 2, -4, Vector3.new(10, 6, 8))
		end
		build({ set = set, origin = origin, rng = rngFor(index) })
		moonWindow(set, origin + Vector3.new(-5.6, layout.room.max[2] - 10, 0), Vector3.xAxis, 140)
		dust(model, layout, origin)
	end
end

Dressing.stage4 = backstageStage(4, Backstage.flies)
Dressing.stage5 = backstageStage(5, Backstage.propRoom)
Dressing.stage6 = backstageStage(6, Backstage.openingNight)

Dressing.byStage =
	{ Dressing.stage1, Dressing.stage2, Dressing.stage3, Dressing.stage4, Dressing.stage5, Dressing.stage6 }

return Dressing
