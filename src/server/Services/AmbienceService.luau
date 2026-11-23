--!strict
--[[
	AmbienceService — the layered 3D soundscape of the building.

	Each layer is a looping Sound on an anchored, invisible emitter placed somewhere the
	sound would really come from: drips in the pit, wind in the rafters, timber settling in
	the wings, a faint piano through a wall, applause from a house that is not there.

	Because they are 3D sounds in the world, they pan and fade on their own as the player
	moves — no per-frame code anywhere. Rolloff numbers live in Config.Ambience.Layers, and
	with stages 260 studs apart nothing bleeds between rooms.

	Every ID is a placeholder in Assets.luau. While one is 0 the emitter is still built and
	still visible in the Explorer (so you can see where the sound will come from), it simply
	has nothing to play. Clients add the reverb — see client/Audio/AmbienceController.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local AmbienceService = {}

type Placement = { layer: string, offset: { number } }

-- Where each layer sits, in stage-local coordinates.
local STAGE_PLACEMENTS: { { Placement } } = {
	{
		{ layer = "Drip", offset = { 40, 2, -18 } },
		{ layer = "Drip", offset = { 76, 2, 20 } },
		{ layer = "Wind", offset = { 130, 42, 0 } },
		{ layer = "Wood", offset = { 152, 26, -20 } },
		{ layer = "Piano", offset = { 157, 20, 18 } },
		{ layer = "Applause", offset = { 10, 8, 0 } },
	},
	{
		{ layer = "Wind", offset = { 90, 50, -18 } },
		{ layer = "Drip", offset = { 140, 2, 8 } },
		{ layer = "Wood", offset = { 60, 54, -20 } },
		{ layer = "Piano", offset = { 28, 33, 10 } },
		{ layer = "Applause", offset = { 174, 10, 0 } },
	},
	{
		{ layer = "Wind", offset = { 110, 50, 0 } },
		{ layer = "Wood", offset = { 56, 26, -14 } },
		{ layer = "Drip", offset = { 40, -4, 14 } },
		{ layer = "Piano", offset = { 120, 10, -22 } },
		{ layer = "Applause", offset = { 60, -3, 20 } },
	},
	{
		{ layer = "Wind", offset = { 70, 62, 0 } },
		{ layer = "Wood", offset = { 40, 50, 18 } },
		{ layer = "Piano", offset = { 67, -2, 0 } },
		{ layer = "Drip", offset = { 110, 30, -18 } },
	},
	{
		{ layer = "Wood", offset = { 60, 20, 20 } },
		{ layer = "Drip", offset = { 100, 4, -20 } },
		{ layer = "Piano", offset = { 20, 14, 18 } },
		{ layer = "Wind", offset = { 120, 30, 0 } },
	},
	{
		{ layer = "Applause", offset = { 80, 6, 26 } },
		{ layer = "Applause", offset = { 80, 6, -26 } },
		{ layer = "Piano", offset = { 40, 12, -20 } },
		{ layer = "Wood", offset = { 110, 40, 0 } },
	},
}

local LOBBY_PLACEMENTS: { Placement } = {
	{ layer = "Wind", offset = { 0, 24, -20 } },
	{ layer = "Wood", offset = { -24, 12, 16 } },
	{ layer = "Piano", offset = { 24, 8, -18 } },
}

local function emitter(parent: Instance, placement: Placement, origin: Vector3, stage: number)
	local layer = (Config.Ambience.Layers :: any)[placement.layer]
	assert(layer, "Unknown ambience layer: " .. placement.layer)
	local asset = (Assets.Sounds :: any)[layer.asset]
	assert(asset, "Unknown ambience sound: " .. layer.asset)

	local host = Instance.new("Part")
	host.Name = "Ambience_" .. placement.layer
	host.Anchored = true
	host.CanCollide = false
	host.CanTouch = false
	host.CanQuery = false
	host.CastShadow = false
	host.Transparency = 1
	host.Size = Vector3.one
	host.CFrame = CFrame.new(origin + Vector3.new(placement.offset[1], placement.offset[2], placement.offset[3]))
	host:SetAttribute("Stage", stage)
	host:AddTag("AmbienceEmitter")
	host.Parent = parent

	local sound = Instance.new("Sound")
	sound.Name = placement.layer
	sound.SoundId = Assets.uri(asset.Id)
	sound.Volume = asset.Volume
	sound.Looped = true
	-- Tapered inverse falls off like a real room: close to full inside min, gone by max.
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = layer.min
	sound.RollOffMaxDistance = layer.max
	sound.Parent = host
	if asset.Id ~= 0 then
		sound.Playing = true
	end
	return host
end

--- Builds every emitter. Call after the map exists; `map` supplies the stage origins.
function AmbienceService.init(_map: Types.MapInfo)
	local existing = Workspace:FindFirstChild("Ambience")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Ambience"
	folder.Parent = Workspace

	local lobbyOrigin = Vector3.new(Config.Map.LobbyOrigin[1], Config.Map.LobbyOrigin[2], Config.Map.LobbyOrigin[3])
	for _, placement in LOBBY_PLACEMENTS do
		emitter(folder, placement, lobbyOrigin, 0)
	end
	for stage, placements in STAGE_PLACEMENTS do
		local origin = Vector3.new(
			Config.Map.StageOrigins[stage][1],
			Config.Map.StageOrigins[stage][2],
			Config.Map.StageOrigins[stage][3]
		)
		for _, placement in placements do
			emitter(folder, placement, origin, stage)
		end
	end
end

return AmbienceService
