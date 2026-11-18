--!strict
--[[
	ClientState — what this client currently believes (always a mirror of server decisions).
	UI and effects read from here and listen to `Changed(key)` instead of to each other.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local ClientState = {}

ClientState.phase = "Lobby" :: Types.RunPhase
ClientState.stage = 0
ClientState.stageInfo = nil :: Types.StageStartInfo?
ClientState.runStartedAt = nil :: number?
ClientState.retakes = 0
ClientState.reducedScares = false
ClientState.profile = nil :: Types.ProfileSnapshot?

ClientState.Changed = Signal.new() :: Signal.Signal<string>

function ClientState.set(key: string, value: any)
	local state = ClientState :: any
	if state[key] == value then
		return
	end
	state[key] = value
	ClientState.Changed:Fire(key)
end

return ClientState
