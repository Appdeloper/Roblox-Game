--[[
	Mannequin behaviour specs (Lune). Drives the real Trail + Mannequin modules with a fake
	clock and a scripted player path through the built Stage 1 geometry.
]]

local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Instance = roblox.Instance

return function(h, map, check)
	local SSS = h.place:GetService("ServerScriptService")
	local Config = h.require(h.place:GetService("ReplicatedStorage").Shared.Config)
	local Trail = h.require(SSS.Services.Mannequin.Trail)
	local Mannequin = h.require(SSS.Services.Mannequin.Mannequin)
	local stage = map.stages[1]
	local folder = Instance.new("Folder")
	folder.Parent = h.place:GetService("Workspace")

	print("\n== Smoke: Trail")
	do
		local t = Trail.new()
		for i = 0, 10 do
			t:push(i * 0.1, CFrame.new(i, 0, 0))
		end
		check(math.abs(t:sample(0.25).Position.X - 2.5) < 1e-6, "sample interpolates between samples")
		check(t:sample(99).Position.X == 10, "sample clamps past the end")
		check(t:sample(-5).Position.X == 0, "sample clamps before the start")
		t:prune(0.55)
		check(math.abs(t:sample(0.55).Position.X - 5.5) < 1e-6, "prune keeps a sample before the cut")
		check(
			math.abs((t:nearestTime(Vector3.new(7.2, 0, 0), 0, 1) or -1) - 0.7) < 1e-9,
			"nearestTime finds the closest sample"
		)
		check(t:nearestTime(Vector3.new(7.2, 0, 0), 0.8, 0.5) == nil, "nearestTime respects since + radius")
		t:push(0.5, CFrame.new())
		check(t:lastTime() == 1, "push ignores out-of-order samples")
		for i = 11, 2000 do
			t:push(i * 0.1, CFrame.new(i, 0, 0))
			t:prune(i * 0.1 - 1)
		end
		check(t:count() < 40 and t.head < 300, "long runs stay bounded (compaction)")
		check(math.abs(t:sample(199.95).Position.X - 1999.5) < 1e-6, "sampling still correct after compaction")
	end

	print("\n== Smoke: Mannequin")
	local log = {}
	local function events()
		return {
			caught = function()
				table.insert(log, "caught")
			end,
			doorWarning = function(id)
				table.insert(log, "warning:" .. id)
			end,
			doorOpened = function(id)
				table.insert(log, "opened:" .. id)
			end,
			doorOutran = function(id)
				table.insert(log, "outran:" .. id)
			end,
		}
	end
	local function count(name)
		local n = 0
		for _, e in log do
			if e == name then
				n += 1
			end
		end
		return n
	end

	local DT = 1 / 60
	local entrance = stage.entrance

	-- Runs the sim from t0 to t1; `pathAt(t)` returns the player CFrame (or nil).
	local function run(m, t0, t1, pathAt, onTick)
		local t = t0
		while t < t1 do
			t += DT
			local cf = pathAt(t)
			m:update(t, DT, cf)
			if onTick then
				onTick(t, cf)
			end
		end
		return t
	end

	local function line(startT, from, dir, speed, stopAt)
		return function(t)
			local travel = math.max(0, math.min(t, stopAt or math.huge) - startT) * speed
			local pos = from + dir * travel
			return CFrame.lookAt(pos, pos + dir)
		end
	end

	-- 1) Standing still at the entrance: the mannequin never leaves home.
	do
		table.clear(log)
		local m = Mannequin.new("TestA", 1, folder, events())
		m:reset(stage, 0)
		run(m, 0, 6, function()
			return entrance
		end)
		check(m.state == "Idle", "stays Idle while the player reads the title card")
		check((m.position - stage.mannequinHome.Position).Magnitude < 1e-3, "stays at its home spot")
		check(count("caught") == 0, "no catch while idle")
		m:destroy()
	end

	-- 2) Running: copies the player exactly Delay seconds late; 3) stopping gets you caught.
	do
		table.clear(log)
		local m = Mannequin.new("TestB", 2, folder, events())
		m:reset(stage, 0)
		local path = line(0, entrance.Position, Vector3.new(1, 0, 0), 16, 6)
		local sawWarmup = false
		run(m, 0, 1.4, path, function()
			sawWarmup = sawWarmup or m.state == "Warmup"
		end)
		check(sawWarmup and m.state == "Warmup", "waits for a full delay of history before copying")
		run(m, 1.4, 4, path)
		check(m.state == "Trailing", "trails once Delay of history exists")
		local expected = path(4 - Config.Mannequin.Delay).Position
		local err = (m.position - expected).Magnitude
		check(
			err < 0.6,
			string.format("replays the player's position %.1fs late (error %.2f studs)", Config.Mannequin.Delay, err)
		)
		local caughtAt = nil
		run(m, 4, 10, path, function(t)
			if not caughtAt and count("caught") > 0 then
				caughtAt = t
			end
		end)
		check(caughtAt ~= nil, "catches a player who stops")
		check(
			caughtAt and caughtAt > 6 and caughtAt < 6 + Config.Mannequin.Delay + 0.2,
			string.format("catch lands within Delay after stopping (%.2fs)", (caughtAt or 0) - 6)
		)
		check(count("caught") == 1, "catch fires once until reset")
		m:destroy()
	end

	-- 4) Grace period: after a reset the mannequin cannot catch you straight away.
	do
		table.clear(log)
		local m = Mannequin.new("TestC", 3, folder, events())
		m:reset(stage, 100)
		local standing = entrance * CFrame.new(0, 0, -4) -- 4 studs forward: starts recording
		local caughtAt = nil
		run(m, 100, 108, function()
			return standing
		end, function(t)
			if not caughtAt and count("caught") > 0 then
				caughtAt = t
			end
		end)
		check(
			caughtAt ~= nil and caughtAt >= 100 + Config.Catch.GraceSeconds,
			"no catch during the respawn grace period"
		)
		m:destroy()
	end

	-- 5) Scare hold freezes the mannequin and disables catching.
	do
		table.clear(log)
		local m = Mannequin.new("TestD", 4, folder, events())
		m:reset(stage, 0)
		local path = line(0, entrance.Position, Vector3.new(1, 0, 0), 16)
		run(m, 0, 5, path)
		m:holdForScare(2, 5)
		local frozenAt = m.position
		run(m, 5, 6.9, function()
			return CFrame.new(frozenAt)
		end)
		check((m.position - frozenAt).Magnitude < 1e-3, "frozen during a scare")
		check(count("caught") == 0, "no catch during a scare, even standing on it")
		m:bow(0, 1, 7)
		m:update(7.01, DT, path(7.01))
		check(m.rig.model:GetAttribute("Pose") == "Bow", "bow pose is published as an attribute")
		m:destroy()
	end

	-- 6) Painted door: warning → hidden path → door opens after the warning → rejoins trail.
	do
		table.clear(log)
		local door = stage.doors[1]
		local m = Mannequin.new("TestE", 5, folder, events())
		m:reset(stage, 0)
		local triggerPos = door.triggerCFrame.Position
		local waypoints = { entrance.Position, triggerPos, door.exitStep, door.exitStep + Vector3.new(30, 5, -18) }
		local function pathAt(t)
			local remaining = t * 14
			for i = 1, #waypoints - 1 do
				local a, b = waypoints[i], waypoints[i + 1]
				local len = (b - a).Magnitude
				if remaining <= len then
					local pos = a + (b - a).Unit * remaining
					return CFrame.lookAt(pos, pos + (b - a).Unit)
				end
				remaining -= len
			end
			return CFrame.new(waypoints[#waypoints])
		end
		local triggeredAt, openedAt, hiddenCatchable = nil, nil, false
		local states = {}
		run(m, 0, 16, pathAt, function(t, cf)
			states[m.state] = true
			local inside = (cf.Position - triggerPos).Magnitude < 6
			if inside and not triggeredAt and m:tryDoor(door, t) then
				triggeredAt = t
			end
			if not openedAt and table.find(log, "opened:" .. door.id) then
				openedAt = t
			end
			if m.state == "Shortcut" and m.shortcut and m.shortcut.phase ~= "StepOut" and m:canCatch(t) then
				hiddenCatchable = true
			end
		end)
		check(triggeredAt ~= nil, "door triggers while trailing")
		check(log[1] == "warning:" .. door.id, "warning is sent the moment the door triggers")
		check(
			openedAt ~= nil and openedAt - triggeredAt >= Config.Door.MinWarningSeconds,
			"door opens only after the warning time"
		)
		check(not hiddenCatchable, "cannot catch while hidden behind the scenery")
		check(states.Ambush == true or states.Trailing == true, "steps out and resumes the chase")
		check(m.state == "Trailing", "back to trailing after the shortcut")
		check(not m:tryDoor(door, 20), "each door is used once per attempt")
		m:reset(stage, 30)
		check(next(m.doorsUsed) == nil, "doors re-arm after a retake")
		m:destroy()
	end
end
