--[[
	Server sim boot: loads the place, mocks Remotes/MapBuilder prompt, runs the real
	Main.server.luau, and returns helpers (join/leave/tick/walk/routeWaypoints/...).
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

	return {
		h = h,
		Config = Config,
		remotes = remotes,
		prompt = prompt,
		Analytics = Analytics,
		mannequins = mannequins,
		layouts = layouts,
		tick = tick,
		join = join,
		leave = leave,
		stageOf = stageOf,
		v = v,
		routeWaypoints = routeWaypoints,
		walk = walk,
		analyticsCount = analyticsCount,
		SSS = SSS,
		RS = RS,
	}
end
