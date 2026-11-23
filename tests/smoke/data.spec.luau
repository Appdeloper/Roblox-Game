--[[
	DataService specs on the server sim with an in-memory DataStore (fault injectable).
]]

local Sim = require("./sim")

return function(placePath, check)
	print("\n== Smoke: DataService")
	local sim = Sim(placePath, check)
	if not sim then
		return
	end
	local h, Config, remotes = sim.h, sim.Config, sim.remotes
	local DataService = h.require(sim.SSS.Services.DataService)
	local store = h.stubs.DataStoreService:GetDataStore(Config.Data.StoreName)
	local function keyOf(player)
		return Config.Data.KeyPrefix .. tostring(player.UserId)
	end
	local function snapshot(player)
		local args = remotes.last("ProfileUpdated", player.UserId)
		return args and args[1]
	end

	-- 1) Fresh profile → run recorded → saved.
	local ana = sim.join("DataAna")
	sim.tick(0.5)
	check(snapshot(ana) and snapshot(ana).savingEnabled, "fresh player loads with saving enabled")
	DataService.recordRun(ana, 80, 0, true)
	sim.tick(0.5)
	local saved = store.data[keyOf(ana)]
	check(saved and saved.BestTime == 80, "best time saved with UpdateAsync")
	check(saved and saved.Titles.OpeningNight and saved.Titles.FirstEscape, "titles saved")
	check(saved and saved.Version == Config.Data.SchemaVersion, "profile is versioned")

	-- 2) Another server writes newer data; our save merges instead of overwriting.
	store.data[keyOf(ana)].BestTime = 70
	store.data[keyOf(ana)].Titles.DoorSpotter = true
	store.data[keyOf(ana)].TotalEscapes = 10
	DataService.recordRun(ana, 75, 2, true)
	sim.tick(0.5)
	saved = store.data[keyOf(ana)]
	check(saved.BestTime == 70, "merge keeps the lower best time from another server")
	check(saved.Titles.DoorSpotter and saved.Titles.OpeningNight, "merge unions titles")
	check(saved.TotalEscapes == 11, "merge adds only this session's new escapes")

	-- 3) Leave and rejoin (same UserId): data comes back.
	local anaId = ana.UserId
	sim.leave(ana)
	sim.tick(0.5)
	local rejoin = require("./fakes").player(h.signal, "DataAnaRejoin")
	rejoin.UserId = anaId
	table.insert(h.stubs.Players._list, rejoin)
	h.stubs.Players.PlayerAdded:Fire(rejoin)
	sim.tick(0.5)
	check(DataService.get(rejoin) and DataService.get(rejoin).data.BestTime == 70, "rejoining loads the saved profile")
	sim.leave(rejoin)
	sim.tick(0.5)

	-- 4) Transient outage: retries then succeeds.
	store.failGets = 2
	local ben = sim.join("DataBen")
	sim.tick(Config.Data.RetryBaseDelay * 4)
	check(snapshot(ben) and snapshot(ben).savingEnabled, "load retries with backoff and succeeds")
	sim.leave(ben)
	sim.tick(0.5)

	-- 5) Failed load never overwrites a good profile.
	local probe1 = sim.join("Probe1")
	sim.leave(probe1)
	local good = { Version = 2, BestTime = 42, TotalEscapes = 5, Titles = { OpeningNight = true } }
	local catKey = Config.Data.KeyPrefix .. tostring(probe1.UserId + 1)
	store.data[catKey] = good
	store.failGets = 99
	local updatesBefore = store.updates
	local catReal = sim.join("DataCat")
	sim.tick(Config.Data.RetryBaseDelay * 16)
	store.failGets = 0
	check(keyOf(catReal) == catKey, "probe predicted the user id")
	check(snapshot(catReal) and snapshot(catReal).savingEnabled == false, "failed load disables saving")
	check(remotes.count("Notify", catReal.UserId) >= 1, "player is told saving is paused")
	DataService.recordRun(catReal, 10, 0, true)
	sim.leave(catReal)
	sim.tick(1)
	check(store.data[catKey].BestTime == 42 and store.updates == updatesBefore, "failed-load session never writes")

	-- 6) v1 data migrates.
	local probe = sim.join("Probe2")
	sim.leave(probe)
	local v1Key = Config.Data.KeyPrefix .. tostring(probe.UserId + 1)
	store.data[v1Key] = { Version = 1, BestTime = 70, Titles = { OpeningNight = true } }
	local dee = sim.join("DataDee")
	sim.tick(0.5)
	local snap = snapshot(dee)
	check(snap and snap.bestTime == 70, "v1 profile migrates (best time kept)")
	check(snap and table.find(snap.ownedSkins, "OpeningNight") ~= nil, "title unlocks its ticket skin")

	-- 7) Remote validation for settings and skins.
	remotes.fromClient("EquipSkin", dee, "Golden")
	remotes.fromClient("EquipSkin", dee, "NotASkin")
	sim.tick(0.1)
	check(snapshot(dee).equippedSkin == "Classic", "can't equip a skin you don't own")
	remotes.fromClient("EquipSkin", dee, "OpeningNight")
	remotes.fromClient("SetSetting", dee, "Bogus", true)
	remotes.fromClient("SetSetting", dee, "ReducedScares", true)
	sim.tick(0.1)
	check(snapshot(dee).equippedSkin == "OpeningNight", "equipping an owned skin works")
	check(snapshot(dee).reducedScares == true, "Reduced Scares setting stored")

	-- 8) BindToClose flushes everyone.
	local closed = false
	h.sched.task.spawn(function()
		for _, fn in h.closeHandlers do
			fn()
		end
		closed = true
	end)
	sim.tick(2)
	check(closed, "BindToClose finishes within the timeout")
	check(
		store.data[keyOf(dee)] and store.data[keyOf(dee)].Version == Config.Data.SchemaVersion,
		"shutdown saved the migrated profile at the current version"
	)
	check(store.data[keyOf(dee)].Settings.ReducedScares == true, "settings persisted")

	-- 9) Newer schema on disk is treated as a failed load (never downgraded).
	local probe3 = sim.join("Probe3")
	sim.leave(probe3)
	local futureKey = Config.Data.KeyPrefix .. tostring(probe3.UserId + 1)
	store.data[futureKey] = { Version = 99, BestTime = 1 }
	local eve = sim.join("DataEve")
	sim.tick(0.5)
	check(snapshot(eve) and snapshot(eve).savingEnabled == false, "newer-schema profile locks saving")
	sim.leave(eve)
	sim.tick(0.5)
	check(store.data[futureKey].Version == 99, "newer-schema profile untouched")
	check(
		#h.sched.errors == 0,
		"no errors in scheduled tasks" .. (if #h.sched.errors > 0 then ": " .. h.sched.errors[1] else "")
	)
end
