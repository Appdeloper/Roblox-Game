--!strict
--[[
	Server entry point (ServerScriptService.Main). Boot order matters:
	  1. Remotes exist before any client can ask for them.
	  2. The map is built before players are placed in it.
	  3. Services init (wire dependencies), then start (connect players).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MapBuilder = require(ServerScriptService.MapBuilder)

Remotes.init()

local map = MapBuilder.build()
print(string.format("[Main] map built: %d stages", #map.stages))
