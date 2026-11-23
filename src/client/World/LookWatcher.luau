--!strict
--[[
	LookWatcher — the client half of the "Don't Look" rule.

	  * Every 0.1 s it checks whether the camera is looking at one of YOUR mannequins (view cone
	    from LookRule + a line-of-sight ray) and reports changes to the server ("LookState").
	    The server decides what happens; this module only reports and shows.
	  * A stare meter under the timer fills while you look (the server publishes it on each
	    mannequin as the "Stare" attribute), so the rule is readable on a phone without audio.
	  * Stared too long (StareLunge): the guide lamps flicker and a caption explains why.
	    With Reduced Scares on, the lamps just dip once.
	  * The first time a mannequin starts chasing you in a session, a caption teaches the rule.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LookRule = require(ReplicatedStorage.Shared.LookRule)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local Captions = require(script.Parent.Parent.UI.Captions)
local ClientState = require(script.Parent.Parent.ClientState)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local LookWatcher = {}

local CHECK_INTERVAL = 0.1
local MIN_SEND_INTERVAL = 0.25

local player = Players.LocalPlayer
local reported = ""
local lastSentAt = -math.huge
local accumulator = 0
local hinted = false

local meterFrame: Frame
local meterFill: Frame
local meterLabel: TextLabel

local function ownMannequins(): { Model }
	local out = {}
	for _, model in CollectionService:GetTagged("Mannequin") do
		if
			model:IsA("Model")
			and model:GetAttribute("OwnerUserId") == player.UserId
			and model:GetAttribute("Hidden") ~= true
		then
			table.insert(out, model)
		end
	end
	return out
end

local function lineOfSight(from: Vector3, model: Model, root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { model }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(from, root.Position - from, params)
	return hit == nil
end

--- Name of the own mannequin the camera is looking at, or "".
function LookWatcher.target(): string
	local camera = Workspace.CurrentCamera
	if not camera then
		return ""
	end
	local look = Config.Mannequin.Look
	local eye = camera.CFrame.Position
	local forward = camera.CFrame.LookVector
	local best, bestDot = "", -1
	for _, model in ownMannequins() do
		local root = model.PrimaryPart
		if root then
			-- Aim at the chest, not the feet.
			local offset = (root.Position + Vector3.new(0, 0.8, 0)) - eye
			local distance = offset.Magnitude
			local dot = if distance > 1e-3 then forward:Dot(offset / distance) else 1
			if
				dot > bestDot
				and LookRule.inCone(dot, distance, look.MaxAngleDegrees, look.MaxRange)
				and lineOfSight(eye, model, root)
			then
				best, bestDot = model.Name, dot
			end
		end
	end
	return best
end

local function report(name: string, now: number)
	if name == reported or now - lastSentAt < MIN_SEND_INTERVAL then
		return
	end
	reported = name
	lastSentAt = now
	Remotes.get("LookState"):FireServer(name)
end

local function maxStare(): number
	local best = 0
	for _, model in ownMannequins() do
		local v = model:GetAttribute("Stare")
		if type(v) == "number" then
			best = math.max(best, v)
		end
	end
	return best
end

local function anyChasing(): boolean
	for _, model in ownMannequins() do
		local pose = model:GetAttribute("Pose")
		if pose ~= nil and pose ~= "Idle" then
			return true
		end
	end
	return false
end

local function updateMeter()
	local stare = if ClientState.phase == "Running" then maxStare() else 0
	meterFrame.Visible = stare > 0
	meterFill.Size = UDim2.fromScale(stare, 1)
	local danger = stare >= 0.6
	meterFill.BackgroundColor3 = if danger then Theme.Colors.UiDanger else Theme.Colors.UiAccent
	meterLabel.Text = if danger then "👁  DON'T STARE!" else "👁  It's frozen while you watch"
end

local function step(dt: number)
	accumulator += dt
	if accumulator < CHECK_INTERVAL then
		return
	end
	accumulator = 0
	local now = os.clock()
	if ClientState.phase ~= "Running" then
		report("", now)
	else
		report(LookWatcher.target(), now)
		if not hinted and anyChasing() then
			hinted = true
			Captions.show(Config.Text.LookHint, 4)
		end
	end
	updateMeter()
end

--- Guide lamps stutter for a moment (the "you stared too long" beat).
local function flickerLamps()
	local reduced = ClientState.reducedScares
	for _, part in CollectionService:GetTagged("GuideLamp") do
		local light = part:FindFirstChildWhichIsA("Light")
		if light then
			local base = light.Brightness
			if reduced then
				local dip = TweenService:Create(light, TweenInfo.new(0.2), { Brightness = base * 0.4 })
				dip:Play()
				task.delay(0.35, function()
					TweenService:Create(light, TweenInfo.new(0.3), { Brightness = base }):Play()
				end)
			else
				task.spawn(function()
					for i = 1, 5 do
						light.Brightness = if i % 2 == 1 then base * 0.1 else base
						task.wait(0.06 + (i % 3) * 0.03)
					end
					light.Brightness = base
				end)
			end
		end
	end
end

local function onStareLunge(name: string)
	flickerLamps()
	AudioController.play("LampBuzz")
	local model = Workspace:FindFirstChild("Mannequins")
	local mannequin = model and model:FindFirstChild(name)
	local root = mannequin and (mannequin :: Model).PrimaryPart
	if root then
		AudioController.playAt("FloorCreak", root)
	end
	Captions.show(Config.Text.StareLunge, 2.2)
end

local function onMirrorCracked()
	AudioController.play("CardboardCrumple")
	Captions.show(Config.Text.MirrorCracked, 2)
end

function LookWatcher.init()
	local hud = UIRoot.get("Hud")
	meterFrame =
		Widgets.frame("StareMeter", hud, UDim2.fromOffset(240, 34), UDim2.new(0.5, 0, 0, 72), Theme.Colors.UiDark, 0.25)
	meterFrame.AnchorPoint = Vector2.new(0.5, 0)
	meterFrame.Visible = false
	Widgets.corner(meterFrame, 10)
	meterFill = Widgets.frame("Fill", meterFrame, UDim2.fromScale(0, 1), nil, Theme.Colors.UiAccent, 0.2)
	Widgets.corner(meterFill, 10)
	meterLabel = Widgets.label({
		name = "Label",
		parent = meterFrame,
		text = "",
		size = UDim2.new(1, -16, 1, -8),
		position = UDim2.fromOffset(8, 4),
		font = Theme.Fonts.Bold,
		color = Theme.Colors.Paper,
		zIndex = 2,
	})

	Remotes.get("StareLunge").OnClientEvent:Connect(onStareLunge)
	Remotes.get("MirrorCracked").OnClientEvent:Connect(onMirrorCracked)
	RunService.Heartbeat:Connect(step)
end

return LookWatcher
