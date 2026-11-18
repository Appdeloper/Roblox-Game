--!strict
--[[
	MannequinRig — builds the wooden block-rig mannequin (blank face, ball joints).

	Shared because the server builds the real chasers and the client builds a local-only
	"puppet" for the stage-2 window scare. Joints are Motor6Ds so clients can animate limbs by
	setting Motor6D.Transform locally (walk swing, bow) without any animation assets.

	Layout (relative to Root, whose centre is Config.Mannequin.RootHeight above the feet):
	  legs -3..-1, pelvis -1..-0.5, torso -0.5..1.2, head 1.5..2.8, arms hang from 1.2.
]]

local CollectionService = game:GetService("CollectionService")

local Theme = require(script.Parent.Theme)

local MannequinRig = {}

export type Rig = {
	model: Model,
	root: BasePart,
	joints: { [string]: Motor6D },
}

type PartSpec = { name: string, size: Vector3, offset: Vector3 }

local PARTS: { PartSpec } = {
	{ name = "Pelvis", size = Vector3.new(1.9, 0.5, 0.9), offset = Vector3.new(0, -0.75, 0) },
	{ name = "Torso", size = Vector3.new(1.8, 1.7, 0.9), offset = Vector3.new(0, 0.35, 0) },
	{ name = "Head", size = Vector3.new(1.1, 1.3, 1.1), offset = Vector3.new(0, 2.15, 0) },
	{ name = "LeftArm", size = Vector3.new(0.6, 1.9, 0.6), offset = Vector3.new(-1.25, 0.25, 0) },
	{ name = "RightArm", size = Vector3.new(0.6, 1.9, 0.6), offset = Vector3.new(1.25, 0.25, 0) },
	{ name = "LeftLeg", size = Vector3.new(0.8, 2, 0.8), offset = Vector3.new(-0.5, -2, 0) },
	{ name = "RightLeg", size = Vector3.new(0.8, 2, 0.8), offset = Vector3.new(0.5, -2, 0) },
}

-- name, part0, part1, joint position relative to Root
type JointSpec = { name: string, part0: string, part1: string, at: Vector3 }

local JOINTS: { JointSpec } = {
	{ name = "RootJoint", part0 = "Root", part1 = "Pelvis", at = Vector3.new(0, -0.75, 0) },
	{ name = "Waist", part0 = "Pelvis", part1 = "Torso", at = Vector3.new(0, -0.5, 0) },
	{ name = "Neck", part0 = "Torso", part1 = "Head", at = Vector3.new(0, 1.3, 0) },
	{ name = "LeftShoulder", part0 = "Torso", part1 = "LeftArm", at = Vector3.new(-1.25, 1.0, 0) },
	{ name = "RightShoulder", part0 = "Torso", part1 = "RightArm", at = Vector3.new(1.25, 1.0, 0) },
	{ name = "LeftHip", part0 = "Pelvis", part1 = "LeftLeg", at = Vector3.new(-0.5, -1, 0) },
	{ name = "RightHip", part0 = "Pelvis", part1 = "RightLeg", at = Vector3.new(0.5, -1, 0) },
}

-- Ball joints that sell the "artist's mannequin" look (decorative, welded).
local BALLS: { { at: Vector3, part: string, size: number } } = {
	{ at = Vector3.new(-1.25, 1.0, 0), part = "Torso", size = 0.7 },
	{ at = Vector3.new(1.25, 1.0, 0), part = "Torso", size = 0.7 },
	{ at = Vector3.new(-0.5, -1, 0), part = "Pelvis", size = 0.75 },
	{ at = Vector3.new(0.5, -1, 0), part = "Pelvis", size = 0.75 },
	{ at = Vector3.new(0, 1.35, 0), part = "Torso", size = 0.55 },
	{ at = Vector3.new(-0.5, -2, 0), part = "LeftLeg", size = 0.6 },
	{ at = Vector3.new(0.5, -2, 0), part = "RightLeg", size = 0.6 },
}

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Wood
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = true
	part.Anchored = false
	part.Parent = parent
	return part
end

--- Builds a rig at `cframe` (root position). Not parented; caller decides where it lives.
function MannequinRig.build(name: string, cframe: CFrame): Rig
	local model = Instance.new("Model")
	model.Name = name

	local root = newPart("Root", Vector3.new(2, 2, 1), cframe, Theme.Colors.Mannequin, model)
	root.Transparency = 1
	root.Massless = false
	root.CastShadow = false
	model.PrimaryPart = root

	local parts: { [string]: BasePart } = { Root = root }
	for _, spec in PARTS do
		parts[spec.name] =
			newPart(spec.name, spec.size, cframe * CFrame.new(spec.offset), Theme.Colors.Mannequin, model)
	end

	local joints: { [string]: Motor6D } = {}
	for _, spec in JOINTS do
		local p0, p1 = parts[spec.part0], parts[spec.part1]
		local motor = Instance.new("Motor6D")
		motor.Name = spec.name
		motor.Part0 = p0
		motor.Part1 = p1
		-- Same world point expressed in each part's space.
		local jointWorld = cframe * CFrame.new(spec.at)
		motor.C0 = p0.CFrame:ToObjectSpace(jointWorld)
		motor.C1 = p1.CFrame:ToObjectSpace(jointWorld)
		motor.Parent = p0
		joints[spec.name] = motor
	end

	for i, ball in BALLS do
		local host = parts[ball.part]
		local sphere = newPart(
			"JointBall" .. i,
			Vector3.one * ball.size,
			cframe * CFrame.new(ball.at),
			Theme.Colors.MannequinJoint,
			model
		)
		sphere.Shape = Enum.PartType.Ball
		sphere.CastShadow = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = host
		weld.Part1 = sphere
		weld.Parent = sphere
	end

	model:SetAttribute("Pose", "Idle")
	CollectionService:AddTag(model, "Mannequin")
	return { model = model, root = root, joints = joints }
end

return MannequinRig
