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
local SetPieces = require(script.Parent.SetPieces)

local Props = {}

local DOOR_WIDTH = 5
local DOOR_HEIGHT = 8.6
local UNDER_GAP = 0.35
local OPENING = DOOR_HEIGHT + UNDER_GAP

--- Thick moulded frame: deep jambs + head, gilt casing, keystone and a threshold.
local function doorFrame(model: Model, base: CFrame)
	for _, side in { -1, 1 } do
		Builders.part({
			name = "Jamb",
			size = Vector3.new(0.9, OPENING + 0.9, 1.1),
			cframe = base * CFrame.new(side * (DOOR_WIDTH / 2 + 0.45), (OPENING + 0.9) / 2, 0),
			parent = model,
			surface = "DarkWood",
		})
		Builders.part({
			name = "Casing",
			size = Vector3.new(0.25, OPENING + 0.9, 0.14),
			cframe = base * CFrame.new(side * (DOOR_WIDTH / 2 + 0.78), (OPENING + 0.9) / 2, -0.62),
			parent = model,
			surface = "Gilt",
			decor = true,
		})
	end
	Builders.part({
		name = "Lintel",
		size = Vector3.new(DOOR_WIDTH + 1.8, 0.9, 1.1),
		cframe = base * CFrame.new(0, OPENING + 0.45, 0),
		parent = model,
		surface = "DarkWood",
	})
	Builders.part({
		name = "Casing",
		size = Vector3.new(DOOR_WIDTH + 1.8, 0.25, 0.14),
		cframe = base * CFrame.new(0, OPENING + 0.78, -0.62),
		parent = model,
		surface = "Gilt",
		decor = true,
	})
	Builders.part({
		name = "Keystone",
		size = Vector3.new(1, 1.3, 0.3),
		cframe = base * CFrame.new(0, OPENING + 1.1, -0.55),
		parent = model,
		surface = "Gilt",
		decor = true,
	})
	Builders.part({
		name = "Threshold",
		size = Vector3.new(DOOR_WIDTH + 0.6, 0.12, 1.2),
		cframe = base * CFrame.new(0, 0.06, -0.1),
		parent = model,
		surface = "DarkWood",
		decor = true,
	})
end

--- The door leaf lives in its own model so clients can swing it on the hinge. Everything on
--- the leaf (insets, star, rose, handle) swings with it; only "Handle" turns on a warning.
local function doorLeaf(model: Model, base: CFrame, starred: boolean, panelSurface: string): Model
	local leaf = Builders.model("Leaf", model)
	local panel = Builders.part({
		name = "Panel",
		size = Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 0.3),
		cframe = base * CFrame.new(0, UNDER_GAP + DOOR_HEIGHT / 2, 0),
		parent = leaf,
		surface = panelSurface,
	})
	leaf.PrimaryPart = panel
	-- Two raised panels.
	for _, frac in { 0.27, 0.72 } do
		Builders.part({
			name = "Inset",
			size = Vector3.new(DOOR_WIDTH - 1.4, DOOR_HEIGHT * 0.36, 0.08),
			cframe = base * CFrame.new(0, UNDER_GAP + DOOR_HEIGHT * frac, -0.19),
			parent = leaf,
			surface = if panelSurface == "PaintedDoor" then "DoorPanelInset" else "AgedWood",
			decor = true,
		})
	end
	if starred then
		SetPieces.star(
			leaf,
			"Star",
			base * CFrame.new(0, UNDER_GAP + DOOR_HEIGHT * 0.72, -0.27),
			1.05,
			0.44,
			0.12,
			"Brass"
		)
	end
	local spindle = base * CFrame.new(DOOR_WIDTH / 2 - 0.45, UNDER_GAP + 3.8, -0.2)
	Builders.cylinder({
		name = "Rose",
		size = Vector3.new(0.1, 0.6, 0.6),
		cframe = spindle * CFrame.Angles(0, math.rad(90), 0),
		parent = leaf,
		surface = "Brass",
		decor = true,
	})
	-- Lever: its spindle end sits on the rose (DoorEffects turns it around that end).
	Builders.part({
		name = "Handle",
		size = Vector3.new(0.9, 0.2, 0.2),
		cframe = spindle * CFrame.new(-0.35, 0, -0.15),
		parent = leaf,
		surface = "Brass",
		decor = true,
	})
	return leaf
end

--- Warm light strip in the gap under the door + a hidden floor spill; clients reveal both.
local function underGlow(model: Model, base: CFrame, spillTag: string, spillAttributes: { [string]: any })
	local strip = Builders.part({
		name = "UnderGlow",
		size = Vector3.new(DOOR_WIDTH, 0.2, 0.15),
		cframe = base * CFrame.new(0, 0.12, -0.05),
		parent = model,
		surface = "DoorGlow",
		decor = true,
	})
	local light = Builders.pointLight(strip, Theme.Colors.DoorGlow, 12, 2.5, false)
	light.Name = "Glow"
	SetPieces.lightSpill(model, base, spillTag, spillAttributes)
end

--- base: CFrame at the bottom-centre of the doorway, LookVector pointing out into the room.
function Props.paintedDoor(parent: Instance, base: CFrame, doorId: string, role: string): Model
	local model = Builders.model("PaintedDoor_" .. doorId .. "_" .. role, parent)
	doorFrame(model, base)
	doorLeaf(model, base, true, "PaintedDoor")
	underGlow(model, base, "DoorSpill", { DoorId = doorId })
	model:SetAttribute("DoorId", doorId)
	model:SetAttribute("Role", role)
	-- Hinge on the leaf's left edge (seen from the room), used by the client swing.
	model:SetAttribute("HingeCFrame", base * CFrame.new(-DOOR_WIDTH / 2, 0, 0))
	CollectionService:AddTag(model, "PaintedDoor")
	return model
end

--- Flat "painted on the set" look for the fake exit: hidden until a client enables it.
local function paintedOverlay(panel: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PaintedOverlay"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.4
	gui.Enabled = false
	gui.Parent = panel
	local function paint(size: UDim2, pos: UDim2, color: Color3, transparency: number)
		local f = Instance.new("Frame")
		f.Size = size
		f.Position = pos
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.Parent = gui
		return f
	end
	local wood = Theme.Surfaces.ExitDoor.Color
	paint(UDim2.fromScale(1, 1), UDim2.new(), wood:Lerp(Theme.Colors.Paper, 0.18), 0)
	-- Painted "panels" and a painted shadow edge: convincingly flat once you look closely.
	paint(UDim2.fromScale(0.7, 0.3), UDim2.fromScale(0.15, 0.1), wood:Lerp(Theme.Colors.Black, 0.25), 0.2)
	paint(UDim2.fromScale(0.7, 0.3), UDim2.fromScale(0.15, 0.55), wood:Lerp(Theme.Colors.Black, 0.25), 0.2)
	paint(UDim2.fromScale(0.06, 1), UDim2.fromScale(0.94, 0), Theme.Colors.Black, 0.55)
	local knob = paint(UDim2.fromScale(0.12, 0.06), UDim2.fromScale(0.78, 0.52), Theme.Colors.Brass, 0)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = knob
end

--- Stage 3 exits. Both look like doors; only one opens. Clients decide (per player) which is
--- real: the real one gets its light + spill, the fake one its painted overlay.
function Props.exitDoor(parent: Instance, base: CFrame, side: string): Model
	local model = Builders.model("Exit_" .. side, parent)
	doorFrame(model, base)
	local leaf = doorLeaf(model, base, false, "ExitDoor")
	underGlow(model, base, "LightSpill", { Side = side })
	local panel = leaf.PrimaryPart
	if panel then
		paintedOverlay(panel)
	end
	local sign = Builders.part({
		name = "ExitSign",
		size = Vector3.new(3.2, 1.2, 0.3),
		cframe = base * CFrame.new(0, OPENING + 2.4, -0.4),
		parent = model,
		surface = "ExitSign",
		decor = true,
	})
	Builders.surfaceText(sign, Enum.NormalId.Front, "EXIT", Theme.Colors.UiDark, Theme.Fonts.Bold)
	model:SetAttribute("Side", side)
	model:SetAttribute("HingeCFrame", base * CFrame.new(-DOOR_WIDTH / 2, 0, 0))
	CollectionService:AddTag(model, "StageExitDoor")
	return model
end

--- A tipped-over seat row: the seats hang off the row's SIDE faces (backs on one side,
--- cushions on the other), always below the walking surface, so the top stays clean and
--- readable for the jump (only the glow-tape lips sit on top).
function Props.seatRowDressing(parent: Instance, row: BasePart)
	local seats = math.max(2, math.floor(row.Size.Z / 2.2))
	local spacing = row.Size.Z / seats
	local hx, hy = row.Size.X / 2, row.Size.Y / 2
	for i = 1, seats do
		local z = -row.Size.Z / 2 + spacing * (i - 0.5)
		Builders.part({
			name = "SeatBack",
			size = Vector3.new(0.35, 1.9, spacing * 0.82),
			cframe = row.CFrame * CFrame.new(-hx - 0.2, hy - 2, z),
			parent = parent,
			surface = "Velvet",
			decor = true,
		})
		Builders.part({
			name = "SeatCushion",
			size = Vector3.new(0.5, 1.4, spacing * 0.78),
			cframe = row.CFrame * CFrame.new(hx + 0.3, -1.3, z),
			parent = parent,
			surface = "Velvet",
			decor = true,
		})
		Builders.part({
			name = "Armrest",
			size = Vector3.new(0.6, 0.25, 0.22),
			cframe = row.CFrame * CFrame.new(hx + 0.35, hy - 1.6, z + spacing / 2),
			parent = parent,
			surface = "DarkWood",
			decor = true,
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
			surface = "DarkWood",
			decor = true,
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
			surface = "GlowTape",
			decor = true,
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
			surface = "Footlight",
			decor = true,
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
		surface = "Iron",
		decor = true,
	})
	Builders.spotLight(can, Enum.NormalId.Front, color, range, 40)
	return can
end

--- Simple hanging sign with text on its front face.
function Props.sign(parent: Instance, cframe: CFrame, size: Vector3, text: string, textColor: Color3, surface: string)
	local board = Builders.part({
		name = "Sign",
		size = size,
		cframe = cframe,
		parent = parent,
		surface = surface,
		decor = true,
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
		surface = "Invisible",
		decor = true,
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
