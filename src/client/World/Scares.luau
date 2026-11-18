--!strict
--[[
	Scares — the three scripted, once-per-run moments. Design rules (ages 9–17, mobile):
	  * Telegraphed: a caption announces what is happening before or as it happens.
	  * Readable: big, slow, well-lit motion — no gore, nothing pops at the camera.
	  * Skippable-friendly: never blocks movement; a Skip button ends the effect instantly.
	  * Reduced Scares: no shakes/flashes (CameraEffects already gates those).
	The server freezes the mannequin and pauses catching while a scare plays.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local MannequinRig = require(ReplicatedStorage.Shared.MannequinRig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local CameraEffects = require(script.Parent.Parent.Camera.CameraEffects)
local Captions = require(script.Parent.Parent.UI.Captions)
local ClientState = require(script.Parent.Parent.ClientState)
local DoorEffects = require(script.Parent.DoorEffects)

local Scares = {}

local token = 0
local playing = false
local cleanup: { Instance } = {}
local fxFolder: Folder

local function alive(myToken: number): boolean
	return token == myToken
end

--- Registers a local-only instance to be destroyed when the scare ends or is skipped.
local function track(instance: Instance)
	table.insert(cleanup, instance)
end

local function finish()
	playing = false
	for _, instance in cleanup do
		instance:Destroy()
	end
	table.clear(cleanup)
end

local function skip(stage: number)
	token += 1
	finish()
	Remotes.get("ScareSkipped"):FireServer(stage)
end

local function caption(stage: number, text: string, seconds: number?)
	Captions.show(text, seconds, function()
		skip(stage)
	end)
end

local function taggedInStage(tag: string, stage: number): Instance?
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:GetAttribute("Stage") == stage then
			return inst
		end
	end
	return nil
end

local function localPart(name: string, size: Vector3, cf: CFrame, color: Color3, transparency: number?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Parent = fxFolder
	track(part)
	return part
end

-- ── Stage 1: the shadow takes a bow ───────────────────────────────────────────────────────

--- Builds a flat silhouette on the curtain plane. Returns upper-body parts (which bow) and the waist pivot.
local function buildShadow(feet: CFrame): ({ [BasePart]: CFrame }, CFrame)
	local ink = Theme.Colors.Black
	-- feet: origin on the curtain, X = into the curtain, Y = up, Z = sideways along the curtain.
	local function piece(name: string, height: number, width: number, y: number, z: number): Part
		return localPart(name, Vector3.new(0.05, height, width), feet * CFrame.new(0, y, z), ink, 0.25)
	end
	piece("ShadowLegL", 3.2, 0.9, 1.6, -0.55)
	piece("ShadowLegR", 3.2, 0.9, 1.6, 0.55)
	local upper = {
		piece("ShadowTorso", 2.9, 2.9, 4.65, 0),
		piece("ShadowHead", 1.8, 1.8, 7.0, 0),
		piece("ShadowArmL", 3, 0.8, 4.4, -1.9),
		piece("ShadowArmR", 3, 0.8, 4.4, 1.9),
	}
	local waist = feet * CFrame.new(0, 3.2, 0)
	local offsets: { [BasePart]: CFrame } = {}
	for _, p in upper do
		offsets[p] = waist:ToObjectSpace(p.CFrame)
	end
	return offsets, waist
end

local function shadowBow(myToken: number)
	local cfg = Config.Scares.Stage1
	local screen = taggedInStage("ShadowScreen", 1)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not screen or not screen:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return
	end
	-- The curtain's audience-facing plane (it faces -X toward the house).
	local planeX = screen.Position.X - screen.Size.X / 2 - 0.06
	local floorY = screen.Position.Y - screen.Size.Y / 2
	local z = math.clamp(
		root.Position.Z,
		screen.Position.Z - screen.Size.Z / 2 + 3,
		screen.Position.Z + screen.Size.Z / 2 - 3
	)
	local feet = CFrame.new(planeX, floorY, z)
	local upper, waist = buildShadow(feet)

	-- A warm spotlight fades up from the front (no flash).
	local lamp = localPart(
		"ScareSpot",
		Vector3.one,
		CFrame.lookAt(Vector3.new(planeX - 45, floorY + 16, z), feet.Position + Vector3.new(0, 5, 0)),
		Theme.Colors.UiDark,
		1
	)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Color = Theme.Colors.WarmSpot
	spot.Range = 60
	spot.Angle = 30
	spot.Brightness = 0
	spot.Parent = lamp
	TweenService:Create(spot, TweenInfo.new(0.8), { Brightness = 4 }):Play()
	AudioController.play("ShadowBow")
	caption(1, "A spotlight finds you… and your shadow takes a bow.", cfg.ShadowBowSeconds + 1)

	local bowValue = Instance.new("NumberValue")
	track(bowValue)
	bowValue.Changed:Connect(function(alpha: number)
		-- Bow sideways in the curtain plane (reads clearly as a bow in silhouette).
		local pose = waist * CFrame.Angles(math.rad(55) * alpha, 0, 0)
		for part, offset in upper do
			part.CFrame = pose * offset
		end
	end)
	local bowInfo = TweenInfo.new(cfg.ShadowBowSeconds / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true)
	TweenService:Create(bowValue, bowInfo, { Value = 1 }):Play()

	task.delay(cfg.MannequinBowDelay, function()
		if alive(myToken) then
			caption(1, "…and something behind you finishes the bow.", cfg.MannequinBowSeconds + 1)
		end
	end)
	task.delay(cfg.MannequinBowDelay + cfg.MannequinBowSeconds + 1.2, function()
		if alive(myToken) then
			TweenService:Create(spot, TweenInfo.new(0.8), { Brightness = 0 }):Play()
			task.delay(0.9, function()
				if alive(myToken) then
					finish()
				end
			end)
		end
	end)
end

-- ── Stage 2: someone walks past the upstairs windows ──────────────────────────────────────

local function windowWalk(myToken: number)
	local cfg = Config.Scares.Stage2
	local marker = taggedInStage("WindowWalk", 2)
	if not marker then
		return
	end
	local from = marker:GetAttribute("From") :: Vector3
	local to = marker:GetAttribute("To") :: Vector3
	local rig = MannequinRig.build("WindowPuppet", CFrame.lookAt(from, to))
	rig.root.Anchored = true
	rig.model:SetAttribute("Pose", "Walk")
	rig.model.Parent = fxFolder
	track(rig.model)
	local glow = Instance.new("PointLight")
	glow.Color = Theme.Colors.Window
	glow.Range = 9
	glow.Brightness = 1.5
	glow.Parent = rig.root
	caption(2, "Look up! Someone is walking past the upstairs windows…", cfg.WindowWalkSeconds)
	TweenService:Create(rig.root, TweenInfo.new(cfg.WindowWalkSeconds, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(to, to + (to - from).Unit),
	}):Play()

	task.delay(cfg.WindowWalkSeconds, function()
		if not alive(myToken) then
			return
		end
		caption(2, "A brass handle beside the landing starts turning.", Config.Scares.CaptionSeconds)
		for _, door in CollectionService:GetTagged("PaintedDoor") do
			if door:GetAttribute("Stage") == 2 and door:GetAttribute("Role") == "Exit" then
				DoorEffects.warn(tostring(door:GetAttribute("DoorId")) .. "/Exit", 3, cfg.HandleTurns)
			end
		end
		finish()
	end)
end

-- ── Stage 3: one polite knock, then applause ──────────────────────────────────────────────

local function bounceAudience(myToken: number)
	for _, seat in CollectionService:GetTagged("AudienceSeat") do
		if seat:IsA("BasePart") then
			local base = seat.CFrame
			local info =
				TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 6, true, math.random() * 0.3)
			TweenService:Create(seat, info, { CFrame = base + Vector3.new(0, 0.35, 0) }):Play()
			task.delay(3, function()
				if seat.Parent and not alive(myToken) then
					seat.CFrame = base
				end
			end)
		end
	end
end

local function knockAndApplause(myToken: number)
	local cfg = Config.Scares.Stage3
	local info = ClientState.stageInfo
	local fakeSide = if info and info.realExit == "Left" then "Right" else "Left"
	local fakeDoor = DoorEffects.get("Exit/" .. fakeSide)
	if fakeDoor and fakeDoor.panel then
		AudioController.playAt("Knock", fakeDoor.panel)
	end
	DoorEffects.jiggle("Exit/" .. fakeSide)
	CameraEffects.shake(0.12, 0.2)
	caption(3, "Knock.  (One polite knock…)", cfg.KnockToApplauseSeconds + 0.5)
	task.delay(cfg.KnockToApplauseSeconds, function()
		if not alive(myToken) then
			return
		end
		AudioController.play("Applause")
		bounceAudience(myToken)
		caption(3, "…then applause from the empty seats. Take your exit!", cfg.ApplauseSeconds)
		task.delay(cfg.ApplauseSeconds, function()
			if alive(myToken) then
				finish()
			end
		end)
	end)
end

-- ── API ───────────────────────────────────────────────────────────────────────────────────

local SCARES = { shadowBow, windowWalk, knockAndApplause }

function Scares.init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "LocalScareFX"
	fxFolder.Parent = Workspace
end

function Scares.play(stage: number)
	local scare = SCARES[stage]
	if not scare or playing then
		return
	end
	playing = true
	token += 1
	scare(token)
end

--- Called on retakes / leaving: ends any scare in progress without notifying the server.
function Scares.stop()
	token += 1
	finish()
end

return Scares
