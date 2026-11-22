--!strict
--[[
	MannequinAnimator — procedural, asset-free animation for every mannequin on this client.

	Server mannequins move via physics; here we only bend their Motor6D joints locally
	(Motor6D.Transform, set during Stepped) based on how fast each one is moving:
	  walking → leg/arm swing, idle → a curious head tilt, Pose = "Bow" → a deep bow.
	The server's Pose attribute also carries the player's own movement, copied late:
	Jump (arms up, knees tucked), Fall (arms out), Climb (hand over hand), plus Reach (both
	arms out for you when it's close) and Frozen (stiff, caught being watched).
	Your own mannequins turn their head to follow you, and creak when they freeze or unfreeze.
	Hidden mannequins (an uncracked mirror) are invisible; Understudies and the Mirror are
	drawn slightly see-through so you can tell the cast apart.
	Mannequins further than Config.Effects.AnimationRange are skipped (mobile frame budget).
	Other players' mannequins are faded so you always know which one is yours.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local Quality = require(script.Parent.Parent.Quality)

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
	parts: { BasePart },
	head: BasePart?,
	torso: BasePart?,
	lastPose: string,
	lastHidden: boolean?,
	reach: number,
	lookYaw: number,
	lookPitch: number,
}

-- See-through amount per role (own mannequins); other players' casts use the fade instead.
local ROLE_TRANSPARENCY: { [string]: number } = { Copycat = 0, Understudy = 0.25, Mirror = 0.35 }

local tracked: { [Model]: Tracked } = {}
local JOINT_NAMES = { "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftHip", "RightHip" }

local function isOwn(model: Model): boolean
	local owner = model:GetAttribute("OwnerUserId")
	-- Local puppets have no owner: treat them as "yours" (fully visible).
	return owner == nil or owner == Players.LocalPlayer.UserId
end

local function applyLook(t: Tracked)
	local hidden = t.model:GetAttribute("Hidden") == true
	if hidden == t.lastHidden then
		return
	end
	t.lastHidden = hidden
	local role = t.model:GetAttribute("Role")
	local amount = if hidden
		then 1
		elseif not t.own then Config.Mannequin.OtherPlayersTransparency
		else ROLE_TRANSPARENCY[role :: string] or 0
	for _, part in t.parts do
		part.LocalTransparencyModifier = amount
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
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			table.insert(parts, d)
		end
	end
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("Torso")
	local t: Tracked = {
		model = model,
		root = root,
		joints = joints,
		lastPos = root.Position,
		phase = 0,
		bow = 0,
		speed = 0,
		own = own,
		parts = parts,
		head = if head and head:IsA("BasePart") then head else nil,
		torso = if torso and torso:IsA("BasePart") then torso else nil,
		lastPose = "Idle",
		lastHidden = nil,
		reach = 0,
		lookYaw = 0,
		lookPitch = 0,
	}
	tracked[model] = t
	applyLook(t)
end

--- Head yaw/pitch (radians, in the torso's frame) that points the face at `target`.
local function lookAngles(t: Tracked, target: Vector3): (number, number)
	local torso, head = t.torso, t.head
	if not torso or not head then
		return 0, 0
	end
	local d = torso.CFrame:VectorToObjectSpace(target - head.Position)
	local flat = math.sqrt(d.X * d.X + d.Z * d.Z)
	local yaw = math.atan2(-d.X, -d.Z)
	local pitch = math.atan2(d.Y, math.max(flat, 1e-3))
	return math.clamp(yaw, -math.rad(75), math.rad(75)), math.clamp(pitch, -math.rad(35), math.rad(35))
end

local function onPoseChanged(t: Tracked, pose: string)
	local was = t.lastPose
	t.lastPose = pose
	-- Wood creaks when it locks up under your gaze, and again when it moves on.
	if t.own and (pose == "Frozen" or was == "Frozen") then
		AudioController.playAt("FloorCreak", t.root)
	end
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

	local pose = (t.model:GetAttribute("Pose") :: string?) or "Idle"
	if pose ~= t.lastPose then
		onPoseChanged(t, pose)
	end
	local frozen = pose == "Frozen"
	if frozen then
		-- Caught being watched: stiff, no new motion.
		stride = 0
		swing = 0
	end
	local bowTarget = if pose == "Bow" then 1 else 0
	t.bow += (bowTarget - t.bow) * math.min(1, dt * 5)
	t.reach += ((if pose == "Reach" then 1 else 0) - t.reach) * math.min(1, dt * 6)
	local idle = 1 - math.clamp(stride * 3, 0, 1)
	local jump = if pose == "Jump" then 1 else 0
	local fall = if pose == "Fall" then 1 else 0
	local climb = if pose == "Climb" then 1 else 0
	local climbSwing = math.sin(t.phase * 1.5) * math.rad(50) * climb
	local reach = t.reach

	-- Your own mannequins watch you: the head follows your character (or camera).
	local yaw, pitch = 0, 0
	if t.own then
		local character = Players.LocalPlayer.Character
		local myHead = character and character:FindFirstChild("Head")
		local camera = Workspace.CurrentCamera
		local target = if myHead and myHead:IsA("BasePart")
			then myHead.Position
			elseif camera then camera.CFrame.Position
			else nil
		if target then
			yaw, pitch = lookAngles(t, target)
		end
	end
	local follow = math.min(1, dt * (if frozen then 2 else 5))
	t.lookYaw += (yaw - t.lookYaw) * follow
	t.lookPitch += (pitch - t.lookPitch) * follow

	local j = t.joints
	if j.LeftHip then
		j.LeftHip.Transform = CFrame.Angles(swing - math.rad(45) * jump + math.rad(15) * fall + climbSwing * 0.5, 0, 0)
	end
	if j.RightHip then
		j.RightHip.Transform =
			CFrame.Angles(-swing - math.rad(20) * jump - math.rad(10) * fall - climbSwing * 0.5, 0, 0)
	end
	if j.LeftShoulder then
		j.LeftShoulder.Transform = CFrame.Angles(
			-swing * 0.8 * (1 - reach)
				- math.rad(85) * reach
				- math.rad(150) * jump
				+ math.rad(150) * climb
				+ climbSwing,
			0,
			-math.rad(70) * fall
		)
	end
	if j.RightShoulder then
		-- During the bow the right arm sweeps across the chest.
		j.RightShoulder.Transform = CFrame.Angles(
			swing * 0.8 * (1 - reach)
				- math.rad(70) * t.bow
				- math.rad(85) * reach
				- math.rad(150) * jump
				+ math.rad(150) * climb
				- climbSwing,
			0,
			math.rad(25) * t.bow + math.rad(70) * fall
		)
	end
	if j.Waist then
		-- Negative X rotation tips the torso forward (toward the look direction).
		j.Waist.Transform = CFrame.Angles(-math.rad(65) * t.bow - math.rad(15) * reach, 0, 0)
	end
	if j.Neck then
		local tilt = math.rad(14) * idle * (1 - t.bow) + (if frozen then math.rad(18) else 0)
		j.Neck.Transform = CFrame.Angles(0, t.lookYaw * (1 - t.bow), 0)
			* CFrame.Angles(t.lookPitch * (1 - t.bow) - math.rad(15) * t.bow, 0, tilt)
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for model, t in tracked do
		if not model.Parent or not t.root.Parent then
			tracked[model] = nil
			continue
		end
		-- Cheap (returns early unless Hidden flipped); runs even for far-away mannequins.
		applyLook(t)
		if (t.root.Position - eye).Magnitude <= Quality.settings.AnimationRange then
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
