--[[
	Leaderboard + badges specs on the server sim (fake OrderedDataStore / BadgeService).
]]

local Sim = require("./sim")

return function(placePath, check)
	print("\n== Smoke: leaderboard + badges")
	local sim = Sim(placePath, check)
	if not sim then
		return
	end
	local h, Config, remotes = sim.h, sim.Config, sim.remotes
	local LeaderboardService = h.require(sim.SSS.Services.LeaderboardService)
	local ordered = h.stubs.DataStoreService:GetOrderedDataStore(Config.Leaderboard.StoreName)
	local badges = h.stubs.BadgeService
	-- Real IDs for this test (placeholders are 0 in the shipped Config).
	Config.Badges.FirstEscape, Config.Badges.OpeningNight, Config.Badges.SpottedTheDoor = 101, 102, 103

	local function escape(player)
		sim.remotes.fromClient("RequestStart", player)
		sim.tick(0.2)
		for stage = 1, 3 do
			local info = remotes.last("StageStarted", player.UserId)[1]
			sim.walk(player, sim.routeWaypoints(stage, info.realExit), Config.Movement.WalkSpeed)
		end
		return remotes.last("RunFinished", player.UserId)
	end

	local ana = sim.join("BoardAna")
	local finished = escape(ana)
	check(finished ~= nil, "escape completes")
	sim.tick(1)
	local stored = ordered.data[tostring(ana.UserId)]
	check(
		type(stored) == "number" and math.abs(stored / 100 - finished[1].escapeTime) < 0.02,
		"best time stored in centiseconds"
	)

	ordered.data[tostring(ana.UserId)] = 1000 -- pretend an older, faster record exists (10 s)
	LeaderboardService.submit(ana, 99)
	check(ordered.data[tostring(ana.UserId)] == 1000, "a slower time never replaces a faster one")
	LeaderboardService.submit(ana, 5)
	check(ordered.data[tostring(ana.UserId)] == 500, "a faster time replaces the record")

	ordered.data["777"] = 4000
	LeaderboardService.refresh()
	local board = h.place:GetService("Workspace").Map:FindFirstChild("LeaderboardGui", true)
	local row1 = board and board.List.Row1.Text or ""
	local row2 = board and board.List.Row2.Text or ""
	check(
		string.find(row1, "BoardAna") ~= nil and string.find(row1, "00:05.00") ~= nil,
		"lobby board shows the fastest first"
	)
	check(string.find(row2, "Player777") ~= nil, "board resolves offline names")

	local function has(userId, badgeId)
		for _, a in badges.awarded do
			if a.userId == userId and a.badgeId == badgeId then
				return true
			end
		end
		return false
	end
	check(has(ana.UserId, 101), "First Escape badge awarded")
	local zeroRetakes = finished[1].retakes == 0
	check(has(ana.UserId, 102) == zeroRetakes, "Opening Night badge only for zero retakes")
	local outran = remotes.count("DoorOutran", ana.UserId) > 0
	check(has(ana.UserId, 103) == outran, "Spotted the Door matches outrunning a door")

	-- Unverified (impossibly fast) runs don't reach the board or badges.
	local cheat = sim.join("BoardCheat")
	sim.remotes.fromClient("RequestStart", cheat)
	sim.tick(0.2)
	for stage = 1, 3 do
		local info = remotes.last("StageStarted", cheat.UserId)[1]
		local points = sim.routeWaypoints(stage, info.realExit)
		cheat:moveTo(points[#points])
		sim.tick(0.3)
	end
	check(remotes.count("RunFinished", cheat.UserId) == 1, "teleport-run still finishes (no soft lock)")
	sim.tick(1)
	check(ordered.data[tostring(cheat.UserId)] == nil, "unverified run kept off the leaderboard")
	check(not has(cheat.UserId, 101), "unverified run earns no badge")
	check(
		#h.sched.errors == 0,
		"no errors in scheduled tasks" .. (if #h.sched.errors > 0 then ": " .. h.sched.errors[1] else "")
	)
end
