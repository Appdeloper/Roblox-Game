--[[
	Client smoke spec: boots the real client Main against a built map and drives it with
	every server→client message, then presses the important buttons.
]]

local roblox = require("@lune/roblox")
local Harness = require("./harness")
local Fakes = require("./fakes")
local ClientHarness = require("./client")

return function(placePath, check)
	print("\n== Smoke: client")
	local h = Harness.load(placePath)
	local SSS = h.place:GetService("ServerScriptService")
	local map = h.require(SSS.MapBuilder).build()
	local c = ClientHarness.boot(h, Fakes)

	local ok, err = pcall(c.runMain)
	check(ok, "client Main boots" .. (if ok then "" else ": " .. tostring(err)))
	if not ok then
		return
	end
	c.tick(0.5)
	check(c.find("DLB_Hud") ~= nil and c.find("DLB_Modal") ~= nil, "screen guis created")
	check(c.find("BigJump") ~= nil, "big mobile jump button on touch devices")
	check(c.find("Start") ~= nil, "lobby start button")

	local function step(name, fn)
		local okStep, stepErr = pcall(fn)
		check(okStep, name .. (if okStep then "" else ": " .. tostring(stepErr)))
		local okTick, tickErr = pcall(c.tick, 0.3)
		if not okTick then
			check(false, name .. " (follow-up frames): " .. tostring(tickErr))
		end
	end

	local r = c.remotes
	local entrance = map.stages[1].entrance
	c.character.root.CFrame = entrance

	step("profile snapshot applies", function()
		r.fromServer("ProfileUpdated", {
			bestTime = 95.5,
			totalEscapes = 2,
			titles = { "OpeningNight" },
			ownedSkins = { "Classic", "Golden" },
			equippedSkin = "Golden",
			ownsSpotlightTrail = false,
			trailEnabled = false,
			reducedScares = false,
			savingEnabled = true,
		})
	end)
	step("lobby start button fires RequestStart", function()
		c.find("Start").Activated:Fire()
	end)
	check(r.sent("RequestStart") == 1, "RequestStart sent once")

	local function stageInfo(stage, isRetake, retakes)
		return {
			stage = stage,
			title = "Stage " .. stage,
			act = "ACT " .. stage,
			hint = "hint",
			isRetake = isRetake,
			realExit = if stage == 3 then "Left" else nil,
			runStartedAt = 1000,
			retakes = retakes,
		}
	end

	step("run + stage 1 title card", function()
		r.fromServer("RunStarted", 1000)
		r.fromServer("StageStarted", stageInfo(1, false, 0))
	end)
	c.tick(1)
	local timer = c.find("Timer")
	check(timer and timer.Visible, "timer visible while running")
	step("caught → retake slate", function()
		r.fromServer("Caught", 1)
		r.fromServer("StageStarted", stageInfo(1, true, 1))
	end)
	step("fell", function()
		r.fromServer("Fell", 2)
	end)
	step("door warning + open + outran", function()
		r.fromServer("DoorWarning", map.stages[1].doors[1].id, 2)
		c.tick(1)
		r.fromServer("DoorOpened", map.stages[1].doors[1].id)
		r.fromServer("DoorOutran", map.stages[1].doors[1].id)
	end)
	c.tick(4)
	step("stage 1 scare (shadow bow)", function()
		r.fromServer("Scare", 1)
	end)
	c.tick(6)
	step("stage 2 + window scare + backdrop", function()
		r.fromServer("StageStarted", stageInfo(2, false, 2))
		c.character.root.CFrame = roblox.CFrame.new(map.stages[2].entrance.Position + roblox.Vector3.new(130, -3, 0))
		r.fromServer("Scare", 2)
	end)
	c.tick(6)
	step("stage 3 + collapsing step + knock/applause + fake exit", function()
		r.fromServer("StageStarted", stageInfo(3, false, 2))
		local stepPart = h.game:GetService("CollectionService"):GetTagged("CollapseStep")[1]
		c.character.root.CFrame = stepPart.CFrame * roblox.CFrame.new(0, 3.5, 0)
		r.fromServer("Scare", 3)
		r.fromServer("FakeExit")
	end)
	c.tick(6)
	step("scare skip button", function()
		r.fromServer("Scare", 3)
		c.tick(0.2)
		local skip = c.find("Skip")
		skip.Activated:Fire()
	end)
	check(r.sent("ScareSkipped") >= 1, "skip tells the server (analytics)")

	step("settings: reduced scares toggle", function()
		c.find("SettingsButton").Activated:Fire()
		c.find("ReducedToggle").Activated:Fire()
	end)
	check(r.sent("SetSetting") == 1, "SetSetting sent")
	step("settings: leave the show", function()
		c.find("Leave").Activated:Fire()
	end)
	check(r.sent("RequestLobby") == 1, "RequestLobby sent")

	step("mobile jump button jumps", function()
		local input = { UserInputType = roblox.Enum.UserInputType.Touch }
		c.find("BigJump").InputBegan:Fire(input)
		c.tick(0.1)
		c.stubs.UserInputService.InputEnded:Fire(input)
	end)
	check(c.character.humanoid.Jump == true, "humanoid.Jump set by the big button")

	for _, skin in { "Classic", "OpeningNight", "VelvetCurtain", "Golden", "Moonlit" } do
		step("finish ticket renders skin " .. skin, function()
			r.fromServer("RunFinished", {
				escapeTime = 123.45,
				retakes = 0,
				bestTime = 120.1,
				isNewBest = skin == "Golden",
				titleEarned = "Opening Night",
				skin = skin,
				playerName = "Tester",
				seat = "C7",
			})
			c.tick(1)
			check(c.find("Ticket") ~= nil, "ticket shown (" .. skin .. ")")
		end)
	end
	step("ticket encore button", function()
		c.find("Encore").Activated:Fire()
	end)
	check(r.sent("RequestStart") == 2, "Encore sends RequestStart")
	step("returned to lobby + notify", function()
		r.fromServer("ReturnedToLobby")
		r.fromServer("Notify", "Hello!")
	end)
	check(
		#h.sched.errors == 0,
		"no errors in client scheduled tasks" .. (if #h.sched.errors > 0 then ": " .. h.sched.errors[1] else "")
	)
end
