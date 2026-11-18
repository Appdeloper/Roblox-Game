--!strict
--[[
	Client entry point. The client only renders, animates and sends requests;
	the server decides everything that matters.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local _Remotes = require(Shared:WaitForChild("Remotes"))
