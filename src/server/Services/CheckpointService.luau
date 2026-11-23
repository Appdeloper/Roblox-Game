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
	-- The stage the player is in now (an index into the map's stages).
	stage: number,
	-- The run's stage list (Story: 1..6; Daily/Endless: chosen by shared/Modes) and the
	-- position in it. Endless extends `sequence` as it goes (`extend`).
	sequence: { number },
	step: number,
	extend: ((step: number) -> number?)?,
	-- Stages cleared so far this run (the Endless score).
	cleared: number,
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

--- Starts a run over `sequence` (default: every stage in order). `extend(step)` may supply
--- the stage for steps past the end (Endless).
function CheckpointService.begin(player: Player, sequence: { number }?, extend: ((step: number) -> number?)?): Progress
	local seq = sequence or {}
	if #seq == 0 then
		for i = 1, Config.Game.StageCount do
			seq[i] = i
		end
	end
	local p: Progress = {
		stage = seq[1],
		sequence = seq,
		step = 1,
		extend = extend,
		cleared = 0,
		retakes = 0,
		stageRetakes = 0,
		stageStartedAt = Clock.now(),
	}
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

--- Moves to the next stage in the run. Returns false when the run is on its last stage.
function CheckpointService.advance(player: Player): boolean
	local p = progress[player]
	if not p then
		return false
	end
	p.cleared += 1
	local nextStep = p.step + 1
	if not p.sequence[nextStep] and p.extend then
		p.sequence[nextStep] = (p.extend :: (number) -> number?)(nextStep) :: number
	end
	local nextStage = p.sequence[nextStep]
	if not nextStage then
		return false
	end
	p.step = nextStep
	p.stage = nextStage
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
