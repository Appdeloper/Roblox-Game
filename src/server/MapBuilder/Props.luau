--!strict
--[[
	Props — reusable set pieces (all original, built from primitives).

	Painted doors are the key readable prop: purple planks, a brass ★, a brass lever handle and
	a hidden glow strip under the door. Clients animate the handle/glow/opening locally when the
	server sends DoorWarning / DoorOpened, so each player only sees their own mannequin's door.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Builders = require(script.Parent.Builders)

local Props = {}

local DOOR_WIDTH = 5
local DOOR_HEIGHT = 8.6
local UNDER_GAP = 0.35

local function doorFrame(model: Model, base: CFrame)
	local jambSize = Vector3.new(0.5, DOOR_HEIGHT + UNDER_GAP + 0.5, 0.7)
	for _, side in { -1, 1 } do
		Builders.part({
			name = "Jamb",
			size = jambSize,
			cframe = base * CFrame.new(side * (DOOR_WIDTH / 2 + 0.25), jambSize.Y / 2, 0),
			parent = model,
			color = Theme.Colors.DarkWood,
			material = Enum.Material.Wood,
		})
	end
	Builders.part({
		name = "Lintel",
		size = Vector3.new(DOOR_WIDTH + 1, 0.5, 0.7),
		cframe = base * CFrame.new(0, DOOR_HEIGHT + UNDER_GAP + 0.25, 0),
		parent = model,
		color = Theme.Colors.DarkWood,
		material = Enum.Material.Wood,
	})
end

--- The door leaf (panel, star, handle) lives in its own model so clients can swing it on the hinge.
local function doorLeaf(model: Model, base: CFrame, starred: boolean, panelColor: Color3): Model
	local leaf = Builders.model("Leaf", model)
	local panel = Builders.part({
		name = "Panel",
		size = Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 0.3),
		cframe = base * CFrame.new(0, UNDER_GAP + DOOR_HEIGHT / 2, 0),
		parent = leaf,
		color = panelColor,
		material = Enum.Material.WoodPlanks,
	})
	leaf.PrimaryPart = panel

	if starred then
		local plaque = Builders.part({
			name = "Star",
			size = Vector3.new(1.8, 1.8, 0.08),
			cframe = base * CFrame.new(0, UNDER_GAP + DOOR_HEIGHT * 0.72, -0.19),
			parent = leaf,
			transparency = 1,
			collide = false,
		})
		local _, label = Builders.surfaceText(plaque, Enum.NormalId.Front, "★", Theme.Colors.Brass, Theme.Fonts.Bold)
		label.TextStrokeTransparency = 0.4
		label.TextStrokeColor3 = Theme.Colors.DarkWood
	end

	local handle = Builders.part({
		name = "Handle",
		size = Vector3.new(0.9, 0.22, 0.22),
		cframe = base * CFrame.new(DOOR_WIDTH / 2 - 0.8, UNDER_GAP + 3.8, -0.3),
		parent = leaf,
		color = Theme.Colors.Brass,
		material = Enum.Material.Metal,
		collide = false,
	})
	handle.Reflectance = 0.2
	return leaf
end

--- Hidden glow strip in the gap under the door. Clients fade it in during a warning.
local function underGlow(model: Model, base: CFrame)
	local strip = Builders.part({
		name = "UnderGlow",
		size = Vector3.new(DOOR_WIDTH, 0.2, 0.15),
		cframe = base * CFrame.new(0, 0.12, -0.05),
		parent = model,
		color = Theme.Colors.DoorGlow,
		material = Enum.Material.Neon,
		transparency = 1,
		collide = false,
	})
	local light = Builders.pointLight(strip, Theme.Colors.DoorGlow, 10, 2.5, false)
	light.Name = "Glow"
end

--- base: CFrame at the bottom-centre of the doorway, LookVector pointing out into the room.
function Props.paintedDoor(parent: Instance, base: CFrame, doorId: string, role: string): Model
	local model = Builders.model("PaintedDoor_" .. doorId .. "_" .. role, parent)
	doorFrame(model, base)
	doorLeaf(model, base, true, Theme.Colors.PaintedDoor)
	underGlow(model, base)
	model:SetAttribute("DoorId", doorId)
	model:SetAttribute("Role", role)
	-- Hinge on the leaf's left edge (seen from the room), used by the client swing.
	model:SetAttribute("HingeCFrame", base * CFrame.new(-DOOR_WIDTH / 2, 0, 0))
	CollectionService:AddTag(model, "PaintedDoor")
	return model
end

--- Stage 3 exits. Both look like doors; only one opens. The fake one is painted flat on the set.
function Props.exitDoor(parent: Instance, base: CFrame, side: string): Model
	local model = Builders.model("Exit_" .. side, parent)
	doorFrame(model, base)
	doorLeaf(model, base, false, Theme.Colors.DarkWood)
	underGlow(model, base)
	local sign = Builders.part({
		name = "ExitSign",
		size = Vector3.new(3.2, 1.2, 0.3),
		cframe = base * CFrame.new(0, DOOR_HEIGHT + UNDER_GAP + 1.4, -0.2),
		parent = model,
		color = Theme.Colors.UiGood,
		material = Enum.Material.Neon,
		collide = false,
	})
	Builders.surfaceText(sign, Enum.NormalId.Front, "EXIT", Theme.Colors.UiDark, Theme.Fonts.Bold)
	model:SetAttribute("Side", side)
	model:SetAttribute("HingeCFrame", base * CFrame.new(-DOOR_WIDTH / 2, 0, 0))
	CollectionService:AddTag(model, "StageExitDoor")
	return model
end

--- Seat backs and armrests lying on a tipped row (non-colliding, purely visual).
function Props.seatRowDressing(parent: Instance, row: BasePart)
	local seats = math.max(2, math.floor(row.Size.Z / 3))
	local spacing = row.Size.Z / seats
	for i = 1, seats do
		local z = -row.Size.Z / 2 + spacing * (i - 0.5)
		Builders.part({
			name = "SeatBack",
			size = Vector3.new(0.4, 1.6, spacing * 0.8),
			cframe = row.CFrame
				* CFrame.new(-row.Size.X / 2 + 0.3, row.Size.Y / 2 + 0.5, z)
				* CFrame.Angles(0, 0, math.rad(-35)),
			parent = parent,
			color = Theme.Colors.SeatVelvet,
			material = Enum.Material.Fabric,
			collide = false,
		})
	end
end

--- Thin dark posts holding a floating platform up to the floor (visual only).
function Props.supportPosts(parent: Instance, part: BasePart, floorY: number)
	local bottom = part.CFrame.Position.Y - part.Size.Y / 2
	local height = bottom - floorY
	if height < 1 then
		return
	end
	local thickness = 0.8
	local hx, hz = part.Size.X / 2 - thickness, part.Size.Z / 2 - thickness
	for _, offset in { Vector3.new(-hx, 0, -hz), Vector3.new(hx, 0, hz) } do
		local base = part.CFrame.Position + offset
		Builders.part({
			name = "Post",
			size = Vector3.new(thickness, height, thickness),
			cframe = CFrame.new(base.X, floorY + height / 2, base.Z),
			parent = parent,
			color = Theme.Colors.DarkWood,
			material = Enum.Material.Wood,
			collide = false,
		})
	end
end

--- Glow-tape "X" spike mark on the floor where a stage entrance spawns you.
function Props.spikeMark(parent: Instance, floorCFrame: CFrame)
	for _, angle in { 45, -45 } do
		Builders.part({
			name = "SpikeMark",
			size = Vector3.new(3, 0.05, 0.4),
			cframe = floorCFrame * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, math.rad(angle), 0),
			parent = parent,
			color = Theme.Colors.MoonTeal,
			material = Enum.Material.Neon,
			collide = false,
		})
	end
end

--- A row of warm footlights along a stage edge. Only every `lightEvery`-th bulb casts light.
function Props.footlights(parent: Instance, from: Vector3, to: Vector3, count: number, lightEvery: number)
	for i = 0, count - 1 do
		local alpha = if count > 1 then i / (count - 1) else 0
		local pos = from:Lerp(to, alpha)
		local bulb = Builders.part({
			name = "Footlight",
			size = Vector3.new(0.8, 0.5, 1.4),
			cframe = CFrame.new(pos),
			parent = parent,
			color = Theme.Colors.Footlight,
			material = Enum.Material.Neon,
			collide = false,
			tag = "Footlight",
		})
		if i % lightEvery == 0 then
			Builders.pointLight(bulb, Theme.Colors.Footlight, 14, 1.2)
		end
	end
end

--- A hanging stage spotlight: a dark can with a SpotLight aimed at `target`.
function Props.stageSpot(parent: Instance, position: Vector3, target: Vector3, color: Color3, range: number)
	local can = Builders.part({
		name = "StageSpot",
		size = Vector3.new(1.2, 1.2, 2),
		cframe = CFrame.lookAt(position, target),
		parent = parent,
		color = Theme.Colors.UiDark,
		material = Enum.Material.Metal,
		collide = false,
	})
	Builders.spotLight(can, Enum.NormalId.Front, color, range, 40)
	return can
end

--- Simple hanging sign with text on its front face.
function Props.sign(parent: Instance, cframe: CFrame, size: Vector3, text: string, textColor: Color3, color: Color3)
	local board = Builders.part({
		name = "Sign",
		size = size,
		cframe = cframe,
		parent = parent,
		color = color,
		material = Enum.Material.Wood,
		collide = false,
	})
	Builders.surfaceText(board, Enum.NormalId.Front, text, textColor)
	return board
end

--- Dust motes drifting through a volume (one emitter per room keeps it cheap).
function Props.dust(parent: Instance, center: Vector3, size: Vector3, rate: number, texture: string)
	local volume = Builders.part({
		name = "DustVolume",
		size = size,
		cframe = CFrame.new(center),
		parent = parent,
		transparency = 1,
		collide = false,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Dust"
	if texture ~= "" then
		emitter.Texture = texture
	end
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(8, 14)
	emitter.Speed = NumberRange.new(0.2, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.12)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Theme.Colors.Fog)
	emitter.LightEmission = 0.4
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Parent = volume
	return volume
end

return Props
