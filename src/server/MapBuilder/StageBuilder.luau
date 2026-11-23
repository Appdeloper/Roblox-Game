--!strict
--[[
	StageBuilder — turns a pure-data layout (./Layouts) into Parts and returns the server-side
	StageInfo (spawn CFrames, zones, door paths). Stage-specific set dressing lives in ./Dressing.

	Clients discover interactive pieces through CollectionService tags; every tagged instance
	also carries a "Stage" attribute so clients can filter by the stage they are in.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Types = require(ReplicatedStorage.Shared.Types)
local LayoutTypes = require(script.Parent.LayoutTypes)
local Builders = require(script.Parent.Builders)
local Props = require(script.Parent.Props)
local SetPieces = require(script.Parent.SetPieces)
local LayoutValidator = require(script.Parent.LayoutValidator)

type Layout = LayoutTypes.Layout
type RouteBox = LayoutTypes.RouteBox

local StageBuilder = {}

-- Walkable route surfaces (Theme "Route*" = lighter + warmer than the set around them).
local ROUTE_SURFACE: { [string]: string } = {
	Platform = "RouteWood",
	Landing = "RouteWood",
	Floor = "RouteFloor",
	SeatRow = "RouteWood",
	Roof = "RouteRoof",
	Step = "RouteCardboard",
	Slide = "RouteSlide",
}
local SHOP_FACADES = { "FacadeRose", "FacadeSage", "FacadeOchre" }
local TAPED: { [string]: boolean } = { Platform = true, Landing = true, SeatRow = true, Roof = true }

local ROOF_CAP = 0.6

type Ctx = {
	index: number,
	layout: Layout,
	origin: Vector3,
	model: Model,
	floorY: number,
}

local function w(ctx: Ctx, v: { number }): Vector3
	return ctx.origin + Builders.v(v)
end

local function zone(ctx: Ctx, box: LayoutTypes.Box?): Types.ZoneInfo?
	if not box then
		return nil
	end
	return { cframe = CFrame.new(w(ctx, box.center)), size = Builders.v(box.size) }
end

local function placement(ctx: Ctx, p: LayoutTypes.Placement): CFrame
	local pos = w(ctx, p.pos)
	return CFrame.lookAt(pos, pos + Builders.v(p.facing))
end

--- Floor, four walls and a ceiling around the layout's interior box.
function StageBuilder.room(parent: Instance, min: Vector3, max: Vector3)
	local size = max - min
	local center = (min + max) / 2
	local t = 2
	local shell = Builders.folder("Room", parent)
	local function slab(name: string, c: Vector3, s: Vector3, surface: string)
		Builders.part({ name = name, size = s, cframe = CFrame.new(c), parent = shell, surface = surface })
	end
	slab(
		"Floor",
		Vector3.new(center.X, min.Y - t / 2, center.Z),
		Vector3.new(size.X + 2 * t, t, size.Z + 2 * t),
		"AgedWood"
	)
	slab(
		"Ceiling",
		Vector3.new(center.X, max.Y + t / 2, center.Z),
		Vector3.new(size.X + 2 * t, t, size.Z + 2 * t),
		"Ceiling"
	)
	for _, sx in { -1, 1 } do
		local x = if sx < 0 then min.X - t / 2 else max.X + t / 2
		slab("WallX", Vector3.new(x, center.Y, center.Z), Vector3.new(t, size.Y, size.Z + 2 * t), "Plaster")
	end
	for _, sz in { -1, 1 } do
		local z = if sz < 0 then min.Z - t / 2 else max.Z + t / 2
		slab("WallZ", Vector3.new(center.X, center.Y, z), Vector3.new(size.X, size.Y, t), "Plaster")
	end
end

local function buildNet(ctx: Ctx)
	local net = ctx.layout.net
	local center = w(ctx, net.center)
	local size = Builders.v(net.size)
	Builders.part({
		name = "SafetyNet",
		size = size,
		cframe = CFrame.new(center),
		parent = ctx.model,
		surface = "Net",
		tag = "SafetyNet",
	})
	-- A low translucent fog layer hides the net and reads as "don't fall in".
	Builders.part({
		name = "FogLayer",
		size = Vector3.new(size.X, 0.2, size.Z),
		cframe = CFrame.new(center + Vector3.new(0, size.Y / 2 + 1.2, 0)),
		parent = ctx.model,
		surface = "Fog",
		transparency = 0.82,
		decor = true,
	})
end

local function buildSlide(ctx: Ctx, box: RouteBox, parent: Instance): BasePart
	local size = Builders.v(box.size)
	local toward = box.slopeToward or "+X"
	local alongX = toward == "+X" or toward == "-X"
	-- WedgePart local axes: X = width, Y = height, Z = length of the slope.
	local wedgeSize = if alongX then Vector3.new(size.Z, size.Y, size.X) else Vector3.new(size.X, size.Y, size.Z)
	local wedge = Builders.wedge({
		name = box.id,
		size = wedgeSize,
		cframe = Builders.slopeCFrame(w(ctx, box.center), toward),
		parent = parent,
		surface = ROUTE_SURFACE.Slide,
		tag = "SlideMat",
	})
	wedge.CustomPhysicalProperties = PhysicalProperties.new(0.7, Config.Hazards.SlideFriction, 0, 100, 1)
	wedge.CanQuery = true
	return wedge
end

local function buildRoof(ctx: Ctx, box: RouteBox, parent: Instance, index: number): BasePart
	local center, size = w(ctx, box.center), Builders.v(box.size)
	local body = Builders.part({
		name = box.id .. "_Shop",
		size = size - Vector3.new(0, ROOF_CAP, 0),
		cframe = CFrame.new(center - Vector3.new(0, ROOF_CAP / 2, 0)),
		parent = parent,
		surface = SHOP_FACADES[(index - 1) % #SHOP_FACADES + 1],
	})
	body.CastShadow = true
	return Builders.part({
		name = box.id,
		size = Vector3.new(size.X + 0.4, ROOF_CAP, size.Z + 0.4),
		cframe = CFrame.new(center + Vector3.new(0, size.Y / 2 - ROOF_CAP / 2, 0)),
		parent = parent,
		surface = ROUTE_SURFACE.Roof,
	})
end

--- Copies a Motion spec onto attributes (clients rebuild it with Movers.specOf).
local function setMotion(instance: Instance, spec: LayoutTypes.MotionSpec)
	instance:SetAttribute("Period", spec.period)
	instance:SetAttribute("Phase", spec.phase or 0)
	for _, key in { "amplitude", "min", "hold", "aim", "halfWidth" } do
		local value = (spec :: any)[key]
		if value ~= nil then
			instance:SetAttribute(string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2), value)
		end
	end
end

local function buildRouteBox(ctx: Ctx, box: RouteBox, parent: Instance, order: number): BasePart
	if box.kind == "Slide" then
		return buildSlide(ctx, box, parent)
	elseif box.kind == "Roof" then
		return buildRoof(ctx, box, parent, order)
	end
	local cframe = CFrame.new(w(ctx, box.center)) * CFrame.Angles(0, 0, math.rad(box.tilt or 0))
	local part = Builders.part({
		name = box.id,
		size = Builders.v(box.size),
		cframe = cframe,
		parent = parent,
		surface = ROUTE_SURFACE[box.kind] or ROUTE_SURFACE.Platform,
	})
	part.CastShadow = true
	if box.collapse then
		CollectionService:AddTag(part, "CollapseStep")
		part:SetAttribute("Order", order)
	end
	if box.pulse then
		-- Clients shrink/grow it from server time (shared/Motion); full size is the layout size.
		CollectionService:AddTag(part, "PulseProp")
		setMotion(part, box.pulse)
		part:SetAttribute("BaseSize", part.Size)
	end
	if box.conveyor then
		-- An anchored part with a velocity carries characters standing on it.
		local velocity = Builders.v(box.conveyor)
		part.AssemblyLinearVelocity = velocity
		part:SetAttribute("ConveyorVelocity", velocity)
		CollectionService:AddTag(part, "Conveyor")
	end
	return part
end

--- Lighting as a signpost. A warm lamp hangs high over every landing and over the first
--- and last step of a stage, so the safe line through the room is the lit line. Lamps sit
--- well above head height, outside the jump corridor.
local function guideLight(part: BasePart, parent: Instance)
	local host = Builders.part({
		name = "GuideLight",
		size = Vector3.one,
		cframe = CFrame.new(part.CFrame.Position + Vector3.new(0, part.Size.Y / 2 + 9, 0)),
		parent = parent,
		surface = "Invisible",
		decor = true,
		tag = "GuideLamp",
	})
	Builders.pointLight(host, Theme.Colors.WarmSpot, 26, 1.1)
end

--- The drop is cold and unlit: teal fill far below the route marks the danger.
local function pitLight(ctx: Ctx, parent: Instance)
	local net = ctx.layout.net
	for _, fraction in { 0.3, 0.7 } do
		local x = net.center[1] + (fraction - 0.5) * net.size[1] * 0.7
		local host = Builders.part({
			name = "PitLight",
			size = Vector3.one,
			cframe = CFrame.new(w(ctx, { x, net.center[2] + 6, net.center[3] })),
			parent = parent,
			surface = "Invisible",
			decor = true,
		})
		Builders.pointLight(host, Theme.Colors.MoonTeal, 50, 0.7)
	end
end

local function buildRoute(ctx: Ctx): { [string]: BasePart }
	local folder = Builders.folder("Route", ctx.model)
	local decor = Builders.folder("RouteDecor", ctx.model)
	local parts: { [string]: BasePart } = {}
	for order, box in ctx.layout.route do
		local part = buildRouteBox(ctx, box, folder, order)
		parts[box.id] = part
		if box.kind == "SeatRow" then
			Props.seatRowDressing(decor, part)
		end
		if box.kind == "Platform" or box.kind == "Landing" or box.kind == "SeatRow" then
			Props.supportPosts(decor, part, ctx.floorY)
		end
		-- Glow-tape lips on take-off/landing edges (collapsing steps get theirs as a SurfaceGui
		-- in the dressing, so the tape falls with the step).
		if TAPED[box.kind] then
			SetPieces.edgeTape(decor, part)
		end
		-- Landings and the two ends of the run get a warm lamp overhead.
		if box.kind == "Landing" or order == 1 or order == #ctx.layout.route then
			guideLight(part, decor)
		end
	end
	pitLight(ctx, decor)
	return parts
end

local function buildTrusses(ctx: Ctx)
	local decor = Builders.folder("LadderMarks", ctx.model)
	for i, box in ctx.layout.trusses do
		local centre = w(ctx, box.center)
		local size = Builders.v(box.size)
		Builders.truss({
			name = "Ladder" .. i,
			size = size,
			cframe = CFrame.new(centre),
			parent = ctx.model,
			surface = "Ladder",
			tag = "SceneryLadder",
		})
		-- Glow bands at the foot and the head of the climb, so "you go up here" and
		-- "this is where you get off" both read from across the room.
		for _, offset in { -size.Y / 2 + 0.6, size.Y / 2 - 0.6 } do
			Builders.part({
				name = "LadderMark",
				size = Vector3.new(size.X + 0.5, 0.3, size.Z + 0.5),
				cframe = CFrame.new(centre + Vector3.new(0, offset, 0)),
				parent = decor,
				surface = "GlowTape",
				decor = true,
			})
		end
	end
end

local function buildSolids(ctx: Ctx)
	local folder = Builders.folder("Set", ctx.model)
	for _, solid in ctx.layout.solids do
		local center, size = w(ctx, solid.center), Builders.v(solid.size)
		if solid.tag == "Curtain" then
			SetPieces.stripCurtain(folder, solid.name, center, size)
		elseif solid.windows then
			local band = {
				y1 = solid.windows.y1 + ctx.origin.Y,
				y2 = solid.windows.y2 + ctx.origin.Y,
				spans = {},
			}
			for _, span in solid.windows.spans do
				table.insert(band.spans, { span[1] + ctx.origin.X, span[2] + ctx.origin.X })
			end
			Builders.wallWithWindows(solid.name, folder, center, size, band, solid.surface)
		else
			Builders.part({
				name = solid.name,
				size = size,
				cframe = CFrame.new(center),
				parent = folder,
				surface = solid.surface,
				collide = solid.collide,
				transparency = solid.transparency,
				tag = solid.tag,
			})
		end
	end
end

local function buildDoors(ctx: Ctx): { Types.DoorInfo }
	local folder = Builders.folder("PaintedDoors", ctx.model)
	local infos: { Types.DoorInfo } = {}
	for _, door in ctx.layout.doors do
		Props.paintedDoor(folder, placement(ctx, door.entry), door.id, "Entry")
		Props.paintedDoor(folder, placement(ctx, door.exit), door.id, "Exit")
		local path = {}
		for _, p in door.path do
			table.insert(path, w(ctx, p))
		end
		local trigger = zone(ctx, door.trigger) :: Types.ZoneInfo
		table.insert(infos, {
			id = door.id,
			stage = ctx.index,
			triggerCFrame = trigger.cframe,
			triggerSize = trigger.size,
			entryPoint = w(ctx, door.entryPoint),
			path = path,
			exitStep = w(ctx, door.exitStep),
			exitFacing = Builders.v(door.exit.facing),
			pathSpeed = door.pathSpeed or Config.Door.DefaultPathSpeed,
		})
	end
	return infos
end

local function buildBackdrop(ctx: Ctx, routeParts: { [string]: BasePart })
	local backdrop = ctx.layout.backdrop
	if not backdrop then
		return
	end
	local panel = Builders.part({
		name = "DescendingBackdrop",
		size = Builders.v(backdrop.panel.size),
		cframe = CFrame.new(w(ctx, backdrop.panel.center)),
		parent = ctx.model,
		surface = "Backdrop",
		tag = "Backdrop",
	})
	panel.CastShadow = true
	-- The floor the backdrop closes onto: the surface directly beneath it.
	local landing = routeParts.Landing
	local floorTop = if landing
		then landing.CFrame.Position.Y + landing.Size.Y / 2
		else panel.CFrame.Position.Y - panel.Size.Y
	panel:SetAttribute("FloorY", floorTop)
	panel:SetAttribute("TriggerCFrame", CFrame.new(w(ctx, backdrop.trigger.center)))
	panel:SetAttribute("TriggerSize", Builders.v(backdrop.trigger.size))
	Builders.surfaceText(panel, Enum.NormalId.Left, "☾  ✦  ✧  ✦", Theme.Colors.Paper)
end

local function buildExits(ctx: Ctx)
	local exits = ctx.layout.exits
	if not exits then
		return
	end
	local folder = Builders.folder("Exits", ctx.model)
	for _, exit in exits do
		Props.exitDoor(folder, placement(ctx, exit.door), exit.name)
	end
end

-- ── Movers ────────────────────────────────────────────────────────────────────────────────
--- Moving hazards are built at rest and animated on every client from server time. On the
--- server they don't collide (Hazard attribute), so only the client's own physics meets them.

local function hazardPart(props: any): BasePart
	local part = Builders.part(props)
	part.CanCollide = false
	part.CanQuery = false
	part:SetAttribute("Hazard", true)
	return part
end

local function buildMovers(ctx: Ctx): { Types.SpinnerInfo }
	local spinners: { Types.SpinnerInfo } = {}
	local movers = ctx.layout.movers
	if not movers then
		return spinners
	end
	local folder = Builders.folder("Movers", ctx.model)
	for _, mover in movers do
		local model = Builders.model(mover.id, folder)
		model:SetAttribute("Kind", mover.kind)
		model:SetAttribute("Axis", mover.axis)
		setMotion(model, mover.motion)
		local center = w(ctx, mover.center)
		model:SetAttribute("Pivot", center)
		if mover.kind == "Pendulum" then
			local length = mover.ropeLength or 10
			model:SetAttribute("RopeLength", length)
			local bob = hazardPart({
				name = "Bob",
				size = Builders.v(mover.size),
				cframe = CFrame.new(center - Vector3.new(0, length, 0)),
				parent = model,
				surface = "Sandbag",
			})
			bob:SetAttribute("Solid", true)
			hazardPart({
				name = "Rope",
				size = Vector3.new(0.3, length, 0.3),
				cframe = CFrame.new(center - Vector3.new(0, length / 2, 0)),
				parent = model,
				surface = "Rope",
			})
		elseif mover.kind == "Slider" then
			local shelf = hazardPart({
				name = "Shelf",
				size = Builders.v(mover.size),
				cframe = CFrame.new(center),
				parent = model,
				surface = "DarkWood",
			})
			shelf:SetAttribute("Solid", true)
		elseif mover.kind == "Spinner" then
			local gate = mover.gate :: LayoutTypes.Box
			local gateCenter = w(ctx, gate.center)
			hazardPart({
				name = "Rig",
				size = Builders.v(mover.size),
				cframe = CFrame.new(center),
				parent = model,
				surface = "Iron",
			})
			-- The beam, built pointing at its gate; clients swing it around the rig.
			local target = Vector3.new(gateCenter.X, gateCenter.Y - gate.size[2] / 2, gateCenter.Z)
			local length = (target - center).Magnitude
			hazardPart({
				name = "Beam",
				size = Vector3.new(1.6, 1.6, length),
				cframe = CFrame.lookAt(center, target) * CFrame.new(0, 0, -length / 2),
				parent = model,
				surface = "WarmBeam",
			})
			-- The danger mark painted on the catwalk, so the gate reads before the beam arrives.
			hazardPart({
				name = "GateMark",
				size = Vector3.new(gate.size[1], 0.08, gate.size[3]),
				cframe = CFrame.new(gateCenter.X, gateCenter.Y - gate.size[2] / 2 + 0.05, gateCenter.Z),
				parent = model,
				surface = "GlowTape",
			})
			model:SetAttribute("Target", target)
			table.insert(spinners, {
				id = mover.id,
				motion = mover.motion,
				gate = zone(ctx, gate) :: Types.ZoneInfo,
			})
		end
		CollectionService:AddTag(model, "Mover")
	end
	return spinners
end

--- A tall soft-glowing column over a stage's exit, visible from the whole room, with an
--- EXIT sign on top: the one thing in every stage that says "this way". Doors with a choice
--- (stages 3 and 6) already carry EXIT signs, so they get no beacon (it would give the answer away).
local function buildExitBeacon(ctx: Ctx)
	local zoneBox = ctx.layout.exitZone
	if not zoneBox then
		return
	end
	local base = w(ctx, zoneBox.center) - Vector3.new(0, zoneBox.size[2] / 2, 0)
	local height = 24
	local column = Builders.part({
		name = "ExitBeacon",
		size = Vector3.new(height, 3, 3),
		cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		parent = ctx.model,
		surface = "WarmBeam",
		decor = true,
		tag = "ExitBeacon",
	})
	column.Shape = Enum.PartType.Cylinder
	column.Transparency = 0.72
	local sign = Builders.part({
		name = "ExitBeaconSign",
		size = Vector3.new(6, 2, 0.3),
		cframe = CFrame.lookAt(base + Vector3.new(0, 9, 0), base + Vector3.new(-1, 9, 0)),
		parent = ctx.model,
		surface = "ExitSign",
		decor = true,
	})
	Builders.surfaceText(sign, Enum.NormalId.Front, "EXIT ➜", Theme.Colors.UiDark, Theme.Fonts.Bold)
	Builders.pointLight(column, Theme.Colors.UiGood, 22, 1.2)
end

local function buildMarkers(ctx: Ctx)
	local layout = ctx.layout
	local spawn = placement(ctx, layout.spawn)
	local floor = spawn * CFrame.new(0, -Config.Map.SpawnHeight, 0)
	Props.spikeMark(ctx.model, CFrame.new(floor.Position))
	if layout.windowWalk then
		local marker = Builders.part({
			name = "WindowWalk",
			size = Vector3.one,
			cframe = CFrame.new(w(ctx, layout.windowWalk.from)),
			parent = ctx.model,
			surface = "Invisible",
			decor = true,
			tag = "WindowWalk",
		})
		marker:SetAttribute("From", w(ctx, layout.windowWalk.from))
		marker:SetAttribute("To", w(ctx, layout.windowWalk.to))
	end
end

--- Stamps every tagged descendant with its stage index for client-side filtering.
local function stampStage(model: Model, index: number)
	for _, d in model:GetDescendants() do
		if #CollectionService:GetTags(d) > 0 then
			d:SetAttribute("Stage", index)
		end
	end
	model:SetAttribute("Stage", index)
end

--- Mannequin-root-height points over the middle of every route box, in route order.
local function routePath(ctx: Ctx): { Vector3 }
	local points = {}
	for _, box in ctx.layout.route do
		local top = if box.kind == "Slide" then 0 else box.size[2] / 2
		table.insert(points, w(ctx, box.center) + Vector3.new(0, top + Config.Mannequin.RootHeight, 0))
	end
	return points
end

local function exitInfos(ctx: Ctx): { Types.ExitInfo }?
	local exits = ctx.layout.exits
	if not exits then
		return nil
	end
	local out: { Types.ExitInfo } = {}
	for _, exit in exits do
		table.insert(
			out,
			{ name = exit.name, zone = zone(ctx, exit.zone) :: Types.ZoneInfo, canBeReal = exit.canBeReal }
		)
	end
	return out
end

local function stageInfo(ctx: Ctx, doors: { Types.DoorInfo }, spinners: { Types.SpinnerInfo }): Types.StageInfo
	local layout = ctx.layout
	return {
		index = ctx.index,
		entrance = placement(ctx, layout.spawn),
		mannequinHome = placement(ctx, layout.mannequinHome),
		killY = ctx.origin.Y + LayoutValidator.killY(layout, Config.Map.KillMargin),
		exitZone = zone(ctx, layout.exitZone),
		scareZone = zone(ctx, layout.scareZone),
		doors = doors,
		routePath = routePath(ctx),
		exits = exitInfos(ctx),
		spinners = if #spinners > 0 then spinners else nil,
	}
end

export type Dresser = (model: Model, layout: Layout, origin: Vector3, routeParts: { [string]: BasePart }) -> ()

function StageBuilder.build(
	index: number,
	layout: Layout,
	origin: Vector3,
	parent: Instance,
	dress: Dresser?
): Types.StageInfo
	local model = Builders.model(layout.name, parent)
	local ctx: Ctx = {
		index = index,
		layout = layout,
		origin = origin,
		model = model,
		floorY = origin.Y + layout.room.min[2],
	}
	StageBuilder.room(model, w(ctx, layout.room.min), w(ctx, layout.room.max))
	buildNet(ctx)
	local routeParts = buildRoute(ctx)
	buildTrusses(ctx)
	buildSolids(ctx)
	local doors = buildDoors(ctx)
	buildBackdrop(ctx, routeParts)
	buildExits(ctx)
	local spinners = buildMovers(ctx)
	buildExitBeacon(ctx)
	buildMarkers(ctx)
	if dress then
		dress(model, layout, origin, routeParts)
	end
	stampStage(model, index)
	return stageInfo(ctx, doors, spinners)
end

return StageBuilder
