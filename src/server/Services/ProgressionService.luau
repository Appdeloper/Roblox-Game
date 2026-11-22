--!strict
--[[
	ProgressionService — trophies, ticket stubs and the unlocks they bring.

	Listens to what happens in a run and records it on the profile (DataService). Every
	trophy also awards its BadgeService badge (Badges, server-side; placeholder IDs are logged).

	  Stubs     Act I..VI the first time you clear each stage; Daily / Endless / Co-op the first
	            time you finish a run in that mode
	  Trophies  see Config.Trophies (escape, zero retakes, door, stare down, mirror, finale,
	            daily, streak, endless 10, co-op finish, revive)
	When a trophy or streak unlocks a cosmetic, the player is told what's new in the wardrobe.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Badges = require(script.Parent.Badges)
local DataService = require(script.Parent.DataService)

local ProgressionService = {}

-- Players who made a mannequin lunge in the stage they're in now (for Stare Down).
local lungedThisStage: { [Player]: boolean } = {}

local function unlockNames(kind: string, key: string): { string }
	local names = {}
	for _, items in Config.Cosmetics :: any do
		for _, item in items do
			if item.Unlock.Kind == kind and item.Unlock.Key == key then
				table.insert(names, item.DisplayName)
			end
		end
	end
	table.sort(names)
	return names
end

--- Grants a trophy (and its badge). Announces it, and any cosmetic it unlocks.
function ProgressionService.trophy(player: Player, key: string)
	if not DataService.grantTrophy(player, key) then
		return
	end
	Badges.award(player, key)
	local trophy = (Config.Trophies :: any)[key]
	local message = "🏆 Trophy: " .. trophy.DisplayName .. "!"
	local unlocks = unlockNames("Trophy", key)
	if #unlocks > 0 then
		message ..= "  New in your wardrobe: " .. table.concat(unlocks, ", ") .. "."
	end
	Remotes.get("Notify"):FireClient(player, message)
	Analytics.track("trophy", player, { trophy = key })
end

function ProgressionService.stub(player: Player, key: string)
	if DataService.grantStub(player, key) then
		Analytics.track("stub", player, { stub = key })
	end
end

function ProgressionService.onStageEntered(player: Player, _stage: number, isRetake: boolean)
	if not isRetake then
		lungedThisStage[player] = nil
	end
end

function ProgressionService.onStageCleared(player: Player, stage: number)
	ProgressionService.stub(player, "Act" .. stage)
	if stage == Config.Game.StageCount then
		ProgressionService.trophy(player, "FullHouse")
	end
	if lungedThisStage[player] then
		ProgressionService.trophy(player, "StareDown")
	end
	lungedThisStage[player] = nil
end

function ProgressionService.onRunFinished(player: Player, result: any)
	local mode = result.mode or "Story"
	if mode == "Endless" then
		ProgressionService.stub(player, "Endless")
		if (result.cleared or 0) >= 10 then
			ProgressionService.trophy(player, "EndlessTen")
		end
		return
	end
	if not result.verified then
		return
	end
	ProgressionService.trophy(player, "FirstEscape")
	if result.retakes == 0 then
		ProgressionService.trophy(player, "OpeningNight")
	end
	if mode == "Daily" then
		ProgressionService.stub(player, "Daily")
		ProgressionService.trophy(player, "DailyDouble")
	elseif mode == "Coop" then
		ProgressionService.stub(player, "Coop")
		if (result.partySize or 1) >= 2 then
			ProgressionService.trophy(player, "CastParty")
		end
	end
end

function ProgressionService.init(signals: {
	stageEntered: any,
	stageCleared: any,
	runFinished: any,
	stared: any,
	mirrorCracked: any,
	doorOutran: any,
	revived: any,
})
	signals.stageEntered:Connect(ProgressionService.onStageEntered)
	signals.stageCleared:Connect(ProgressionService.onStageCleared)
	signals.runFinished:Connect(ProgressionService.onRunFinished)
	signals.stared:Connect(function(player: Player)
		lungedThisStage[player] = true
	end)
	signals.mirrorCracked:Connect(function(player: Player)
		ProgressionService.trophy(player, "MirrorMirror")
	end)
	signals.doorOutran:Connect(function(player: Player)
		ProgressionService.trophy(player, "SpottedTheDoor")
	end)
	signals.revived:Connect(function(_player: Player, by: Player)
		ProgressionService.trophy(by, "RevivalAct")
	end)
	DataService.DailyVisit:Connect(function(player: Player, streak: number)
		if streak >= 3 then
			ProgressionService.trophy(player, "DailyDevotee")
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lungedThisStage[player] = nil
	end)
end

return ProgressionService
