--!strict
--[[
	Ambient — everything in the theatre that moves on its own, driven by ONE shared Heartbeat
	connection. No part owns a script and nothing else polls.

	Idle motion
	  swinging sandbags  counterweights on the fly ropes, swung as a slow pendulum
	  flickering lamps   filament dips, occasionally a longer stutter
	  rigging creaks     an overhead timber groan on a slow random timer

	Reactive
	  creaky floorboards  loose boards creak and puff dust the first time you cross them
	  curtain ripple      fabric kicks as you run past it
	  nervous lamps       lamps flicker harder and more often the closer your mannequin gets

	Budget: the pendulum pass touches a handful of parts per frame and is skipped entirely
	for props out of view range; everything else runs on a 12 Hz throttle.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local ClientState = require(script.Parent.Parent.ClientState)
local Curtains = require(script.Parent.Curtains)
local MannequinAnimator = require(script.Parent.MannequinAnimator)
local Quality = require(script.Parent.Parent.Quality)

local Ambient = {}

local LOGIC_INTERVAL = 1 / 12
-- Pendulum cull distance comes from the quality level (Quality.settings.SwingRange).
local CREAK_RANGE = 7 -- how close a foot must be to set a loose board off
local CREAK_COOLDOWN = 6 -- seconds before the same board can creak again
local RIPPLE_RANGE = 16
local RIPPLE_SPEED = 6 -- studs/s before the player counts as "rushing past"

type Swing = {
	parts: { { part: BasePart, offset: CFrame } },
	pivot: CFrame,
	speed: number,
	phase: number,
	amplitude: number,
}

type Lamp = {
	light: Light,
	brightness: number,
	-- Time until the current dip ends; 0 when lit normally.
	dipUntil: number,
	nextDip: number,
}

type Board = {
	part: BasePart,
	readyAt: number,
}

local swings: { Swing } = {}
local lamps: { Lamp } = {}
local boards: { Board } = {}
local puff: ParticleEmitter? = nil
local accumulator = 0
local nextRiggingCreak = 0
local lastRipplePos: Vector3? = nil

-- ── Setup ─────────────────────────────────────────────────────────────────────────────────

--- Sandbag + rope pairs share a SwingPivot attribute; group them into one pendulum.
local function collectSwings()
	local groups: { [string]: { BasePart } } = {}
	for _, part in CollectionService:GetTagged("SwingProp") do
		local pivot = part:GetAttribute("SwingPivot")
		if part:IsA("BasePart") and typeof(pivot) == "Vector3" then
			local key = string.format("%.1f,%.1f,%.1f", pivot.X, pivot.Y, pivot.Z)
			groups[key] = groups[key] or {}
			table.insert(groups[key], part)
		end
	end
	for _, parts in groups do
		local anchor = parts[1]:GetAttribute("SwingPivot") :: Vector3
		local pivot = CFrame.new(anchor)
		local entry: Swing = {
			parts = {},
			pivot = pivot,
			-- Longer ropes swing slower, like a real pendulum.
			speed = 0.5 + math.random() * 0.25,
			phase = math.random() * math.pi * 2,
			amplitude = math.rad(2.5 + math.random() * 2),
		}
		for _, part in parts do
			table.insert(entry.parts, { part = part, offset = pivot:ToObjectSpace(part.CFrame) })
		end
		table.insert(swings, entry)
	end
end

local function collectLamps()
	for _, part in CollectionService:GetTagged("FlickerLamp") do
		local light = part:FindFirstChildWhichIsA("Light")
		if light then
			table.insert(lamps, {
				light = light,
				brightness = light.Brightness,
				dipUntil = 0,
				nextDip = os.clock() + math.random() * 6,
			})
		end
	end
end

local function collectBoards()
	for _, part in CollectionService:GetTagged("Creaky") do
		if part:IsA("BasePart") then
			table.insert(boards, { part = part, readyAt = 0 })
		end
	end
end

--- One reusable emitter for every dust puff, moved to wherever a board creaks.
local function makePuff(): ParticleEmitter
	local host = Instance.new("Part")
	host.Name = "DustPuffHost"
	host.Anchored = true
	host.CanCollide = false
	host.CanTouch = false
	host.CanQuery = false
	host.CastShadow = false
	host.Transparency = 1
	host.Size = Vector3.one
	host.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "DustPuff"
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Lifetime = NumberRange.new(0.7, 1.4)
	emitter.Speed = NumberRange.new(1.4, 3)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Theme.Colors.Fog)
	emitter.LightEmission = 0.5
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = host
	return emitter
end

-- ── Per-frame: pendulums only ─────────────────────────────────────────────────────────────

local function updateSwings(now: number, eye: Vector3)
	for _, swing in swings do
		local first = swing.parts[1]
		if first.part.Parent and (first.part.Position - eye).Magnitude <= Quality.settings.SwingRange then
			local angle = math.sin(now * swing.speed + swing.phase) * swing.amplitude
			local rotation = swing.pivot * CFrame.Angles(0, 0, angle)
			for _, piece in swing.parts do
				piece.part.CFrame = rotation * piece.offset
			end
		end
	end
end

-- ── 12 Hz: lamps, boards, ripple, creaks ──────────────────────────────────────────────────

--- 0 when the mannequin is far away, 1 when it is on top of you.
local function dread(): number
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
	return math.clamp(1 - distance / Config.Audio.HeartbeatRange, 0, 1)
end

local function updateLamps(now: number, tension: number)
	for _, lamp in lamps do
		-- A lamp a scare has put out stays out until the scare ends.
		if not lamp.light.Parent or not lamp.light.Enabled then
			continue
		end
		if now < lamp.dipUntil then
			continue
		end
		if lamp.dipUntil > 0 then
			-- Dip just ended.
			lamp.light.Brightness = lamp.brightness
			lamp.dipUntil = 0
		end
		if now >= lamp.nextDip then
			-- The closer the mannequin, the more often and the deeper lamps stutter.
			local deep = math.random() < 0.25 + tension * 0.5
			lamp.light.Brightness = lamp.brightness * (if deep then 0.1 else 0.55)
			lamp.dipUntil = now + (if deep then 0.22 else 0.08)
			lamp.nextDip = lamp.dipUntil + (0.6 + math.random() * 5) * (1 - tension * 0.7)
			if deep and tension > 0.45 then
				AudioController.playAt("LampBuzz", lamp.light.Parent :: BasePart)
			end
		end
	end
end

local function updateBoards(now: number, foot: Vector3?, moving: boolean)
	if not foot or not moving then
		return
	end
	for _, board in boards do
		if now >= board.readyAt and (board.part.Position - foot).Magnitude <= CREAK_RANGE then
			board.readyAt = now + CREAK_COOLDOWN
			AudioController.playAt("FloorCreak", board.part)
			local emitter = puff
			if emitter then
				local host = emitter.Parent :: BasePart
				host.CFrame = CFrame.new(board.part.Position + Vector3.new(0, board.part.Size.Y / 2, 0))
				emitter:Emit(5)
			end
			break -- one board at a time; a run should tick, not rattle
		end
	end
end

local function updateRipple(root: Vector3?)
	if not root then
		lastRipplePos = nil
		return
	end
	local previous = lastRipplePos
	lastRipplePos = root
	if not previous then
		return
	end
	local speed = (root - previous).Magnitude / LOGIC_INTERVAL
	if speed >= RIPPLE_SPEED then
		Curtains.ripple(root, RIPPLE_RANGE, math.clamp(speed / Config.Movement.WalkSpeed, 0, 1))
	end
end

local function updateRiggingCreak(now: number, eye: Vector3)
	if now < nextRiggingCreak then
		return
	end
	nextRiggingCreak = now + 9 + math.random() * 14
	local ropes = CollectionService:GetTagged("RiggingRope")
	if #ropes == 0 then
		return
	end
	-- Creak from a rope that is actually near the player, so it sounds overhead.
	local nearest: BasePart? = nil
	local best = 90
	for _, rope in ropes do
		if rope:IsA("BasePart") then
			local distance = (rope.Position - eye).Magnitude
			if distance < best then
				best = distance
				nearest = rope
			end
		end
	end
	if nearest then
		AudioController.playAt("RiggingCreak", nearest)
	end
end

-- ── Loop ──────────────────────────────────────────────────────────────────────────────────

function Ambient.init()
	collectSwings()
	collectLamps()
	collectBoards()
	puff = makePuff()
	-- Props built after start-up (a map rebuild) join in.
	CollectionService:GetInstanceAddedSignal("Creaky"):Connect(function(part)
		if part:IsA("BasePart") then
			table.insert(boards, { part = part, readyAt = 0 })
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		updateSwings(now, eye)

		accumulator += dt
		if accumulator < LOGIC_INTERVAL then
			return
		end
		accumulator = 0

		local character = Players.LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local root = if rootPart and rootPart:IsA("BasePart") then rootPart.Position else nil
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1

		local tension = dread()
		updateLamps(now, tension)
		updateBoards(now, root, moving)
		updateRipple(root)
		updateRiggingCreak(now, eye)
	end)
end

return Ambient
