--[[
	Game mode specs on the server sim: Daily Run (seeded list, first finish counts), Endless
	(lives, faster mannequin, score = stages cleared) and Co-op (downed, revive, shared clears,
	party retake when everyone is down).
]]

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local Sim = require("./sim")

return function(placePath, check)
	print("\n== Smoke: game modes")
	local sim = Sim(placePath, check)
	if not sim then
		return
	end
	local h, Config, remotes = sim.h, sim.Config, sim.remotes
	local tick, join, stageOf, walk, routeWaypoints = sim.tick, sim.join, sim.stageOf, sim.walk, sim.routeWaypoints
	local Modes = h.require(h.place:GetService("ReplicatedStorage").Shared.Modes)
	local MannequinService = h.require(sim.SSS.Services.MannequinService)
	local LeaderboardService = h.require(sim.SSS.Services.LeaderboardService)
	local Stores = h.stubs.DataStoreService

	local function info(player)
		local last = remotes.last("StageStarted", player.UserId)
		return last and last[1]
	end
	local function walkStage(player)
		local i = info(player)
		walk(player, routeWaypoints(i.stage, i.realExit), Config.Movement.WalkSpeed)
	end

	-- ── Daily ──────────────────────────────────────────────────────────────────────────────
	do
		local dee = join("Dee")
		tick(Config.Run.StartCooldown + 0.1)
		remotes.fromClient("RequestMode", dee, "Daily")
		tick(0.1)
		local first = info(dee)
		local day = Modes.dayNumber(os.time())
		local expected = Modes.dailySequence(day, Config.Game.StageCount, Config.Modes.Daily.Length)
		check(first and first.mode == "Daily", "daily: the run is a Daily Run")
		check(first and first.stage == expected[1], "daily: starts on the day's first stage")
		check(first and first.steps == Config.Modes.Daily.Length, "daily: the HUD knows how long the run is")
		for _ = 1, Config.Modes.Daily.Length do
			walkStage(dee)
		end
		local finished = remotes.last("RunFinished", dee.UserId)
		check(finished and finished[1].mode == "Daily", "daily: finishing gives a Daily ticket")
		tick(1)
		local store = Stores:GetOrderedDataStore(LeaderboardService.dailyStoreName(day))
		local firstValue = store.data[tostring(dee.UserId)]
		check(firstValue ~= nil, "daily: the first finish goes on today's board")
		-- A second (slower) run the same day is only a rehearsal.
		tick(Config.Run.StartCooldown + 0.1)
		remotes.fromClient("RequestMode", dee, "Daily")
		tick(3)
		for _ = 1, Config.Modes.Daily.Length do
			walkStage(dee)
		end
		tick(1)
		check(store.data[tostring(dee.UserId)] == firstValue, "daily: only the first finish of the day counts")
		local last = remotes.last("Notify", dee.UserId)
		check(last and string.find(last[1], "rehearsal") ~= nil, "daily: a repeat run is called a rehearsal")
	end

	-- ── Endless ────────────────────────────────────────────────────────────────────────────
	do
		local eve = join("Eve")
		-- A fixed shuffle that doesn't open on the light rigs (the sim walker waits for beams,
		-- and waiting in Endless costs lives), so the test never depends on the clock.
		local RoundService = h.require(sim.SSS.Services.RoundService)
		local seed = 1
		while true do
			local seq = Modes.endlessSequence(seed, Config.Game.StageCount, 4)
			if not table.find(seq, 4) then
				break
			end
			seed += 1
		end
		RoundService.endlessSeed = function()
			return seed
		end
		tick(Config.Run.StartCooldown + 0.1)
		remotes.fromClient("RequestMode", eve, "Endless")
		tick(0.1)
		local start = info(eve)
		check(
			start and start.mode == "Endless" and start.lives == Config.Modes.Endless.Lives,
			"endless: starts with lives"
		)
		check(start and start.steps == nil, "endless: the run has no end")
		local stagesSeen = {}
		for _ = 1, 3 do
			stagesSeen[info(eve).stage] = true
			walkStage(eve)
		end
		local now = info(eve)
		check(now.step == 4, "endless: three stages cleared, on the fourth")
		local cast = MannequinService.castOf(eve)
		local delay = cast and cast.Main and cast.Main.delay
		check(
			delay ~= nil and delay < Config.Modes.Endless.BaseDelay,
			string.format("endless: the mannequin gets faster (%.2fs)", delay or -1)
		)
		-- Stand still until the lives run out.
		local deadline = 0
		while not remotes.last("RunFinished", eve.UserId) and deadline < 60 do
			-- Step off the entrance (so the mannequin starts), then freeze.
			eve:moveTo(eve:position() + Vector3.new(5, 0, 0))
			tick(6)
			deadline += 6
		end
		local finished = remotes.last("RunFinished", eve.UserId)
		check(finished ~= nil, "endless: running out of lives ends the run")
		check(
			finished and finished[1].mode == "Endless" and finished[1].stagesCleared == 3,
			"endless: the score is stages cleared"
		)
		check(finished and finished[1].titleEarned == nil, "endless: no Opening Night title for losing all lives")
		tick(1)
		local board = Stores:GetOrderedDataStore(Config.Modes.Endless.StoreName)
		check(board.data[tostring(eve.UserId)] == 3, "endless: the global board keeps stages cleared")
	end

	-- ── Co-op ──────────────────────────────────────────────────────────────────────────────
	do
		local cat = join("Cat")
		local dan = join("Dan")
		tick(Config.Run.StartCooldown + 0.1)
		remotes.fromClient("RequestMode", cat, "Coop")
		remotes.fromClient("RequestMode", dan, "Coop")
		check(remotes.count("StageStarted", cat.UserId) == 0, "co-op: waits for the party to gather")
		tick(Config.Modes.Coop.GatherSeconds + 0.2)
		local ci, di = info(cat), info(dan)
		check(ci and di and ci.mode == "Coop" and di.mode == "Coop", "co-op: both players start together")
		-- Cat stands still and gets caught: downed, not sent back.
		local entrance = cat:position()
		local catRetakes = ci.retakes
		-- Dan's own mannequin is held for this part, so only Cat goes down.
		MannequinService.holdForScare(dan, 30)
		walk(dan, { routeWaypoints(1)[2] }, Config.Movement.WalkSpeed)
		cat:moveTo(entrance + Vector3.new(6, 0, 0))
		tick(Config.Catch.GraceSeconds + Config.Mannequin.Delay + 1.5)
		check(cat.Character:GetAttribute("Downed") == true, "co-op: a caught player is downed")
		check(info(cat).retakes == catRetakes and info(cat).isRetake == false, "co-op: downed is not a retake")
		-- Dan walks back and stands next to Cat.
		walk(dan, { cat:position() + Vector3.new(2, 0, 0) }, Config.Movement.WalkSpeed)
		tick(Config.Modes.Coop.ReviveSeconds + 0.5)
		check(cat.Character:GetAttribute("Downed") == false, "co-op: a teammate revives you")
		-- Dan clears the stage: both move on.
		walk(dan, routeWaypoints(1), Config.Movement.WalkSpeed)
		check(stageOf(dan) == 2 and stageOf(cat) == 2, "co-op: one clear moves the whole party on")
		-- Everyone down: the party retakes the stage.
		local before = remotes.count("StageStarted", cat.UserId)
		cat:moveTo(cat:position() + Vector3.new(5, 0, 1))
		dan:moveTo(dan:position() + Vector3.new(5, 0, -1))
		tick(Config.Catch.GraceSeconds + Config.Mannequin.Delay + 6)
		check(remotes.count("StageStarted", cat.UserId) > before, "co-op: everyone down → the party takes it again")
		check(info(cat).isRetake == true and info(dan).isRetake == true, "co-op: both retake together")
	end

	check(
		#h.sched.errors == 0,
		"no errors in scheduled tasks" .. (h.sched.errors[1] and (": " .. h.sched.errors[1]) or "")
	)
end
