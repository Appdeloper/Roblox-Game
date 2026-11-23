--!strict
--[[
	NearMiss — remembers your closest escape and replays it in slow motion.

	While you run, the last few seconds of you and your Copycat are kept in a small ring
	buffer (30 Hz). When the mannequin was reaching for you (Pose = "Reach") and you got away
	(no catch within a second), that moment is saved. "Near-miss replay" on the finish ticket
	plays it back: local stand-ins act it out at a third of the speed while the camera circles,
	with letterbox bars and the HUD hidden. Nothing here touches the real game.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Captions = require(script.Parent.Parent.UI.Captions)
local ClientState = require(script.Parent.Parent.ClientState)
local ClipMode = require(script.Parent.Parent.UI.ClipMode)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local NearMiss = {}

type Sample = { t: number, me: CFrame, them: CFrame?, pose: string? }

local RATE = 1 / 30
local buffer: { Sample } = {}
local saved: { Sample }? = nil
local savedDistance = math.huge
local pendingAt: number? = nil
local pendingDistance = math.huge
local accumulator = 0
local playing = false

local function myRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function myMannequin(): Model?
	local folder = Workspace:FindFirstChild("Mannequins")
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if
			m:IsA("Model")
			and m:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
			and m:GetAttribute("Role") == "Copycat"
		then
			return m
		end
	end
	return nil
end

local function record(now: number)
	local root = myRoot()
	if not root then
		return
	end
	local m = myMannequin()
	local theirs = m and m.PrimaryPart
	table.insert(buffer, {
		t = now,
		me = root.CFrame,
		them = if theirs then theirs.CFrame else nil,
		pose = if m then m:GetAttribute("Pose") :: string? else nil,
	})
	local keep = Config.Viral.ReplaySeconds + 1.5
	while #buffer > 0 and now - buffer[1].t > keep do
		table.remove(buffer, 1)
	end
	-- Near miss: it was reaching for you…
	if m and theirs and m:GetAttribute("Pose") == "Reach" then
		local d = (theirs.Position - root.Position).Magnitude
		if not pendingAt then
			pendingAt = now
			pendingDistance = d
		else
			pendingDistance = math.min(pendingDistance, d)
		end
	end
	-- …and a second later you're still running: keep it if it's the closest yet.
	if pendingAt and now - pendingAt > 1 then
		if pendingDistance < savedDistance then
			saved = table.clone(buffer)
			savedDistance = pendingDistance
			Captions.show("😱 Near miss! Watch it again from your ticket.", 1.8)
		end
		pendingAt = nil
		pendingDistance = math.huge
	end
end

function NearMiss.has(): boolean
	return saved ~= nil
end

--- A frozen, anchored stand-in for `model` (no scripts, no collisions).
local function standIn(model: Model): Model?
	local wasArchivable = model.Archivable
	model.Archivable = true
	local ok, copy = pcall(function()
		return model:Clone()
	end)
	model.Archivable = wasArchivable
	if not ok or not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	copy.Parent = Workspace
	return copy
end

local function letterbox(): { Frame }
	local overlay = UIRoot.get("Overlay")
	local bars = {}
	for i, y in { 0, 1 } do
		local bar = Widgets.frame(
			"Letterbox" .. i,
			overlay,
			UDim2.new(1, 0, 0.12, 0),
			UDim2.fromScale(0, y),
			Theme.Colors.Black
		)
		bar.AnchorPoint = Vector2.new(0, y)
		bar.ZIndex = 50
		table.insert(bars, bar)
	end
	local label = Widgets.label({
		name = "ReplayLabel",
		parent = bars[2],
		text = "REPLAY  ·  NEAR MISS  ·  ×" .. tostring(Config.Viral.ReplaySpeed),
		size = UDim2.fromScale(1, 1),
		font = Theme.Fonts.Title,
		color = Theme.Colors.WarmSpot,
		zIndex = 51,
	})
	local _ = label
	return bars :: any
end

--- Plays the saved near miss in slow motion. Returns false if there isn't one.
function NearMiss.play(): boolean
	local frames = saved
	if not frames or #frames < 2 or playing then
		return false
	end
	local character = Players.LocalPlayer.Character
	local mannequin = myMannequin()
	if not character then
		return false
	end
	playing = true
	local me = standIn(character)
	local them = if mannequin then standIn(mannequin) else nil
	local hiddenParts: { [BasePart]: number } = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			hiddenParts[d] = d.LocalTransparencyModifier
			d.LocalTransparencyModifier = 1
		end
	end
	local wasClip = ClipMode.isOn()
	ClipMode.set(true)
	local bars = letterbox()
	local camera = Workspace.CurrentCamera
	local previousType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable

	local t0, t1 = frames[1].t, frames[#frames].t
	local clock = 0
	local index = 1
	local done = false
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		clock += dt * Config.Viral.ReplaySpeed
		local t = t0 + clock
		while index < #frames and frames[index + 1].t < t do
			index += 1
		end
		local a = frames[index]
		local b = frames[math.min(index + 1, #frames)]
		local alpha = if b.t > a.t then math.clamp((t - a.t) / (b.t - a.t), 0, 1) else 0
		local mine = a.me:Lerp(b.me, alpha)
		if me then
			me:PivotTo(mine)
		end
		local theirs = if a.them and b.them then a.them:Lerp(b.them, alpha) else a.them
		if them and theirs then
			them:PivotTo(theirs)
		end
		-- Circle the pair slowly, a little above, so both are always in frame.
		local focus = if theirs then mine.Position:Lerp(theirs.Position, 0.5) else mine.Position
		local angle = clock * 0.8
		local eye = focus + Vector3.new(math.cos(angle) * 14, 6, math.sin(angle) * 14)
		camera.CFrame = CFrame.lookAt(eye, focus)
		if t >= t1 then
			done = true
			conn:Disconnect()
		end
	end)
	while not done do
		task.wait(0.1)
	end
	task.wait(0.4)
	for _, bar in bars do
		bar:Destroy()
	end
	if me then
		me:Destroy()
	end
	if them then
		them:Destroy()
	end
	for part, value in hiddenParts do
		if part.Parent then
			part.LocalTransparencyModifier = value
		end
	end
	camera.CameraType = previousType
	ClipMode.set(wasClip)
	playing = false
	return true
end

function NearMiss.init()
	RunService.Heartbeat:Connect(function(dt)
		if ClientState.phase ~= "Running" or playing then
			return
		end
		accumulator += dt
		if accumulator < RATE then
			return
		end
		accumulator = 0
		record(os.clock())
	end)
	-- Caught: the "escape" didn't happen, so the pending moment isn't a near miss.
	Remotes.get("Caught").OnClientEvent:Connect(function()
		pendingAt = nil
		pendingDistance = math.huge
	end)
	Remotes.get("RunStarted").OnClientEvent:Connect(function()
		table.clear(buffer)
	end)
end

return NearMiss
