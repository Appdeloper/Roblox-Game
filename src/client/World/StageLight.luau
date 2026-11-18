--!strict
--[[
	StageLight — the scripted lighting beats that belong to a scare.

	  snapOn    a spotlight slams on and holds, then fades out
	  lampDie   the nearest working lamp dims, stutters and goes out for good
	  flood     every guide lamp in the room swells, then settles

	House rules, so this never becomes a cheap jump-scare:
	  * each beat is asked for by a scare that has already put a caption on screen,
	  * nothing is ever aimed at the camera,
	  * with Reduced Scares on, a "snap" becomes a soft fade and a dying lamp just
	    dims instead of stuttering.
	Every light created here is cleaned up by `StageLight.clear()` when the scare ends.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local ClientState = require(script.Parent.Parent.ClientState)

local StageLight = {}

local folder: Folder
local temporary: { Instance } = {}
-- Bumped by clear(); every deferred step checks it before touching anything, so a scare
-- that ends early can never poke a light it already destroyed.
local generation = 0
-- Lamps killed by a scare, so they can be brought back when the run restarts.
local extinguished: { { light: Light, brightness: number } } = {}

local function track(instance: Instance): Instance
	table.insert(temporary, instance)
	return instance
end

function StageLight.init()
	folder = Instance.new("Folder")
	folder.Name = "LocalStageLight"
	folder.Parent = Workspace
end

--- A spotlight that comes on hard and holds, aimed at `target` from `from`.
--- Never aimed at the player's camera: callers pass a point on the set.
function StageLight.snapOn(from: Vector3, target: Vector3, seconds: number, color: Color3?)
	local can = Instance.new("Part")
	can.Name = "ScareSpot"
	can.Anchored = true
	can.CanCollide = false
	can.CanTouch = false
	can.CanQuery = false
	can.CastShadow = false
	can.Transparency = 1
	can.Size = Vector3.one
	can.CFrame = CFrame.lookAt(from, target)
	can.Parent = folder
	track(can)

	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Color = color or Theme.Colors.WarmSpot
	spot.Range = math.min((target - from).Magnitude + 25, 60)
	spot.Angle = 42
	spot.Shadows = true
	spot.Brightness = 0
	spot.Parent = can

	local attack = if ClientState.reducedScares then 0.45 else 0.06
	local myGeneration = generation
	TweenService:Create(spot, TweenInfo.new(attack), { Brightness = 5 }):Play()
	task.delay(seconds, function()
		if myGeneration == generation then
			TweenService:Create(spot, TweenInfo.new(0.8), { Brightness = 0 }):Play()
		end
	end)
	return can
end

--- The lamp nearest `position` stutters and dies. Returns false if there was none left.
function StageLight.lampDie(position: Vector3): boolean
	local nearest: Light? = nil
	local host: BasePart? = nil
	local best = math.huge
	for _, part in CollectionService:GetTagged("FlickerLamp") do
		if part:IsA("BasePart") then
			local light = part:FindFirstChildWhichIsA("Light")
			if light and light.Enabled and light.Brightness > 0.05 then
				local distance = (part.Position - position).Magnitude
				if distance < best then
					best, nearest, host = distance, light, part
				end
			end
		end
	end
	if not nearest or not host then
		return false
	end
	local light = nearest :: Light
	table.insert(extinguished, { light = light, brightness = light.Brightness })
	local myGeneration = generation
	AudioController.playAt("LampBuzz", host :: BasePart)
	-- Disabling it (not just dimming) is what keeps it dead: the ambient flicker loop
	-- skips disabled lights, so nothing resurrects a lamp the story just put out.
	if ClientState.reducedScares then
		TweenService:Create(light, TweenInfo.new(1.2), { Brightness = 0 }):Play()
		task.delay(1.2, function()
			if myGeneration == generation then
				light.Brightness = 0
				light.Enabled = false
			end
		end)
		return true
	end
	-- Two stutters, then out.
	local full = light.Brightness
	task.spawn(function()
		for _ = 1, 2 do
			if myGeneration ~= generation then
				return
			end
			light.Brightness = full * 0.15
			task.wait(0.09)
			if myGeneration ~= generation then
				return
			end
			light.Brightness = full
			task.wait(0.13)
		end
		if myGeneration == generation then
			TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
			task.delay(0.35, function()
				if myGeneration == generation then
					light.Brightness = 0
					light.Enabled = false
				end
			end)
		end
	end)
	return true
end

--- Every guide lamp in the room swells and settles: used under applause.
function StageLight.flood(seconds: number)
	for _, part in CollectionService:GetTagged("GuideLamp") do
		local light = part:FindFirstChildWhichIsA("Light")
		if light then
			local base = light.Brightness
			local myGeneration = generation
			TweenService:Create(light, TweenInfo.new(0.25), { Brightness = base * 2.2 }):Play()
			task.delay(seconds, function()
				if myGeneration == generation then
					TweenService:Create(light, TweenInfo.new(0.9), { Brightness = base }):Play()
				end
			end)
		end
	end
end

--- Ends every scare light and relights anything a scare killed.
function StageLight.clear()
	generation += 1
	for _, instance in temporary do
		instance:Destroy()
	end
	table.clear(temporary)
	for _, entry in extinguished do
		-- The lamp belongs to the map, but a map rebuild could have taken it away.
		pcall(function()
			entry.light.Brightness = entry.brightness
			entry.light.Enabled = true
		end)
	end
	table.clear(extinguished)
end

return StageLight
