--!strict
--[[
	MapBuilder — builds the ENTIRE place from code on server boot: lobby, three stages and
	lighting. Nothing depends on a hand-made .rbxl; delete Workspace.Map and it is rebuilt.

	Each layout is validated first (jump fairness, kill line, door placement). Problems are
	reported as warnings so a tuning mistake never stops the server, and the same validator
	fails CI offline (tests/layout.spec.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local Types = require(ReplicatedStorage.Shared.Types)
local Builders = require(script.Builders)
local Dressing = require(script.Dressing)
local LayoutValidator = require(script.LayoutValidator)
local LightingSetup = require(script.LightingSetup)
local Lobby = require(script.Lobby)
local StageBuilder = require(script.StageBuilder)

local LAYOUTS = {
	require(script.Layouts.Stage1),
	require(script.Layouts.Stage2),
	require(script.Layouts.Stage3),
}

local MapBuilder = {}

export type BuiltMap = Types.MapInfo & {
	startPrompt: ProximityPrompt,
	leaderboardGui: SurfaceGui,
}

local function validate(index: number, layout: any)
	local errors = LayoutValidator.validate(layout, {
		physics = Config.Movement,
		gapRatio = Config.Map.MaxGapRatio,
		riseRatio = Config.Map.MaxRiseRatio,
		killMargin = Config.Map.KillMargin,
		rootHeight = Config.Mannequin.RootHeight,
		jumpMath = JumpMath,
	})
	for _, message in errors do
		warn(string.format("[MapBuilder] stage %d layout: %s", index, message))
	end
end

--- Studio templates ship their own SpawnLocation; it would steal spawns from the lobby.
--- Disable (never delete) any spawn that isn't part of the generated map.
local function disableStraySpawns(root: Instance)
	for _, d in Workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and not d:IsDescendantOf(root) and d.Enabled then
			d.Enabled = false
			warn("[MapBuilder] disabled stray SpawnLocation " .. d:GetFullName() .. " (players start in the lobby)")
		end
	end
end

function MapBuilder.build(): BuiltMap
	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	LightingSetup.apply()
	local root = Builders.folder("Map", Workspace)

	local lobby = Lobby.build(root, Builders.v(Config.Map.LobbyOrigin))
	local stages: { Types.StageInfo } = {}
	assert(#LAYOUTS == Config.Game.StageCount, "layout count must match Config.Game.StageCount")
	for index, layout in LAYOUTS do
		validate(index, layout)
		local origin = Builders.v(Config.Map.StageOrigins[index])
		stages[index] = StageBuilder.build(index, layout, origin, root, Dressing.byStage[index])
	end

	disableStraySpawns(root)
	return {
		lobbySpawn = lobby.spawn,
		stages = stages,
		startPrompt = lobby.startPrompt,
		leaderboardGui = lobby.leaderboardGui,
	}
end

return MapBuilder
