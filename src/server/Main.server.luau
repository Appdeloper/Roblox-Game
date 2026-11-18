--!strict
--[[
	Server entry point. Boot order matters:
	  1. Remotes exist before any client can ask for them.
	  2. The map is built before players are placed in it.
	  3. Services init (wire dependencies), then start (connect players).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

Remotes.init()
