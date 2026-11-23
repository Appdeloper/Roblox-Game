--!strict
--[[
	AudioController — every sound goes through here so placeholder IDs (0) are skipped
	gracefully and volumes stay consistent. Captions carry the meaning of every important
	sound, so a muted phone (very common!) never misses a cue.

	Loops: ambience (always), heartbeat (proximity to your mannequin), mannequin creak.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)

local AudioController = {}

local group: SoundGroup
local loops: { [string]: Sound } = {}

local function makeSound(key: string, parent: Instance): Sound?
	local asset = (Assets.Sounds :: any)[key]
	if not asset then
		warn("[Audio] unknown sound " .. key)
		return nil
	end
	local uri = Assets.uri(asset.Id)
	if uri == "" then
		return nil -- placeholder: stay silent
	end
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = uri
	sound.Volume = asset.Volume * Config.Audio.SfxVolume
	sound.Looped = asset.Looped
	sound.SoundGroup = group
	sound.Parent = parent
	return sound
end

--- Plays a sound and cleans it up when it ends. A sound that can't play (an asset that was
--- moderated, or the offline test client) is simply dropped: audio is never load-bearing.
local function playOnce(sound: Sound)
	local ok = pcall(function()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		sound:Play()
	end)
	if not ok then
		sound:Destroy()
	end
end

function AudioController.init()
	group = Instance.new("SoundGroup")
	group.Name = "DLB_Sfx"
	group.Parent = SoundService
	AudioController.startLoop("Ambience", SoundService)
end

--- Fire-and-forget 2D sound.
function AudioController.play(key: string)
	local sound = makeSound(key, SoundService)
	if sound then
		sound.PlayOnRemove = false
		playOnce(sound)
	end
end

--- Fire-and-forget 3D sound at a part (rolls off with distance).
function AudioController.playAt(key: string, part: BasePart)
	local sound = makeSound(key, part)
	if sound then
		sound.RollOffMaxDistance = 120
		sound.RollOffMinDistance = 8
		playOnce(sound)
	end
end

--- Starts (or returns) a named looping sound under `parent`. Returns nil for placeholders.
function AudioController.startLoop(key: string, parent: Instance): Sound?
	local existing = loops[key]
	if existing and existing.Parent then
		return existing
	end
	local sound = makeSound(key, parent)
	if sound then
		sound.Looped = true
		pcall(function()
			sound:Play()
		end)
		loops[key] = sound
	end
	return sound
end

function AudioController.getLoop(key: string): Sound?
	local sound = loops[key]
	return if sound and sound.Parent then sound else nil
end

function AudioController.stopLoop(key: string)
	local sound = loops[key]
	if sound then
		sound:Destroy()
		loops[key] = nil
	end
end

return AudioController
