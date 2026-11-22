--!strict
--[[
	DoorEffects — local-only animation of painted doors and exit doors.

	The server tells only the owning player about *their* mannequin's door, so a warning
	never confuses anyone else on the server:
	  DoorWarning → exit door handle turns (looping), warm light glows under it, creak.
	  DoorOpened  → the leaf swings open on its hinge, then closes again.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local AudioController = require(script.Parent.Parent.Audio.AudioController)

local DoorEffects = {}

type DoorVisual = {
	model: Model,
	hinge: CFrame,
	leafParts: { [BasePart]: CFrame },
	handle: BasePart?,
	handleBase: CFrame?,
	panel: BasePart?,
	glow: BasePart?,
	spill: { { part: BasePart, opacity: number } },
	light: Light?,
	token: number,
}

-- painted doors: key "doorId/Role"; real/fake exits: key "Exit/<name>" (names are unique).
local doors: { [string]: DoorVisual } = {}

--- Names of the exit doors that belong to `stage` (from the model's Stage attribute).
function DoorEffects.exitNames(stage: number): { string }
	local out = {}
	for key, door in doors do
		if string.sub(key, 1, 5) == "Exit/" and door.model:GetAttribute("Stage") == stage then
			table.insert(out, string.sub(key, 6))
		end
	end
	table.sort(out)
	return out
end

local function register(model: Instance, key: string)
	if not model:IsA("Model") then
		return
	end
	local hinge = model:GetAttribute("HingeCFrame")
	local leaf = model:FindFirstChild("Leaf")
	if typeof(hinge) ~= "CFrame" or not leaf then
		return
	end
	local parts: { [BasePart]: CFrame } = {}
	for _, d in leaf:GetDescendants() do
		if d:IsA("BasePart") then
			parts[d] = d.CFrame
		end
	end
	local handle = leaf:FindFirstChild("Handle")
	local glow = model:FindFirstChild("UnderGlow")
	-- The floor spill in front of the door: built hidden, revealed with the glow. Each
	-- panel carries its own target opacity so the light fades out with distance.
	local spill: { { part: BasePart, opacity: number } } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 5) == "Spill" then
			local opacity = child:GetAttribute("Opacity")
			table.insert(spill, { part = child, opacity = if type(opacity) == "number" then opacity else 0.6 })
		end
	end
	doors[key] = {
		spill = spill,
		model = model,
		hinge = hinge,
		leafParts = parts,
		handle = if handle and handle:IsA("BasePart") then handle else nil,
		handleBase = if handle and handle:IsA("BasePart") then handle.CFrame else nil,
		panel = leaf:FindFirstChild("Panel") :: BasePart?,
		glow = if glow and glow:IsA("BasePart") then glow else nil,
		light = if glow then glow:FindFirstChildWhichIsA("Light") else nil,
		token = 0,
	}
end

--- Drives a 0..1 value over time, calling apply(alpha) each frame (tweens any custom math).
local function animateValue(seconds: number, style: Enum.EasingStyle, apply: (number) -> ()): Tween
	local value = Instance.new("NumberValue")
	value.Changed:Connect(apply)
	local tween = TweenService:Create(value, TweenInfo.new(seconds, style, Enum.EasingDirection.InOut), { Value = 1 })
	tween.Completed:Once(function()
		value:Destroy()
	end)
	tween:Play()
	return tween
end

local function setGlow(door: DoorVisual, on: boolean)
	if door.glow then
		TweenService:Create(door.glow, TweenInfo.new(0.4), { Transparency = if on then 0.15 else 1 }):Play()
	end
	if door.light then
		door.light.Enabled = on
	end
	for _, panel in door.spill do
		TweenService:Create(panel.part, TweenInfo.new(0.5), {
			Transparency = if on then 1 - panel.opacity else 1,
		}):Play()
	end
end

local function setLeafAngle(door: DoorVisual, degrees: number)
	local rotation = door.hinge * CFrame.Angles(0, math.rad(degrees), 0)
	for part, base in door.leafParts do
		part.CFrame = rotation * door.hinge:ToObjectSpace(base)
	end
end

--- Turns the lever handle down and back up once.
local function turnHandleOnce(door: DoorVisual)
	local handle, base = door.handle, door.handleBase
	if not handle or not base then
		return
	end
	-- Pivot at the spindle end (toward the door's edge).
	local pivot = base * CFrame.new(handle.Size.X / 2 - 0.1, 0, 0)
	local offset = pivot:ToObjectSpace(base)
	local degrees = Config.Door.HandleTurnDegrees
	animateValue(Config.Door.HandleTurnSeconds * 2, Enum.EasingStyle.Sine, function(alpha)
		local angle = math.sin(alpha * math.pi) * math.rad(degrees)
		handle.CFrame = pivot * CFrame.Angles(0, 0, angle) * offset
	end)
end

local function resetDoor(door: DoorVisual)
	door.token += 1
	setLeafAngle(door, 0)
	if door.handle and door.handleBase then
		door.handle.CFrame = door.handleBase
	end
	setGlow(door, false)
end

local function registerPainted(model: Instance)
	register(model, tostring(model:GetAttribute("DoorId")) .. "/" .. tostring(model:GetAttribute("Role")))
end

local function registerExit(model: Instance)
	register(model, "Exit/" .. tostring(model:GetAttribute("Side")))
end

function DoorEffects.init()
	for _, model in CollectionService:GetTagged("PaintedDoor") do
		registerPainted(model)
	end
	for _, model in CollectionService:GetTagged("StageExitDoor") do
		registerExit(model)
	end
	-- Late replication (or a map rebuild) still gets registered.
	CollectionService:GetInstanceAddedSignal("PaintedDoor"):Connect(registerPainted)
	CollectionService:GetInstanceAddedSignal("StageExitDoor"):Connect(registerExit)
end

function DoorEffects.get(key: string): DoorVisual?
	return doors[key]
end

--- Handle turns `turns` times (or until stopped), with light under the door.
function DoorEffects.warn(key: string, seconds: number, turns: number?)
	local door = doors[key]
	if not door then
		return
	end
	door.token += 1
	local token = door.token
	setGlow(door, true)
	if door.panel then
		AudioController.playAt("DoorCreak", door.panel)
	end
	local period = Config.Door.HandleTurnSeconds * 2 + 0.25
	local count = turns or math.max(1, math.floor(seconds / period))
	task.spawn(function()
		for _ = 1, count do
			if door.token ~= token then
				return
			end
			turnHandleOnce(door)
			task.wait(period)
		end
	end)
	-- Failsafe: never leave a door glowing if the "opened" message never arrives.
	task.delay(seconds + 4, function()
		if door.token == token then
			resetDoor(door)
		end
	end)
end

function DoorEffects.open(key: string)
	local door = doors[key]
	if not door then
		return
	end
	door.token += 1
	local token = door.token
	setGlow(door, true)
	if door.panel then
		AudioController.playAt("DoorOpen", door.panel)
	end
	animateValue(0.45, Enum.EasingStyle.Back, function(alpha)
		setLeafAngle(door, 80 * alpha)
	end)
	task.delay(2.5, function()
		if door.token ~= token then
			return
		end
		animateValue(0.6, Enum.EasingStyle.Quad, function(alpha)
			setLeafAngle(door, 80 * (1 - alpha))
		end)
		setGlow(door, false)
	end)
end

--- Tiny shake of a door (fake exit bump, polite knock).
function DoorEffects.jiggle(key: string)
	local door = doors[key]
	if not door then
		return
	end
	animateValue(0.3, Enum.EasingStyle.Sine, function(alpha)
		setLeafAngle(door, math.sin(alpha * math.pi * 4) * 2 * (1 - alpha))
	end)
end

function DoorEffects.setGlow(key: string, on: boolean)
	local door = doors[key]
	if door then
		setGlow(door, on)
	end
end

function DoorEffects.resetAll()
	for _, door in doors do
		resetDoor(door)
	end
end

return DoorEffects
