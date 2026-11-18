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

type Layout = LayoutTypes.Layout

local Dressing = {}

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
		color = Theme.Colors.MoonTeal,
		material = Enum.Material.Neon,
		collide = false,
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
			color = Theme.Colors.WarmSpot,
			material = Enum.Material.Neon,
			collide = false,
		})
	end
	Props.sign(
		parent,
		base * CFrame.new(0, 10, 0),
		Vector3.new(7, 1.6, 0.3),
		label,
		Theme.Colors.WarmSpot,
		Theme.Colors.UiDark
	)
end

function Dressing.stage1(model: Model, layout: Layout, origin: Vector3, _route: { [string]: BasePart })
	local set = Builders.folder("Dressing", model)
	-- Footlights along the stage lip; warm spots from the grid above.
	Props.footlights(set, origin + Vector3.new(102.2, 22.3, -24), origin + Vector3.new(102.2, 22.3, 24), 16, 5)
	for _, z in { -14, 14 } do
		Props.stageSpot(
			set,
			origin + Vector3.new(118, 43, z),
			origin + Vector3.new(128, 22, 0),
			Theme.Colors.WarmSpot,
			60
		)
	end
	moonWindow(set, origin + Vector3.new(-5.6, 30, 0), Vector3.xAxis, 120)
	-- Exit glows in the back curtain.
	exitArch(set, CFrame.lookAt(origin + Vector3.new(156.8, 22, 0), origin + Vector3.new(0, 22, 0)), "BACKSTAGE")
	Props.sign(
		set,
		CFrame.lookAt(origin + Vector3.new(8, 16, -6.9), origin + Vector3.new(8, 16, 10)),
		Vector3.new(8, 2, 0.3),
		"HOP THE SEATS →",
		Theme.Colors.Paper,
		Theme.Colors.DarkWood
	)
	dust(model, layout, origin)
end

local SHOP_SIGNS = { "BAKERY", "HATS & CAPS", "BOOKS", "TOY SHOP" }

function Dressing.stage2(model: Model, layout: Layout, origin: Vector3, route: { [string]: BasePart })
	local set = Builders.folder("Dressing", model)
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
				Theme.Colors.DarkWood
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
			color = Theme.Colors.Window,
			material = Enum.Material.Glass,
			transparency = 0.75,
			collide = false,
		})
	end
	-- Two street lamps on the roofs, one warm light over the landing.
	for _, pos in { Vector3.new(54, 25.5, -8), Vector3.new(92, 26, -8) } do
		local lamp = Builders.part({
			name = "StreetLamp",
			size = Vector3.new(0.8, 0.8, 0.8),
			cframe = CFrame.new(origin + pos + Vector3.new(0, 6, 0)),
			parent = set,
			color = Theme.Colors.WarmSpot,
			material = Enum.Material.Neon,
			collide = false,
		})
		Builders.pointLight(lamp, Theme.Colors.WarmSpot, 22, 1.4)
		Builders.part({
			name = "LampPost",
			size = Vector3.new(0.4, 6, 0.4),
			cframe = CFrame.new(origin + pos + Vector3.new(0, 3, 0)),
			parent = set,
			color = Theme.Colors.UiDark,
			material = Enum.Material.Metal,
			collide = false,
		})
	end
	Props.stageSpot(set, origin + Vector3.new(137, 40, -14), origin + Vector3.new(140, 1, 0), Theme.Colors.WarmSpot, 50)
	moonWindow(set, origin + Vector3.new(72, 50, 11.8), -Vector3.zAxis, 140)
	Props.sign(
		set,
		CFrame.lookAt(origin + Vector3.new(19.6, 8, -2.5), origin + Vector3.new(0, 8, -2.5)),
		Vector3.new(0.3, 2, 4),
		"UP ↑",
		Theme.Colors.Paper,
		Theme.Colors.DarkWood
	)
	exitArch(set, CFrame.lookAt(origin + Vector3.new(175.8, 1, 0), origin + Vector3.new(0, 1, 0)), "STAGE DOOR")
	dust(model, layout, origin)
end

local function staircaseStringers(set: Instance, origin: Vector3)
	-- Two slanted beams per flight make the cardboard steps read as a staircase.
	for _, flight in { { 21, 40, 50, 25 }, { 62, 23, 91, 8 } } do
		local a = origin + Vector3.new(flight[1], flight[2] - 1.5, 0)
		local b = origin + Vector3.new(flight[3], flight[4] - 1.5, 0)
		for _, z in { -5.2, 5.2 } do
			local pa, pb = a + Vector3.new(0, 0, z), b + Vector3.new(0, 0, z)
			Builders.part({
				name = "Stringer",
				size = Vector3.new(0.4, 0.8, (pb - pa).Magnitude),
				cframe = CFrame.lookAt((pa + pb) / 2, pb),
				parent = set,
				color = Theme.Colors.DarkWood,
				material = Enum.Material.Wood,
				collide = false,
			})
		end
	end
end

local function emptyAudience(set: Instance, origin: Vector3)
	-- Rows of empty seats below the staircase — where the applause comes from.
	for row = 0, 5 do
		for _, z in { -19, 19 } do
			Builders.part({
				name = "AudienceRow",
				size = Vector3.new(2, 2.5, 10),
				cframe = CFrame.new(origin + Vector3.new(24 + row * 10, -2.5, z)),
				parent = set,
				color = Theme.Colors.SeatVelvet,
				material = Enum.Material.Fabric,
				collide = false,
				tag = "AudienceSeat",
			})
		end
	end
end

function Dressing.stage3(model: Model, layout: Layout, origin: Vector3, _route: { [string]: BasePart })
	local set = Builders.folder("Dressing", model)
	staircaseStringers(set, origin)
	emptyAudience(set, origin)
	Props.footlights(set, origin + Vector3.new(93, 6.3, -19), origin + Vector3.new(93, 6.3, 19), 14, 5)
	Props.stageSpot(set, origin + Vector3.new(110, 50, 0), origin + Vector3.new(134, 6, 0), Theme.Colors.WarmSpot, 70)
	Props.stageSpot(set, origin + Vector3.new(30, 54, 0), origin + Vector3.new(56, 23, 0), Theme.Colors.WarmSpot, 60)
	moonWindow(set, origin + Vector3.new(-5.6, 46, 0), Vector3.xAxis, 140)
	Props.sign(
		set,
		CFrame.lookAt(origin + Vector3.new(135.8, 30, 0), origin + Vector3.new(0, 30, 0)),
		Vector3.new(0.3, 4, 24),
		"CURTAIN CALL",
		Theme.Colors.Brass,
		Theme.Colors.Curtain
	)
	dust(model, layout, origin)
end

Dressing.byStage = { Dressing.stage1, Dressing.stage2, Dressing.stage3 }

return Dressing
