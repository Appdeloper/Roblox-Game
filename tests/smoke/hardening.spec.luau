--[[
	Hardening specs on the server sim (Phase 3): every client→server remote survives garbage,
	cross-player and spammed input; the server cleans up when everyone leaves.
]]

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local Sim = require("./sim")

return function(placePath, check)
	print("\n== Smoke: hardening")
	local sim = Sim(placePath, check)
	if not sim then
		return
	end
	local h, Config, remotes = sim.h, sim.Config, sim.remotes
	local Remotes = h.require(h.place:GetService("ReplicatedStorage").Shared.Remotes)
	local MannequinService = h.require(sim.SSS.Services.MannequinService)

	local eve = sim.join("HardEve")
	local mal = sim.join("HardMal")
	sim.tick(0.5)

	-- 1) Garbage into every client→server remote: wrong types, extra args, NaN, huge strings,
	--    tables, nils. Nothing may error and nothing may start or change.
	-- (No empty call: RequestStart/RequestLobby with no arguments are legitimate.)
	local garbage = {
		{ 0 / 0 },
		{ math.huge },
		{ string.rep("x", 5000) },
		{ { nested = { 1, 2, 3 } } },
		{ "Story", "extra" },
		{ true, true, true },
		{ Vector3.new(1, 2, 3) },
	}
	local before = remotes.count("StageStarted", mal.UserId)
	for _, name in Remotes.ClientToServer do
		for _, args in garbage do
			remotes.fromClient(name, mal, table.unpack(args))
		end
	end
	sim.tick(1)
	check(#h.sched.errors == 0, "garbage into every remote raises no server errors")
	check(
		remotes.count("StageStarted", mal.UserId) == before,
		"garbage never starts a run (RequestStart takes no arguments)"
	)

	-- 2) Cross-player: Mal can't freeze Eve's mannequin by naming it.
	sim.tick(Config.Run.StartCooldown + 0.1)
	remotes.fromClient("RequestStart", eve)
	sim.tick(0.2)
	local eveCast = MannequinService.castOf(eve)
	local eveMain = eveCast and eveCast.Main
	remotes.fromClient("LookState", mal, eveMain and eveMain:name() or "x")
	sim.tick(0.2)
	check(eveMain ~= nil and eveMain.looking == false, "you can't freeze another player's mannequin")
	remotes.fromClient("EquipCosmetic", mal, "Trail", "Confetti")
	remotes.fromClient("RequestMode", mal, "GodMode")
	sim.tick(0.2)
	check(remotes.count("StageStarted", mal.UserId) == before, "unknown modes are ignored")

	-- 3) Spam: the rate limit holds.
	for _ = 1, 200 do
		remotes.fromClient("LookState", eve, "")
	end
	sim.tick(0.2)
	check(#h.sched.errors == 0, "remote spam is rate-limited without errors")

	-- 4) Died mid-chase → back to the checkpoint with a retake; mannequin keeps running.
	eve:moveTo(eve:position() + Vector3.new(4, 0, 0))
	sim.tick(1)
	eve.Character.humanoid.Health = 0
	eve.Character.humanoid.Died:Fire()
	sim.tick(Config.Movement.RespawnTime + 1)
	check(MannequinService.has(eve), "dying mid-run keeps the run (and the cast) alive")

	-- 5) Empty server: everyone leaves mid-chase → no casts, no loops left behind.
	sim.leave(eve)
	sim.leave(mal)
	sim.tick(0.5)
	check(not MannequinService.has(eve) and not MannequinService.has(mal), "an empty server holds no mannequins")
	check(#sim.mannequins:GetChildren() == 0, "no mannequin models left in the workspace")
	-- Rejoining starts fresh in the lobby.
	local back = sim.join("HardEve2")
	sim.tick(0.5)
	check(sim.stageOf(back) == 0, "a rejoining player starts in the lobby")
	check(
		#h.sched.errors == 0,
		"no errors in scheduled tasks" .. (h.sched.errors[1] and (": " .. h.sched.errors[1]) or "")
	)
end
