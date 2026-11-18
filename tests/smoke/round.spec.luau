--[[
	Server sim: boots the real Main.server.luau with fakes for players/remotes, then plays
	runs end to end — escape, catch, fall, death, fake exit, two players, leaving mid-chase,
	and malformed/spammed remotes.
]]

local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local Harness = require("./harness")
local Fakes = require("./fakes")

local DT = 1 / 30

return function(placePath, check, hooks)
	local h = Harness.load(placePath)
	local RS = h.place:GetService("ReplicatedStorage")
	local SSS = h.place:GetService("ServerScriptService")
	local Config = h.require(RS.Shared.Config)

	local remotes = Fakes.remotes(h.require(RS.Shared.Remotes), h.signal)
	h.mock(RS.Shared.Remotes, remotes)
	local prompt = { Triggered = h.signal() }
	local realMapBuilder = h.require(SSS.MapBuilder)
	h.mock(SSS.MapBuilder, {
		build = function()
			local built = realMapBuilder.build()
			built.startPrompt = prompt
			return built
		end,
	})
	if hooks and hooks.beforeBoot then
		hooks.beforeBoot(h)
	end

	-- Boot exactly what the server boots.
	local mainChunk = luau.load(SSS.Main.Source, {
		debugName = "Main",
		environment = (function()
			local env = table.clone(roblox)
			env.game = h.game
			env.require = h.require
			env.script = SSS.Main
			env.task = h.sched.task
			env.warn = function(...)
				print("[warn]", ...)
			end
			return env
		end)(),
	})
	local okBoot, bootErr = pcall(mainChunk)
	check(okBoot, "Main.server boots" .. (if okBoot then "" else ": " .. tostring(bootErr)))
	if not okBoot then
		return
	end

	local Analytics = h.require(SSS.Services.Analytics)
	local Players = h.stubs.Players
	local Heartbeat = h.stubs.RunService.Heartbeat
	local mannequins = h.place:GetService("Workspace"):FindFirstChild("Mannequins")
	local layouts = {}
	for i = 1, 3 do
		layouts[i] = h.require(SSS.MapBuilder.Layouts["Stage" .. i])
	end

	local function tick(seconds)
		local t = 0
		while t < seconds do
			t += DT
			h.sched.advance(DT)
			Heartbeat:Fire(DT)
		end
	end

	local function join(name)
		local player = Fakes.player(h.signal, name)
		table.insert(Players._list, player)
		Players.PlayerAdded:Fire(player)
		player:spawn(roblox.CFrame.new(0, 10, -220))
		tick(0.2)
		return player
	end

	local function leave(player)
		Players.PlayerRemoving:Fire(player)
		local i = table.find(Players._list, player)
		if i then
			table.remove(Players._list, i)
		end
		player.Parent = nil
	end

	local function stageOf(player)
		local args = remotes.last("StageStarted", player.UserId)
		return if args then args[1].stage else 0
	end

	local function v(t, origin)
		return Vector3.new(t[1] + origin[1], t[2] + origin[2], t[3] + origin[3])
	end

	--- Waypoints across a stage: top of every route element, then the stage's exit.
	local function routeWaypoints(stage, realExit)
		local layout = layouts[stage]
		local origin = Config.Map.StageOrigins[stage]
		local points = {}
		for _, box in layout.route do
			local top = box.center[2] + box.size[2] / 2
			table.insert(points, v({ box.center[1], top + 3, box.center[3] }, origin))
		end
		if layout.exitZone then
			table.insert(points, v(layout.exitZone.center, origin))
		elseif layout.exits then
			local zone = if realExit == "Left" then layout.exits.leftZone else layout.exits.rightZone
			table.insert(points, v(zone.center, origin))
		end
		return points
	end

	--- Walks the player along waypoints at walk speed until done or the stage changes.
	local function walk(player, points, speed)
		local startStage = stageOf(player)
		local finishedBefore = remotes.count("RunFinished", player.UserId)
		for _, target in points do
			while (player:position() - target).Magnitude > 0.5 do
				if stageOf(player) ~= startStage or remotes.count("RunFinished", player.UserId) > finishedBefore then
					return
				end
				local pos = player:position()
				local step = math.min(speed * DT, (target - pos).Magnitude)
				local dir = (target - pos).Unit
				player:moveTo(
					pos + dir * step,
					Vector3.new(dir.X, 0, dir.Z).Magnitude > 0.01 and Vector3.new(dir.X, 0, dir.Z).Unit or nil
				)
				tick(DT)
			end
		end
		tick(0.3)
	end

	local function analyticsCount(name, userId)
		local n = 0
		for _, e in Analytics.history do
			if e.name == name and e.userId == userId then
				n += 1
			end
		end
		return n
	end

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
	end
	check(remotes.count("DoorWarning", ana.UserId) >= 2, "painted doors warned during the run")
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

	if hooks and hooks.after then
		hooks.after(h, {
			remotes = remotes,
			join = join,
			leave = leave,
			tick = tick,
			walk = walk,
			routeWaypoints = routeWaypoints,
			stageOf = stageOf,
		})
	end
end
