--!strict
--[[
	AmbienceController — the client half of the soundscape.

	The server places the 3D ambience emitters; this routes them all through one SoundGroup
	carrying a ReverbSoundEffect, and retunes that reverb for whichever room the local
	player is in. The big empty auditorium rings; the painted street outdoors is short and
	dry; backstage is boxy timber. Changes are cross-faded over Config.Ambience.ReverbBlend
	so you never hear the room switch with a click.

	Everything here is local: the reverb one player hears has no effect on anyone else.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ClientState = require(script.Parent.Parent.ClientState)

local AmbienceController = {}

local group: SoundGroup
local reverb: ReverbSoundEffect
local active: Tween? = nil

local function route(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local sound = part:FindFirstChildWhichIsA("Sound")
	if sound then
		sound.SoundGroup = group
	end
end

--- Picks the reverb for a stage index; 0 (or anything unknown) means the lobby.
local function presetFor(stage: number)
	local presets = Config.Ambience.Reverb
	return presets.Stages[stage] or presets.Lobby
end

local function applyPreset(stage: number, instant: boolean)
	local preset = presetFor(stage)
	if active then
		active:Cancel()
		active = nil
	end
	local goal = {
		DecayTime = preset.DecayTime,
		Density = preset.Density,
		Diffusion = preset.Diffusion,
		WetLevel = preset.WetLevel,
		DryLevel = preset.DryLevel,
	}
	if instant then
		for key, value in goal do
			(reverb :: any)[key] = value
		end
		return
	end
	local tween = TweenService:Create(reverb, TweenInfo.new(Config.Ambience.ReverbBlend), goal)
	active = tween
	tween:Play()
end

function AmbienceController.init()
	group = Instance.new("SoundGroup")
	group.Name = "DLB_Ambience"
	group.Volume = 1
	group.Parent = SoundService

	reverb = Instance.new("ReverbSoundEffect")
	reverb.Name = "RoomReverb"
	reverb.Parent = group

	for _, part in CollectionService:GetTagged("AmbienceEmitter") do
		route(part)
	end
	-- Emitters that replicate after start-up join the same group.
	CollectionService:GetInstanceAddedSignal("AmbienceEmitter"):Connect(route)

	applyPreset(0, true)
	ClientState.Changed:Connect(function(key)
		if key == "stage" or key == "phase" then
			-- In the lobby (or between runs) the room is small again.
			local stage = if ClientState.phase == "Running" then ClientState.stage else 0
			applyPreset(stage, false)
		end
	end)
end

return AmbienceController
