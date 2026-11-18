--!strict
--[[
	Server entry point (ServerScriptService.Main). Boot order matters:
	  1. Remotes exist before any client can ask for them.
	  2. The map is built before players are placed in it.
	  3. Services init in dependency order; RoundService last because it connects players.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Assets = require(ReplicatedStorage.Shared.Assets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MapBuilder = require(ServerScriptService.MapBuilder)
local Services = ServerScriptService.Services
local CheckpointService = require(Services.CheckpointService)
local MannequinService = require(Services.MannequinService)
local RemoteGuard = require(Services.RemoteGuard)
local RoundService = require(Services.RoundService)
local ScareService = require(Services.ScareService)

Remotes.init()
local map = MapBuilder.build()

RemoteGuard.init()
MannequinService.init()
CheckpointService.init(map)
RoundService.init(map)
ScareService.init()

if RunService:IsStudio() then
	local missing = Assets.listPlaceholders()
	if #missing > 0 then
		print(string.format("[Main] %d asset placeholders still to replace (see Assets.luau)", #missing))
	end
end
print(string.format("[Main] Don't Look Backstage ready: %d stages", #map.stages))
