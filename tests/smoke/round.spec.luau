--[[
	Server sim: boots the real Main.server.luau with fakes for players/remotes, then plays
	runs end to end — escape, catch, fall, death, fake exit, two players, leaving mid-chase,
	and malformed/spammed remotes.
]]

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local Sim = require("./sim")

return function(placePath, check)
	local sim = Sim(placePath, check)
	if not sim then
		return
	end
	local h, Config, remotes, prompt = sim.h, sim.Config, sim.remotes, sim.prompt
	local mannequins, layouts = sim.mannequins, sim.layouts
	local tick, join, leave, stageOf, v = sim.tick, sim.join, sim.leave, sim.stageOf, sim.v
	local routeWaypoints, walk, analyticsCount = sim.routeWaypoints, sim.walk, sim.analyticsCount

	print("\n== Smoke: server sim — full escape")
	local ana = join("Ana")
	check(remotes.count("RunStarted", ana.UserId) == 0, "joins into the lobby")
	prompt.Triggered:Fire(ana)
	tick(0.1)
	check(stageOf(ana) == 1, "stage door prompt starts stage 1")
	check(
		ana.Character.humanoid.UseJumpPower and ana.Character.humanoid.JumpPower == Config.Movement.JumpPower,
		"movement config applied"
	)
	check(mannequins and #mannequins:GetChildren() == 1, "one mannequin spawned for the runner")
	local entrance1 = v(layouts[1].spawn.pos, Config.Map.StageOrigins[1])
	check((ana:position() - entrance1).Magnitude < 0.1, "teleported to the stage 1 entrance")
	tick(3)
	check(remotes.count("Caught", ana.UserId) == 0, "no catch while reading the title card")
	for stage = 1, 3 do
		local info = remotes.last("StageStarted", ana.UserId)[1]
		walk(ana, routeWaypoints(stage, info.realExit), Config.Movement.WalkSpeed)
	end
	local finished = remotes.last("RunFinished", ana.UserId)
	check(finished ~= nil, "running the route at walk speed escapes the theatre")
	if finished then
		local ticket = finished[1]
		print(
			string.format(
				"       escape %.1fs, retakes %d, doors warned %d",
				ticket.escapeTime,
				ticket.retakes,
				remotes.count("DoorWarning", ana.UserId)
			)
		)
		check(ticket.retakes == 0 and ticket.titleEarned == "Opening Night", "zero retakes earns Opening Night")
		check(#ticket.seat > 0, "ticket has a seat")
		check(ticket.bestTime ~= nil and ticket.isNewBest, "ticket shows the new best from DataService")
	end
	check(remotes.count("DoorWarning", ana.UserId) >= 2, "painted doors warned during the run")
	check(remotes.count("Scare", ana.UserId) == 3, "each stage's scare plays exactly once")
	check(analyticsCount("stage_started", ana.UserId) == 3, "analytics: stage_started x3")
	check(analyticsCount("stage_cleared", ana.UserId) == 3, "analytics: stage_cleared x3")
	check(analyticsCount("finished", ana.UserId) == 1, "analytics: finished")
	check(#mannequins:GetChildren() == 0, "mannequin removed after finishing")

	print("\n== Smoke: server sim — caught, fell, died")
	tick(Config.Run.StartCooldown + 0.1)
	remotes.fromClient("RequestStart", ana)
	tick(0.1)
	check(stageOf(ana) == 1, "RequestStart remote restarts the show")
	walk(ana, { entrance1 + Vector3.new(6, 0, 0) }, 16)
	tick(Config.Catch.GraceSeconds + Config.Mannequin.Delay + 1)
	check(remotes.count("Caught", ana.UserId) == 1, "standing still gets you caught")
	check((remotes.last("Caught", ana.UserId) or {})[1] == 1, "caught increments retakes")
	tick(Config.Catch.RespawnDelay + 0.1)
	check((ana:position() - entrance1).Magnitude < 0.1, "caught → back to the stage entrance")
	check(remotes.last("StageStarted", ana.UserId)[1].isRetake, "retake card after a catch")
	tick(1)
	check(remotes.count("Caught", ana.UserId) == 1, "grace period: no instant re-catch")

	ana:moveTo(entrance1 + Vector3.new(10, -40, 0))
	tick(0.3)
	check(remotes.count("Fell", ana.UserId) == 1, "falling below the net line counts as a fall")
	tick(Config.Catch.RespawnDelay + 0.2)
	check((ana:position() - entrance1).Magnitude < 0.1, "fell → back to the stage entrance")

	ana.Character.humanoid.Health = 0
	ana.Character.humanoid.Died:Fire()
	tick(0.2)
	ana:spawn(roblox.CFrame.new(0, 10, -220))
	tick(0.3)
	check((ana:position() - entrance1).Magnitude < 0.1, "respawned character returns to the checkpoint")
	check(remotes.last("StageStarted", ana.UserId)[1].retakes == 3, "deaths count as retakes too")

	print("\n== Smoke: server sim — fake exit")
	remotes.fromClient("RequestLobby", ana)
	tick(Config.Run.StartCooldown + 0.1)
	check(remotes.count("ReturnedToLobby", ana.UserId) == 1, "RequestLobby returns to the lobby")
	check(analyticsCount("quit_stage", ana.UserId) == 1, "analytics: quit_stage when leaving a stage")
	remotes.fromClient("RequestStart", ana)
	tick(0.1)
	for stage = 1, 2 do
		walk(ana, routeWaypoints(stage), Config.Movement.WalkSpeed)
	end
	local info3 = remotes.last("StageStarted", ana.UserId)[1]
	check(
		info3.stage == 3 and (info3.realExit == "Left" or info3.realExit == "Right"),
		"stage 3 tells the client which exit is real"
	)
	local fakeSide = if info3.realExit == "Left" then "Right" else "Left"
	local route3 = routeWaypoints(3, fakeSide)
	walk(ana, route3, Config.Movement.WalkSpeed)
	check(remotes.count("FakeExit", ana.UserId) >= 1, "the painted exit is fake")
	check(remotes.count("RunFinished", ana.UserId) == 1, "fake exit doesn't finish the run")
	walk(ana, { route3[#route3 - 1], routeWaypoints(3, info3.realExit)[#route3] }, Config.Movement.WalkSpeed)
	check(remotes.count("RunFinished", ana.UserId) == 2, "the real exit finishes the run")

	print("\n== Smoke: server sim — two players")
	local ben = join("Ben")
	tick(Config.Run.StartCooldown + 0.1)
	remotes.fromClient("RequestStart", ana)
	remotes.fromClient("RequestStart", ben)
	tick(0.1)
	check(#mannequins:GetChildren() == 2, "each player gets their own mannequin")
	local owners = {}
	for _, m in mannequins:GetChildren() do
		owners[m:GetAttribute("OwnerUserId")] = true
	end
	check(owners[ana.UserId] and owners[ben.UserId], "mannequins are owned per player")
	local caughtBefore = remotes.count("Caught", ana.UserId)
	-- Ben idles near the entrance (gets caught); Ana keeps running.
	walk(ben, { entrance1 + Vector3.new(5, 0, 2) }, 16)
	local anaRoute = routeWaypoints(1)
	local benCaughtBefore = remotes.count("Caught", ben.UserId)
	walk(ana, anaRoute, Config.Movement.WalkSpeed)
	tick(Config.Catch.GraceSeconds + 2)
	check(remotes.count("Caught", ben.UserId) > benCaughtBefore, "idle player is caught by their own mannequin")
	check(remotes.count("Caught", ana.UserId) == caughtBefore, "the other player's mannequin never catches you")

	print("\n== Smoke: server sim — leaving mid-chase, bad remotes")
	leave(ben)
	tick(0.2)
	check(#mannequins:GetChildren() == 1, "leaving mid-chase removes your mannequin")
	check(analyticsCount("quit_stage", ben.UserId) == 1, "analytics: quit_stage on disconnect")
	local before = remotes.count("StageStarted", ana.UserId)
	remotes.fromClient("RequestLobby", ana, "extra", 1)
	remotes.fromClient("SetSetting", ana, "ReducedScares")
	remotes.fromClient("SetSetting", ana, { evil = true }, true)
	tick(0.1)
	check(remotes.count("ReturnedToLobby", ana.UserId) == 1, "remotes with extra arguments are ignored")
	for _ = 1, 50 do
		remotes.fromClient("RequestLobby", ana)
		remotes.fromClient("RequestStart", ana)
	end
	tick(0.1)
	check(
		remotes.count("StageStarted", ana.UserId) - before <= Config.Remotes.Burst,
		"spammed remotes are rate limited"
	)
	check(
		#h.sched.errors == 0,
		"no errors in scheduled tasks" .. (if #h.sched.errors > 0 then ": " .. h.sched.errors[1] else "")
	)
end
