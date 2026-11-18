--!strict
--[[
	CurtainCall (Stage 3 set):
	  * a proscenium arch at the foot of the staircase and a plank stage floor
	  * cardboard steps dressed with packing tape + stencils as SurfaceGuis (so the dressing
	    falls WITH each step when it collapses), with glow-tape lips on both edges
	  * curved rows of empty audience seats below the stairs (their backs "bounce" for the
	    applause scare), and a fly-loft rig over the stage.
	The two exits (and their hidden light spill / painted overlay) come from Props.exitDoor.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Builders = require(script.Parent.Parent.Builders)
local SetPieces = require(script.Parent.Parent.SetPieces)

local CurtainCall = {}

export type Ctx = {
	set: Instance,
	origin: Vector3,
	rng: Random,
	route: { [string]: BasePart },
}

local STENCILS = { "FRAGILE", "THIS SIDE UP ↑", "PROPS DEPT.", "HANDLE WITH CARE" }

local function L(ctx: Ctx, x: number, y: number, z: number): Vector3
	return ctx.origin + Vector3.new(x, y, z)
end

local function surfaceGui(part: BasePart, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CardboardDressing_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.6
	gui.Parent = part
	return gui
end

local function strip(gui: SurfaceGui, size: UDim2, position: UDim2, color: Color3, transparency: number)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.Parent = gui
end

--- Packing tape cross + glow-tape lips on top, a stencil on the front face.
local function dressStep(ctx: Ctx, step: BasePart)
	local top = surfaceGui(step, Enum.NormalId.Top)
	local tape = Theme.Surfaces.Paper.Color:Lerp(Theme.Surfaces.Cardboard.Color, 0.55)
	strip(top, UDim2.fromScale(1, 0.12), UDim2.fromScale(0.5, 0.5), tape, 0.15)
	strip(top, UDim2.fromScale(0.1, 1), UDim2.fromScale(0.5, 0.5), tape, 0.15)
	-- Glow-tape outline on all four top edges (reads the same whichever way the face maps).
	local glow = Theme.Surfaces.GlowTape.Color
	strip(top, UDim2.new(0, 5, 1, 0), UDim2.new(0, 3, 0.5, 0), glow, 0)
	strip(top, UDim2.new(0, 5, 1, 0), UDim2.new(1, -3, 0.5, 0), glow, 0)
	strip(top, UDim2.new(1, 0, 0, 5), UDim2.new(0.5, 0, 0, 3), glow, 0)
	strip(top, UDim2.new(1, 0, 0, 5), UDim2.new(0.5, 0, 1, -3), glow, 0)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local side = surfaceGui(step, face)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.9, 0.7)
		label.Position = UDim2.fromScale(0.05, 0.15)
		label.BackgroundTransparency = 1
		label.Text = STENCILS[ctx.rng:NextInteger(1, #STENCILS)]
		label.TextScaled = true
		label.Font = Theme.Fonts.Bold
		label.TextColor3 = Theme.Surfaces.PaintRed.Color
		label.TextTransparency = 0.15
		label.Rotation = ctx.rng:NextNumber(-4, 4)
		label.Parent = side
	end
end

local function steps(ctx: Ctx)
	for _, part in CollectionService:GetTagged("CollapseStep") do
		if part:IsA("BasePart") and part:IsDescendantOf(ctx.set.Parent :: Instance) then
			dressStep(ctx, part)
		end
	end
end

local function audience(ctx: Ctx)
	-- Rows below the staircase on both sides, facing the stage (+X).
	for _, z in { -22, -19, -16, 16, 19, 22 } do
		for x = 24, 78, 2.2 do
			local pos = L(ctx, x, -4, z)
			SetPieces.seat(ctx.set, CFrame.lookAt(pos, pos + Vector3.xAxis), ctx.rng, "AudienceSeat")
		end
	end
end

function CurtainCall.build(ctx: Ctx)
	steps(ctx)
	audience(ctx)
	SetPieces.proscenium(ctx.set, CFrame.lookAt(L(ctx, 92.5, 6, 0), L(ctx, 0, 6, 0)), 40, 34, 6, 2, 6)
	local stage = ctx.route.MainStage
	if stage then
		SetPieces.plankFloor(ctx.set, stage.CFrame, stage.Size, ctx.rng)
	end
	-- Two beams narrowing toward the two doors: the whole act in one image. They stop above
	-- head height so nothing hangs in the run to the exits.
	for _, z in { -8, 8 } do
		SetPieces.narrowingBeam(ctx.set, L(ctx, 118, 48, z), L(ctx, 133, 16, z), 7, 3, 5, "WarmBeam")
	end
	-- Confetti and torn paper for a curtain call that never happened.
	SetPieces.confetti(ctx.set, ctx.rng, L(ctx, 112, 6.04, 0), Vector2.new(18, 16), 70)
	SetPieces.confetti(ctx.set, ctx.rng, L(ctx, 70, -4.4, 0), Vector2.new(26, 20), 40)
	-- Signature fill: cold blue-grey cardboard, so the two warm doors are the only warmth.
	for _, spec in { { 40, 30, -16 }, { 100, 16, 16 } } do
		local fill = Builders.part({
			name = "BackstageFill",
			size = Vector3.one,
			cframe = CFrame.new(L(ctx, spec[1], spec[2], spec[3])),
			parent = ctx.set,
			surface = "Invisible",
			decor = true,
		})
		Builders.pointLight(fill, Theme.Colors.MoonTeal, 60, 0.5)
	end
	SetPieces.rigging(ctx.set, ctx.rng, ctx.origin.X + 96, ctx.origin.X + 134, {
		ctx.origin.Z - 14,
		ctx.origin.Z,
		ctx.origin.Z + 14,
	}, ctx.origin.Y + 54, 8, ctx.origin.Y + 30)
end

return CurtainCall
