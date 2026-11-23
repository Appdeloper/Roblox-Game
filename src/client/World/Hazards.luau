--!strict
--[[
	Hazards — moving set pieces, simulated locally so every player gets their own fair copy
	(a cardboard step that collapses under one player never drops another player).
	The player's character physics is client-owned, so local collision is what matters.

	  Backdrop        stage 2: descends when you approach, holds, rises; loops while you wait.
	  Collapse steps  stages 3 and 6: wobble when stepped on, drop after a delay, reset later.
	  Exits           stages 3 and 6: light under the real door only; the fakes are flat paint.

	Polled at ~15 Hz and only while you are in a stage that has these pieces.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zone = require(ReplicatedStorage.Shared.Zone)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local ClientState = require(script.Parent.Parent.ClientState)
local DoorEffects = require(script.Parent.DoorEffects)

local Hazards = {}

local POLL_INTERVAL = 1 / 15
-- Stages with a backdrop or collapsing steps (the only ones that need polling).
local HAZARD_STAGES = { [2] = true, [3] = true, [6] = true }

type Backdrop = {
	part: BasePart,
	rest: CFrame,
	closed: CFrame,
	trigger: Zone.Box,
	state: "Idle" | "Busy",
	token: number,
}

type Step = {
	part: BasePart,
	stage: number?,
	rest: CFrame,
	state: "Idle" | "Wobbling" | "Fallen",
	token: number,
}

local backdrop: Backdrop? = nil
local steps: { Step } = {}
local accumulator = 0

local function tween(instance: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?): Tween
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goals)
	t:Play()
	return t
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

-- ── Backdrop ──────────────────────────────────────────────────────────────────────────────

local function setupBackdrop(part: Instance)
	if backdrop or not part:IsA("BasePart") then
		return
	end
	local floorY = part:GetAttribute("FloorY")
	local triggerCF = part:GetAttribute("TriggerCFrame")
	local triggerSize = part:GetAttribute("TriggerSize")
	if type(floorY) ~= "number" or typeof(triggerCF) ~= "CFrame" or typeof(triggerSize) ~= "Vector3" then
		warn("[Hazards] backdrop is missing its attributes; it will stay up")
		return
	end
	local rest = part.CFrame
	local closedY = floorY + Config.Hazards.Backdrop.ClosedGap + part.Size.Y / 2
	backdrop = {
		part = part,
		rest = rest,
		closed = rest - Vector3.new(0, rest.Position.Y - closedY, 0),
		trigger = { cframe = triggerCF, size = triggerSize },
		state = "Idle",
		token = 0,
	}
end

local function cycleBackdrop(b: Backdrop)
	b.state = "Busy"
	b.token += 1
	local token = b.token
	local cfg = Config.Hazards.Backdrop
	AudioController.playAt("BackdropRumble", b.part)
	tween(b.part, cfg.DescendSeconds, { CFrame = b.closed }, Enum.EasingStyle.Sine)
	task.delay(cfg.DescendSeconds + cfg.HoldSeconds, function()
		if b.token ~= token then
			return
		end
		tween(b.part, cfg.RiseSeconds, { CFrame = b.rest }, Enum.EasingStyle.Sine)
		task.delay(cfg.RiseSeconds, function()
			if b.token == token then
				b.state = "Idle"
			end
		end)
	end)
end

local function resetBackdrop()
	local b = backdrop
	if b then
		b.token += 1
		b.state = "Idle"
		b.part.CFrame = b.rest
	end
end

-- ── Collapsing steps ──────────────────────────────────────────────────────────────────────

local function addStep(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	for _, step in steps do
		if step.part == part then
			return
		end
	end
	local stage = part:GetAttribute("Stage")
	table.insert(steps, {
		part = part,
		stage = if type(stage) == "number" then stage else 3,
		rest = part.CFrame,
		state = "Idle",
		token = 0,
	})
end

local function standingOn(step: Step, pos: Vector3): boolean
	local rel = step.rest:PointToObjectSpace(pos)
	local half = step.part.Size / 2
	local above = rel.Y - half.Y
	return math.abs(rel.X) <= half.X + 0.6 and math.abs(rel.Z) <= half.Z + 0.6 and above > 1 and above < 5
end

local function collapse(step: Step)
	local cfg = Config.Hazards.Staircase
	step.state = "Wobbling"
	step.token += 1
	local token = step.token
	local wobble = math.min(cfg.WobbleSeconds, cfg.CollapseDelay)
	-- Visible warning: a quick rocking wobble.
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < wobble and step.token == token do
			local t = os.clock() - started
			step.part.CFrame = step.rest * CFrame.Angles(0, 0, math.sin(t * 40) * math.rad(3))
			task.wait()
		end
	end)
	task.delay(cfg.CollapseDelay, function()
		if step.token ~= token then
			return
		end
		step.state = "Fallen"
		step.part.CanCollide = false
		AudioController.playAt("CardboardCrumple", step.part)
		tween(step.part, cfg.FallSeconds, {
			CFrame = step.rest * CFrame.new(0, -cfg.FallDistance, 0) * CFrame.Angles(0.6, 0, 0.4),
			Transparency = 1,
		}, Enum.EasingStyle.Quad)
		task.delay(cfg.ResetSeconds, function()
			if step.token == token then
				Hazards.resetStep(step)
			end
		end)
	end)
end

function Hazards.resetStep(step: Step)
	step.token += 1
	step.state = "Idle"
	step.part.CFrame = step.rest
	step.part.Transparency = 0
	step.part.CanCollide = true
end

-- ── Exits ─────────────────────────────────────────────────────────────────────────────────

local function setupExits(stage: number, realExit: string?)
	for _, side in DoorEffects.exitNames(stage) do
		local key = "Exit/" .. side
		local isReal = realExit == side
		DoorEffects.setGlow(key, isReal)
		local door = DoorEffects.get(key)
		if door and door.panel then
			-- The fake is painted flat onto the set: subtly less "wooden" for sharp eyes.
			door.panel.Material = if isReal then Enum.Material.WoodPlanks else Enum.Material.SmoothPlastic
		end
	end
end

function Hazards.onFakeExit(fakeSide: string)
	local door = DoorEffects.get("Exit/" .. fakeSide)
	if door and door.panel then
		AudioController.playAt("FakeExitBonk", door.panel)
	end
	DoorEffects.jiggle("Exit/" .. fakeSide)
end

-- ── Loop ──────────────────────────────────────────────────────────────────────────────────

local function poll()
	local pos = rootPosition()
	if not pos then
		return
	end
	local stage = ClientState.stage
	if stage == 2 and backdrop and backdrop.state == "Idle" and Zone.contains(backdrop.trigger, pos) then
		cycleBackdrop(backdrop)
	else
		for _, step in steps do
			if step.state == "Idle" and step.stage == stage and standingOn(step, pos) then
				collapse(step)
			end
		end
	end
end

--- Restores every hazard (on each stage start / retake, so retakes are always fair).
function Hazards.resetAll()
	resetBackdrop()
	for _, step in steps do
		Hazards.resetStep(step)
	end
end

function Hazards.onStageStarted(stage: number, realExit: string?)
	Hazards.resetAll()
	if realExit then
		setupExits(stage, realExit)
	end
end

function Hazards.init()
	for _, part in CollectionService:GetTagged("Backdrop") do
		setupBackdrop(part)
	end
	for _, part in CollectionService:GetTagged("CollapseStep") do
		addStep(part)
	end
	-- Pieces that replicate after start-up are picked up too.
	CollectionService:GetInstanceAddedSignal("Backdrop"):Connect(setupBackdrop)
	CollectionService:GetInstanceAddedSignal("CollapseStep"):Connect(addStep)
	RunService.Heartbeat:Connect(function(dt)
		if ClientState.phase ~= "Running" or not HAZARD_STAGES[ClientState.stage] then
			return
		end
		accumulator += dt
		if accumulator >= POLL_INTERVAL then
			accumulator = 0
			poll()
		end
	end)
end

return Hazards
