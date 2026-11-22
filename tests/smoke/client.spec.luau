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
	-- A server mannequin owned by the test client, so animator/heartbeat/creak paths run.
	local MannequinRig = h.require(h.place:GetService("ReplicatedStorage").Shared.MannequinRig)
	local rig = MannequinRig.build("Mannequin_4242", map.stages[1].entrance * roblox.CFrame.new(0, 0, 6))
	rig.model:SetAttribute("OwnerUserId", 4242)
	rig.model.Parent = h.place:GetService("Workspace")
	local otherRig = MannequinRig.build("Mannequin_1", map.stages[1].entrance * roblox.CFrame.new(0, 0, 20))
	otherRig.model:SetAttribute("OwnerUserId", 1)
	otherRig.model:SetAttribute("Pose", "Bow")
	otherRig.model.Parent = h.place:GetService("Workspace")

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
	step("wardrobe opens and renders cards", function()
		c.find("Wardrobe").Activated:Fire()
		c.tick(0.2)
	end)
	check(c.find("WardrobeLayer").Visible and c.find("Card_Golden Ticket") ~= nil, "wardrobe shows ticket skins")
	step("wardrobe equip + buy buttons", function()
		for _, cardName in
			{ "Card_Classic Stub", "Card_Opening Night", "Card_Moonlit", "Card_Spotlight Trail", "Card_Velvet Curtain" }
		do
			c.find(cardName).Action.Activated:Fire()
		end
		c.find("CloseWardrobe").Activated:Fire()
	end)
	check(r.sent("EquipSkin") == 1, "equipping an owned skin asks the server")
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
	rig.root.CFrame = rig.root.CFrame * roblox.CFrame.new(0, 0, -2)
	c.tick(0.5)
	local vignette = c.find("Vignette1")
	check(vignette and vignette.BackgroundTransparency < 1, "proximity vignette shows when your mannequin is close")
	local part = otherRig.model:FindFirstChild("Torso")
	check(part.LocalTransparencyModifier > 0, "other players' mannequins are faded")
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
	-- ── Living environment ────────────────────────────────────────────────────────────────
	print("\n== Smoke: living environment")
	local Workspace = h.place:GetService("Workspace")
	local serverTags = h.game:GetService("CollectionService")

	local creaky = serverTags:GetTagged("Creaky")[1]
	check(creaky ~= nil, "loose floorboards exist to creak")
	if creaky then
		c.character.humanoid.MoveDirection = roblox.Vector3.new(1, 0, 0)
		c.character.root.CFrame = creaky.CFrame * roblox.CFrame.new(0, 3, 0)
		c.tick(0.4)
		local host = Workspace:FindFirstChild("DustPuffHost")
		check(
			host ~= nil and (host.CFrame.Position - creaky.CFrame.Position).Magnitude < 6,
			"stepping on a loose board puffs dust where you stepped"
		)
	end

	local curtain = serverTags:GetTagged("Curtain")[1]
	check(curtain ~= nil, "curtains exist to ripple")
	if curtain then
		local Curtains = c.require(h.place:GetService("StarterPlayer").StarterPlayerScripts.Client.World.Curtains)
		local before = Curtains.rippled
		-- Arrive next to it at a run: two logic ticks far apart = high speed.
		c.character.root.CFrame = curtain.CFrame * roblox.CFrame.new(0, 0, 40)
		c.tick(0.2)
		c.character.root.CFrame = curtain.CFrame * roblox.CFrame.new(0, 0, 6)
		c.tick(0.4)
		check(Curtains.rippled > before, "running past a curtain makes it ripple")
		-- Standing still must not keep kicking the fabric.
		local settled = Curtains.rippled
		c.tick(1.5)
		check(Curtains.rippled == settled, "standing still leaves the curtains alone")
	end

	local lampPart = serverTags:GetTagged("FlickerLamp")[1]
	check(lampPart ~= nil, "lamps exist to flicker")
	if lampPart then
		local light = lampPart:FindFirstChildWhichIsA("Light")
		local original = light.Brightness
		local dipped = false
		for _ = 1, 40 do
			c.tick(0.5)
			if light.Brightness < original then
				dipped = true
				break
			end
		end
		check(dipped, "lamps flicker on their own")
	end

	local swinging = serverTags:GetTagged("SwingProp")[1]
	check(swinging ~= nil, "counterweight sandbags hang from the rigging")
	if swinging then
		local before = swinging.CFrame
		-- Pendulums are skipped far from the camera, so look at it.
		c.camera.CFrame = roblox.CFrame.new(swinging.CFrame.Position)
		c.tick(1.5)
		check(swinging.CFrame ~= before, "sandbags swing")
	end
	c.character.humanoid.MoveDirection = roblox.Vector3.zero

	step("returned to lobby + notify", function()
		r.fromServer("ReturnedToLobby")
		r.fromServer("Notify", "Hello!")
	end)
	check(
		#h.sched.errors == 0,
		"no errors in client scheduled tasks" .. (if #h.sched.errors > 0 then ": " .. h.sched.errors[1] else "")
	)
end
