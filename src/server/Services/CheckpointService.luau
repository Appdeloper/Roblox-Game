--!strict
--[[
	CheckpointService — stage entrances are the checkpoints.

	Tracks, per player in a run: the current stage, total retakes, and when the current stage
	(and attempt) began. Owns teleporting characters to checkpoints so the "how" of moving a
	character (pivot + kill velocity) lives in one place.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local CheckpointService = {}

export type Progress = {
	stage: number,
	retakes: number,
	-- Retakes taken in the current stage only (analytics).
	stageRetakes: number,
	-- Clock.now() when the current stage was first entered.
	stageStartedAt: number,
}

local progress: { [Player]: Progress } = {}
local stages: { Types.StageInfo } = {}

function CheckpointService.init(map: Types.MapInfo)
	stages = map.stages
	Players.PlayerRemoving:Connect(function(player)
		progress[player] = nil
	end)
end

function CheckpointService.begin(player: Player): Progress
	local p: Progress = { stage = 1, retakes = 0, stageRetakes = 0, stageStartedAt = Clock.now() }
	progress[player] = p
	return p
end

function CheckpointService.get(player: Player): Progress?
	return progress[player]
end

function CheckpointService.clear(player: Player)
	progress[player] = nil
end

function CheckpointService.stageInfo(player: Player): Types.StageInfo?
	local p = progress[player]
	return if p then stages[p.stage] else nil
end

--- Moves to the next stage. Returns false when the run is already on the last stage.
function CheckpointService.advance(player: Player): boolean
	local p = progress[player]
	if not p or p.stage >= Config.Game.StageCount then
		return false
	end
	p.stage += 1
	p.stageRetakes = 0
	p.stageStartedAt = Clock.now()
	return true
end

function CheckpointService.addRetake(player: Player): number
	local p = progress[player]
	if not p then
		return 0
	end
	p.retakes += 1
	p.stageRetakes += 1
	return p.retakes
end

--- Pivots a character to `cframe` and zeroes its momentum. Safe if the character is missing.
function CheckpointService.teleport(player: Player, cframe: CFrame): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return false
	end
	character:PivotTo(cframe)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

function CheckpointService.teleportToEntrance(player: Player): boolean
	local stage = CheckpointService.stageInfo(player)
	return stage ~= nil and CheckpointService.teleport(player, stage.entrance)
end

return CheckpointService
