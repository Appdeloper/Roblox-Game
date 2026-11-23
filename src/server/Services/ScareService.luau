--!strict
--[[
	ScareService — server half of the scripted scares. When a player first reaches a stage's
	scare zone (RoundService.ScareZoneEntered, once per run), it freezes their mannequin and
	pauses catching for the scare's duration, schedules the stage-1 bow pose, and tells the
	client to play the visuals. Clients may report "skipped" for analytics only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local MannequinService = require(script.Parent.MannequinService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RoundService = require(script.Parent.RoundService)

local ScareService = {}

local function play(player: Player, stage: number)
	if stage == 1 then
		local cfg = Config.Scares.Stage1
		MannequinService.holdForScare(player, cfg.CatchPause)
		MannequinService.bow(player, cfg.MannequinBowDelay, cfg.MannequinBowSeconds)
	elseif stage == 2 then
		MannequinService.holdForScare(player, Config.Scares.Stage2.CatchPause)
	else
		local cfg = (Config.Scares :: any)["Stage" .. stage]
		if not cfg then
			return
		end
		MannequinService.holdForScare(player, cfg.CatchPause)
	end
	Remotes.get("Scare"):FireClient(player, stage)
end

function ScareService.init()
	RoundService.ScareZoneEntered:Connect(play)
	RemoteGuard.connect("ScareSkipped", RemoteGuard.args("number"), function(player, stage: number)
		if stage == math.floor(stage) and stage >= 1 and stage <= Config.Game.StageCount then
			Analytics.track("scare_skipped", player, { stage = stage })
		end
	end)
end

return ScareService
