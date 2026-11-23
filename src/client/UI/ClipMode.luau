--!strict
--[[
	ClipMode — tools for recording and sharing (everything here is local to your screen).

	  Clip Mode     the 🎥 button hides the HUD and Roblox's own menus for clean recordings.
	                Only the jump button stays (faded) so you can still play; tap the small
	                ⏺ in the corner to bring everything back.
	  Photo spots   stand on a 📸 PHOTO SPOT pad and a "Strike a pose" button appears: the
	                camera frames you from the pad's angle, counts down, and snaps.
	  Snapshot      asks Roblox to capture the screen and offers to share/save it (where the
	                device supports it), plus a friend invite. All calls are optional (pcall).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local CameraEffects = require(script.Parent.Parent.Camera.CameraEffects)
local Captions = require(script.Parent.Captions)
local UIRoot = require(script.Parent.UIRoot)
local Widgets = require(script.Parent.Widgets)

local ClipMode = {}

local on = false
local hidden: { [GuiObject]: boolean } = {}
local exitButton: TextButton
local poseButton: TextButton
local currentSpot: BasePart? = nil
local posing = false
-- Kept visible (faded) in Clip Mode: you still need to jump while recording.
local KEEP = { BigJump = true, ClipExit = true }

local function setCoreGui(enabled: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, enabled)
	end)
end

function ClipMode.isOn(): boolean
	return on
end

function ClipMode.set(enabled: boolean)
	if enabled == on then
		return
	end
	on = enabled
	local hud = UIRoot.get("Hud")
	if enabled then
		table.clear(hidden)
		for _, child in hud:GetChildren() do
			if child:IsA("GuiObject") and not KEEP[child.Name] and child.Visible then
				hidden[child] = true
				child.Visible = false
			end
		end
		local jump = hud:FindFirstChild("BigJump")
		if jump and jump:IsA("GuiObject") then
			jump.BackgroundTransparency = 0.75
		end
		setCoreGui(false)
	else
		for child in hidden do
			if child.Parent then
				child.Visible = true
			end
		end
		table.clear(hidden)
		local jump = hud:FindFirstChild("BigJump")
		if jump and jump:IsA("GuiObject") then
			jump.BackgroundTransparency = 0.15
		end
		setCoreGui(true)
	end
	exitButton.Visible = enabled and not posing
end

--- Captures the screen and offers to share it, where the platform allows. Never errors.
function ClipMode.snapshot()
	local ok = pcall(function()
		local CaptureService = game:GetService("CaptureService") :: any
		CaptureService:CaptureScreenshot(function(contentId)
			pcall(function()
				CaptureService:PromptShareCapture(contentId, "", {}, function() end)
			end)
		end)
	end)
	if not ok then
		Captions.show("Snap! (Use your device's screenshot to keep it.)", 2.5)
	end
end

function ClipMode.inviteFriends()
	pcall(function()
		game:GetService("SocialService"):PromptGameInvite(Players.LocalPlayer)
	end)
end

-- ── Photo spots ──────────────────────────────────────────────────────────────────────────

local function rootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function spotUnder(pos: Vector3): BasePart?
	for _, spot in CollectionService:GetTagged("PhotoSpot") do
		if spot:IsA("BasePart") then
			local rel = spot.CFrame:PointToObjectSpace(pos)
			if
				math.abs(rel.X) <= spot.Size.X / 2
				and math.abs(rel.Z) <= spot.Size.Z / 2
				and rel.Y > 0
				and rel.Y < 6
			then
				return spot
			end
		end
	end
	return nil
end

local function pose()
	local spot = currentSpot
	local root = rootPart()
	if not spot or not root or posing then
		return
	end
	posing = true
	poseButton.Visible = false
	local wasOn = on
	ClipMode.set(true)
	exitButton.Visible = false
	local camera = Workspace.CurrentCamera
	local offset = spot:GetAttribute("CameraOffset")
	local eye = spot.Position + (if typeof(offset) == "Vector3" then offset else Vector3.new(0, 6, 14))
	local previousType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local follow = RunService.RenderStepped:Connect(function()
		local r = rootPart()
		if r then
			camera.CFrame = CFrame.lookAt(eye, r.Position + Vector3.new(0, 1, 0))
		end
	end)
	for i = Config.Viral.PhotoCountdown, 1, -1 do
		Captions.show(string.format("📸  Strike a pose!  %d", i), 1)
		AudioController.play("UiClick")
		task.wait(1)
	end
	CameraEffects.flash(Theme.Colors.Paper)
	ClipMode.snapshot()
	task.wait(1.2)
	follow:Disconnect()
	camera.CameraType = previousType
	posing = false
	ClipMode.set(wasOn)
end

local function watchSpots()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		local root = rootPart()
		currentSpot = if root then spotUnder(root.Position) else nil
		poseButton.Visible = currentSpot ~= nil and not posing
	end)
end

function ClipMode.init()
	local hud = UIRoot.get("Hud")
	Widgets.button({
		name = "ClipButton",
		parent = hud,
		text = "🎥",
		size = UDim2.fromOffset(64, 64),
		position = UDim2.new(1, -82, 0, 8),
		anchor = Vector2.new(1, 0),
		color = Theme.Colors.UiDark,
		textColor = Theme.Colors.Paper,
	}, function()
		AudioController.play("UiClick")
		ClipMode.set(true)
		Captions.show("Clip Mode: the HUD is hidden. Tap ⏺ to bring it back.", 2)
		task.delay(2.1, function()
			if on then
				local caption = hud:FindFirstChild("Caption", true)
				if caption and caption:IsA("GuiObject") then
					caption.Visible = false
				end
			end
		end)
	end)
	exitButton = Widgets.button({
		name = "ClipExit",
		parent = hud,
		text = "⏺",
		size = UDim2.fromOffset(44, 44),
		position = UDim2.new(1, -10, 0, 10),
		anchor = Vector2.new(1, 0),
		color = Theme.Colors.UiDark,
		textColor = Theme.Colors.UiDanger,
	}, function()
		ClipMode.set(false)
	end)
	exitButton.BackgroundTransparency = 0.6
	exitButton.Visible = false
	poseButton = Widgets.button({
		name = "PoseButton",
		parent = hud,
		text = "📸  Strike a pose",
		size = UDim2.fromOffset(260, 70),
		position = UDim2.new(0.5, 0, 1, -250),
		anchor = Vector2.new(0.5, 1),
		color = Theme.Colors.UiAccent,
	}, function()
		task.spawn(pose)
	end)
	poseButton.Visible = false
	watchSpots()
end

return ClipMode
