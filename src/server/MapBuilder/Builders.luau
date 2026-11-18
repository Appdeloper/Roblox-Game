--!strict
--[[
	Builders — small factory helpers so stage code reads like a set list, not property soup.
	Every part is anchored, smooth-surfaced and (by default) non-shadow-casting for mobile.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)

local Builders = {}

export type PartProps = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	parent: Instance,
	-- Key into Theme.Surfaces (Color + Material [+ Reflectance/Transparency]). Required.
	surface: string,
	-- Decorative: no collision, no raycast/touch work, no shadow. Use for anything that is
	-- not walkable or a wall, so the parkour route stays physically and visually clean.
	decor: boolean?,
	collide: boolean?,
	transparency: number?,
	castShadow: boolean?,
	tag: string?,
}

function Builders.v(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

--- Base transparency of a Theme surface (0 when it defines none).
function Builders.surfaceTransparency(name: string): number
	local surface = (Theme.Surfaces :: any)[name]
	assert(surface, "Unknown Theme surface: " .. tostring(name))
	return surface.Transparency or 0
end

--- Applies a Theme surface (see Theme.apply).
function Builders.applySurface(part: BasePart, name: string)
	Theme.apply(part, name)
end

local function applyCommon(part: BasePart, props: PartProps)
	part.Name = props.name
	part.Anchored = true
	part.Size = props.size
	part.CFrame = props.cframe
	Builders.applySurface(part, props.surface)
	if props.transparency then
		part.Transparency = props.transparency
	end
	local collide = if props.decor then false elseif props.collide == nil then true else props.collide
	part.CanCollide = collide
	-- Only collidable geometry needs raycasts; nothing in the map uses Touched.
	part.CanTouch = false
	part.CanQuery = collide
	part.CastShadow = if props.castShadow ~= nil then props.castShadow else false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.tag then
		CollectionService:AddTag(part, props.tag)
	end
	part.Parent = props.parent
end

function Builders.part(props: PartProps): Part
	local part = Instance.new("Part")
	applyCommon(part, props)
	return part
end

--- Cylinder whose axis runs along the CFrame's X axis (Roblox convention).
function Builders.cylinder(props: PartProps): Part
	local part = Builders.part(props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

function Builders.ball(props: PartProps): Part
	local part = Builders.part(props)
	part.Shape = Enum.PartType.Ball
	return part
end

function Builders.wedge(props: PartProps): WedgePart
	local part = Instance.new("WedgePart")
	applyCommon(part, props)
	return part
end

function Builders.cornerWedge(props: PartProps): CornerWedgePart
	local part = Instance.new("CornerWedgePart")
	applyCommon(part, props)
	return part
end

--- Truss sizes must be multiples of 2 on X/Z; Roblox rounds otherwise.
function Builders.truss(props: PartProps): TrussPart
	local part = Instance.new("TrussPart")
	applyCommon(part, props)
	part.Style = Enum.Style.AlternatingSupports
	return part
end

function Builders.folder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Builders.model(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

--- CFrame whose WedgePart slope runs DOWN toward `toward` ("+X", "-X", "+Z", "-Z").
--- A WedgePart is tallest at its local +Z face and thins to nothing at -Z.
function Builders.slopeCFrame(position: Vector3, toward: string): CFrame
	local yaw = ({ ["+X"] = -90, ["-X"] = 90, ["+Z"] = 180, ["-Z"] = 0 })[toward] or 0
	return CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0)
end

function Builders.pointLight(parent: Instance, color: Color3, range: number, brightness: number, enabled: boolean?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Enabled = if enabled == nil then true else enabled
	light.Parent = parent
	return light
end

function Builders.spotLight(parent: Instance, face: Enum.NormalId, color: Color3, range: number, angle: number)
	local light = Instance.new("SpotLight")
	light.Face = face
	light.Color = color
	light.Range = range
	light.Angle = angle
	light.Brightness = 3
	light.Shadows = true
	light.Parent = parent
	return light
end

--- A SurfaceGui with one TextLabel filling the face. Used for signs, stars, the leaderboard.
function Builders.surfaceText(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Enum.Font?
): (SurfaceGui, TextLabel)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font or Theme.Fonts.Title
	label.Parent = gui
	return gui, label
end

--- An axis-aligned wall (thin along Z) with rectangular window holes in one horizontal band.
--- `spans` are LOCAL X ranges (same space as the wall centre); y1/y2 are LOCAL Y.
function Builders.wallWithWindows(
	name: string,
	parent: Instance,
	center: Vector3,
	size: Vector3,
	band: { y1: number, y2: number, spans: { { number } } },
	surface: string
): { BasePart }
	local parts: { BasePart } = {}
	local minX, maxX = center.X - size.X / 2, center.X + size.X / 2
	local minY, maxY = center.Y - size.Y / 2, center.Y + size.Y / 2
	local function slab(suffix: string, x1: number, x2: number, y1: number, y2: number)
		if x2 - x1 <= 0.01 or y2 - y1 <= 0.01 then
			return
		end
		table.insert(
			parts,
			Builders.part({
				name = name .. suffix,
				size = Vector3.new(x2 - x1, y2 - y1, size.Z),
				cframe = CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, center.Z),
				parent = parent,
				surface = surface,
			})
		)
	end
	slab("_Lower", minX, maxX, minY, band.y1)
	slab("_Upper", minX, maxX, band.y2, maxY)
	local cursor = minX
	for i, span in band.spans do
		slab("_Pillar" .. i, cursor, span[1], band.y1, band.y2)
		cursor = span[2]
	end
	slab("_PillarEnd", cursor, maxX, band.y1, band.y2)
	return parts
end

return Builders
