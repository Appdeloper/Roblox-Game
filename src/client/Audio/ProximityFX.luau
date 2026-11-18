--!strict
--[[
	ProximityFX — "how close is it?" feedback for YOUR mannequin only.

	  Heartbeat  volume and tempo rise as it closes in (Config.Audio.Heartbeat*).
	  Creak      a wooden creak loop on the mannequin while it moves.
	  Pulse      a soft dark edge vignette that beats with the heart — the same cue for muted
	             phones. In Reduced Scares it stays as a steady, gentler tint (no pulsing).
	Updated at 15 Hz; silent and invisible outside a run.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioController = require(script.Parent.AudioController)
local ClientState = require(script.Parent.Parent.ClientState)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local MannequinAnimator = require(script.Parent.Parent.World.MannequinAnimator)

local ProximityFX = {}

local INTERVAL = 1 / 15
local edges: { Frame } = {}
local accumulator = 0
local beatPhase = 0
local creakRoot: BasePart? = nil

--- 0 when far away (>= HeartbeatRange), 1 at catch distance.
local function closeness(): number
	if ClientState.phase ~= "Running" then
		return 0
	end
	local mannequin = MannequinAnimator.ownRoot()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not mannequin or not root or not root:IsA("BasePart") then
		return 0
	end
	local distance = (mannequin.Position - root.Position).Magnitude
	local near, far = Config.Catch.Distance, Config.Audio.HeartbeatRange
	return math.clamp(1 - (distance - near) / (far - near), 0, 1)
end

local function buildVignette()
	local overlay = UIRoot.get("Overlay")
	-- Four edge strips with gradients that fade toward the centre of the screen.
	local specs = {
		{ UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0), 90 },
		{ UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0.78), -90 },
		{ UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0, 0), 0 },
		{ UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0.84, 0), 180 },
	}
	for i, spec in specs do
		local edge = Widgets.frame("Vignette" .. i, overlay, spec[1], spec[2], Theme.Colors.Black, 1)
		edge.ZIndex = 5
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec[3]
		gradient.Transparency = NumberSequence.new(0, 1)
		gradient.Parent = edge
		table.insert(edges, edge)
	end
end

local function updateCreak(mannequin: BasePart?)
	if mannequin ~= creakRoot then
		AudioController.stopLoop("MannequinCreak")
		creakRoot = mannequin
		if mannequin then
			AudioController.startLoop("MannequinCreak", mannequin)
		end
	end
	local creak = AudioController.getLoop("MannequinCreak")
	if creak and mannequin then
		local moving = MannequinAnimator.speedOf(mannequin) > Config.Audio.CreakMinSpeed
		creak.Volume = if moving then Config.Audio.CreakVolume else 0
	end
end

local function update(dt: number)
	local t = closeness()
	local heart = if t > 0 then AudioController.startLoop("Heartbeat", SoundService) else nil
	if heart then
		heart.Volume = Config.Audio.HeartbeatMaxVolume * t
		heart.PlaybackSpeed = Config.Audio.HeartbeatMinSpeed
			+ (Config.Audio.HeartbeatMaxSpeed - Config.Audio.HeartbeatMinSpeed) * t
	elseif t == 0 then
		AudioController.stopLoop("Heartbeat")
	end
	updateCreak(if ClientState.phase == "Running" then MannequinAnimator.ownRoot() else nil)

	-- Beats per second follow the heartbeat tempo; the pulse is a quick swell each beat.
	beatPhase = (beatPhase + dt * (1 + 1.4 * t)) % 1
	local pulse = if ClientState.reducedScares then 0.5 else math.exp(-beatPhase * 6)
	local strength = t * (0.35 + 0.35 * pulse)
	for _, edge in edges do
		edge.BackgroundTransparency = 1 - strength
	end
end

function ProximityFX.init()
	buildVignette()
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= INTERVAL then
			update(accumulator)
			accumulator = 0
		end
	end)
end

return ProximityFX
