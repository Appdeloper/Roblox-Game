--[[
	Progression specs on the server sim: daily streak + rewards, ticket stubs, trophies (with
	their badges), cosmetic unlocks and equipping, and the Copycat's mannequin skin.
]]

local roblox = require("@lune/roblox")
local Color3 = roblox.Color3
local Sim = require("./sim")

return function(placePath, check)
	print("\n== Smoke: progression")
	local sim = Sim(placePath, check)
	if not sim then
		return
	end
	local h, Config, remotes = sim.h, sim.Config, sim.remotes
	local Modes = h.require(h.place:GetService("ReplicatedStorage").Shared.Modes)
	local ProgressionService = h.require(sim.SSS.Services.ProgressionService)
	local MannequinService = h.require(sim.SSS.Services.MannequinService)
	local store = h.stubs.DataStoreService:GetDataStore(Config.Data.StoreName)
	local function snapshot(player)
		local args = remotes.last("ProfileUpdated", player.UserId)
		return args and args[1]
	end
	local function has(list, value)
		return table.find(list or {}, value) ~= nil
	end

	-- 1) A fresh player: defaults equipped, a streak of 1.
	local ann = sim.join("ProgAnn")
	sim.tick(0.5)
	local snap = snapshot(ann)
	check(snap and snap.equipped.Trail == "None" and snap.equipped.MannequinSkin == "Pine", "defaults equipped")
	check(snap and snap.streak == 1, "first visit starts a streak of 1")
	check(
		snap and has(snap.unlocked.Playbill, "Classic") and not has(snap.unlocked.Trail, "Confetti"),
		"only free items unlocked"
	)

	-- 2) Equipping something locked does nothing.
	remotes.fromClient("EquipCosmetic", ann, "Trail", "Confetti")
	remotes.fromClient("EquipCosmetic", ann, "Bogus", "Thing")
	sim.tick(0.1)
	check(snapshot(ann).equipped.Trail == "None", "can't equip a locked cosmetic")

	-- 3) A full Story run: stubs for every act, trophies, a new trail unlocked.
	sim.tick(Config.Run.StartCooldown + 0.1)
	remotes.fromClient("RequestStart", ann)
	sim.tick(3)
	for _ = 1, Config.Game.StageCount do
		local info = remotes.last("StageStarted", ann.UserId)[1]
		sim.walk(ann, sim.routeWaypoints(info.stage, info.realExit), Config.Movement.WalkSpeed)
	end
	sim.tick(0.5)
	snap = snapshot(ann)
	local acts = 0
	for i = 1, Config.Game.StageCount do
		acts += if has(snap.stubs, "Act" .. i) then 1 else 0
	end
	check(acts == Config.Game.StageCount, string.format("a ticket stub for every act (%d)", acts))
	check(has(snap.trophies, "FirstEscape") and has(snap.trophies, "FullHouse"), "escape + finale trophies")
	check(has(snap.trophies, "MirrorMirror"), "running past the mirror earns Mirror, Mirror")
	check(has(snap.unlocked.Trail, "Confetti"), "the Full House trophy unlocks the Confetti trail")
	local note = remotes.last("Notify", ann.UserId)
	check(note and string.find(note[1], "Trophy") ~= nil, "trophies are announced")

	-- 4) Equip it.
	remotes.fromClient("EquipCosmetic", ann, "Trail", "Confetti")
	remotes.fromClient("EquipCosmetic", ann, "Playbill", "Classic")
	sim.tick(0.1)
	check(snapshot(ann).equipped.Trail == "Confetti", "equipping an unlocked cosmetic works")

	-- 5) Stare Down: a lunge in a stage you then clear.
	ProgressionService.onStageEntered(ann, 1, false)
	MannequinService.Stared:Fire(ann)
	ProgressionService.onStageCleared(ann, 1)
	check(has(snapshot(ann).trophies, "StareDown"), "a lunge then a clear earns Stare Down")
	check(has(snapshot(ann).unlocked.MannequinSkin, "Gilded"), "…which unlocks the Gilded mannequin")
	remotes.fromClient("EquipCosmetic", ann, "MannequinSkin", "Gilded")
	sim.tick(0.1)
	check(snapshot(ann).equipped.MannequinSkin == "Gilded", "mannequin skin equipped")
	sim.tick(Config.Run.StartCooldown + 0.1)
	remotes.fromClient("RequestStart", ann)
	sim.tick(0.2)
	local cast = MannequinService.castOf(ann)
	local torso = cast and cast.Main and cast.Main.rig.model:FindFirstChild("Torso")
	check(torso and torso.Color == Color3.fromRGB(214, 168, 72), "your Copycat wears your mannequin skin")

	-- 6) Coming back on the third day in a row: streak, reward, trophy.
	local probe = sim.join("ProgProbe")
	sim.leave(probe)
	local nextKey = Config.Data.KeyPrefix .. tostring(probe.UserId + 1)
	local today = Modes.dayNumber(os.time())
	store.data[nextKey] = {
		Version = Config.Data.SchemaVersion,
		TotalEscapes = 0,
		TotalRetakes = 0,
		Titles = {},
		OwnedSkins = {},
		EquippedSkin = "Classic",
		Settings = {},
		Trophies = {},
		Stubs = {},
		Equipped = {},
		LastDay = today - 1,
		Streak = 2,
		BestStreak = 2,
		ProcessedReceipts = {},
	}
	local bea = sim.join("ProgBea")
	sim.tick(0.5)
	snap = snapshot(bea)
	check(snap and snap.streak == 3 and snap.bestStreak == 3, "the next day continues the streak")
	check(snap and has(snap.trophies, "DailyDevotee"), "three days in a row earns Daily Devotee")
	check(snap and has(snap.unlocked.Playbill, "Midnight"), "the day-3 reward (Midnight playbill) unlocks")

	check(
		#h.sched.errors == 0,
		"no errors in scheduled tasks" .. (h.sched.errors[1] and (": " .. h.sched.errors[1]) or "")
	)
end
