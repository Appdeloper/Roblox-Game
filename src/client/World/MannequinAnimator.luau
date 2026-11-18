--!strict
--[[
	MannequinAnimator — procedural, asset-free animation for every mannequin on this client.

	Server mannequins move via physics; here we only bend their Motor6D joints locally
	(Motor6D.Transform, set during Stepped) based on how fast each one is moving:
	  walking → leg/arm swing, idle → a curious head tilt, Pose = "Bow" → a deep bow.
	Mannequins further than Config.Effects.AnimationRange are skipped (mobile frame budget).
	Other players' mannequins are faded so you always know which one is yours.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MannequinAnimator = {}

type Tracked = {
	model: Model,
	root: BasePart,
	joints: { [string]: Motor6D },
	lastPos: Vector3,
	phase: number,
	bow: number,
	speed: number,
	own: boolean,
}

local tracked: { [Model]: Tracked } = {}
local JOINT_NAMES = { "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftHip", "RightHip" }

local function isOwn(model: Model): boolean
	local owner = model:GetAttribute("OwnerUserId")
	-- Local puppets have no owner: treat them as "yours" (fully visible).
	return owner == nil or owner == Players.LocalPlayer.UserId
end

local function fade(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			d.LocalTransparencyModifier = Config.Mannequin.OtherPlayersTransparency
		end
	end
end

local function track(model: Model)
	if tracked[model] then
		return
	end
	local root = model:WaitForChild("Root", 10)
	if not root or not root:IsA("BasePart") then
		return
	end
	local joints: { [string]: Motor6D } = {}
	for _, name in JOINT_NAMES do
		local joint = model:FindFirstChild(name, true)
		if joint and joint:IsA("Motor6D") then
			joints[name] = joint
		end
	end
	local own = isOwn(model)
	if not own then
		fade(model)
	end
	tracked[model] = {
		model = model,
		root = root,
		joints = joints,
		lastPos = root.Position,
		phase = 0,
		bow = 0,
		speed = 0,
		own = own,
	}
end

local function animate(t: Tracked, dt: number)
	local pos = t.root.Position
	local velocity = ((pos - t.lastPos) * Vector3.new(1, 0, 1)).Magnitude / math.max(dt, 1e-3)
	t.lastPos = pos
	-- Smooth the speed so 20 Hz-ish physics updates don't make the legs stutter.
	t.speed += (velocity - t.speed) * math.min(1, dt * 8)

	local stride = math.clamp(t.speed / Config.Movement.WalkSpeed, 0, 1.2)
	t.phase += dt * (4 + t.speed * 0.45)
	local swing = math.sin(t.phase) * stride * math.rad(38)

	local bowTarget = if t.model:GetAttribute("Pose") == "Bow" then 1 else 0
	t.bow += (bowTarget - t.bow) * math.min(1, dt * 5)
	local idle = 1 - math.clamp(stride * 3, 0, 1)

	local j = t.joints
	if j.LeftHip then
		j.LeftHip.Transform = CFrame.Angles(swing, 0, 0)
	end
	if j.RightHip then
		j.RightHip.Transform = CFrame.Angles(-swing, 0, 0)
	end
	if j.LeftShoulder then
		j.LeftShoulder.Transform = CFrame.Angles(-swing * 0.8, 0, 0)
	end
	if j.RightShoulder then
		-- During the bow the right arm sweeps across the chest.
		j.RightShoulder.Transform = CFrame.Angles(swing * 0.8 - math.rad(70) * t.bow, 0, math.rad(25) * t.bow)
	end
	if j.Waist then
		-- Negative X rotation tips the torso forward (toward the look direction).
		j.Waist.Transform = CFrame.Angles(-math.rad(65) * t.bow, 0, 0)
	end
	if j.Neck then
		j.Neck.Transform = CFrame.Angles(-math.rad(15) * t.bow, 0, math.rad(14) * idle * (1 - t.bow))
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for model, t in tracked do
		if not model.Parent or not t.root.Parent then
			tracked[model] = nil
		elseif (t.root.Position - eye).Magnitude <= Config.Effects.AnimationRange then
			animate(t, dt)
		end
	end
end

function MannequinAnimator.init()
	for _, model in CollectionService:GetTagged("Mannequin") do
		if model:IsA("Model") then
			task.spawn(track, model)
		end
	end
	CollectionService:GetInstanceAddedSignal("Mannequin"):Connect(function(model)
		if model:IsA("Model") then
			task.spawn(track, model)
		end
	end)
	CollectionService:GetInstanceRemovedSignal("Mannequin"):Connect(function(model)
		tracked[model :: Model] = nil
	end)
	RunService.Stepped:Connect(function(_, dt)
		step(dt)
	end)
end

--- Root part of the local player's own (server) mannequin, if one exists.
function MannequinAnimator.ownRoot(): BasePart?
	for model, t in tracked do
		if t.own and model:GetAttribute("OwnerUserId") ~= nil and t.root.Parent then
			return t.root
		end
	end
	return nil
end

--- Current smoothed speed of a tracked mannequin (for creak audio).
function MannequinAnimator.speedOf(root: BasePart): number
	for _, t in tracked do
		if t.root == root then
			return t.speed
		end
	end
	return 0
end

return MannequinAnimator
