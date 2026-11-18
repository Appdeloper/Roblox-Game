--!strict
local Config = require("../src/shared/Config")
local Assets = require("../src/shared/Assets")

return function(T)
	T.suite("Config")

	T.test("stage count matches stage text and origins", function()
		T.eq(#Config.Stages, Config.Game.StageCount, "Stages")
		T.eq(#Config.Map.StageOrigins, Config.Game.StageCount, "StageOrigins")
		T.eq(#Config.AntiCheat.MinStageSeconds, Config.Game.StageCount, "MinStageSeconds")
	end)

	T.test("mannequin delay matches spec and is replayable", function()
		T.eq(Config.Mannequin.Delay, 1.5, "Delay")
		T.eq(Config.Mannequin.SampleRate, 20, "SampleRate")
		T.expect(Config.Mannequin.MaxTrailSeconds > Config.Mannequin.Delay * 4, "trail must outlast delay")
	end)

	T.test("grace period outlasts the respawn delay", function()
		T.expect(Config.Catch.GraceSeconds > Config.Catch.RespawnDelay, "grace too short")
	end)

	T.test("door rejoin never closer than catch reach", function()
		-- At walk speed, MinRejoinDelay seconds of trail must be longer than the catch distance.
		local studsBehind = Config.Door.MinRejoinDelay * Config.Movement.WalkSpeed
		T.expect(studsBehind > Config.Catch.Distance * 2, "rejoin delay lets the mannequin catch a running player")
	end)

	T.test("staircase wobble is a visible part of the collapse delay", function()
		local s = Config.Hazards.Staircase
		T.expect(s.WobbleSeconds < s.CollapseDelay, "wobble must fit inside collapse delay")
	end)

	T.test("every ticket skin unlock points at a real source", function()
		for id, skin in Config.TicketSkins do
			local kind = skin.Unlock.Kind
			if kind == "GamePass" then
				T.expect(Config.Monetization.GamePasses[skin.Unlock.Key] ~= nil, id .. " gamepass missing")
			elseif kind == "Product" then
				T.expect(Config.Monetization.Products[skin.Unlock.Key] ~= nil, id .. " product missing")
			elseif kind == "Title" then
				T.expect(Config.Titles[skin.Unlock.Key] ~= nil, id .. " title missing")
			else
				T.eq(kind, "Free", id .. " unlock kind")
			end
		end
		T.expect(Config.TicketSkins[Config.DefaultTicketSkin] ~= nil, "default skin missing")
	end)

	T.test("monetization grants reference real skins", function()
		for key, pass in Config.Monetization.GamePasses do
			local grants = (pass :: any).GrantsSkin
			if grants then
				T.expect(Config.TicketSkins[grants] ~= nil, key .. " grants unknown skin")
			end
		end
		for key, product in Config.Monetization.Products do
			T.expect(Config.TicketSkins[product.GrantsSkin] ~= nil, key .. " grants unknown skin")
		end
	end)

	T.test("assets helper hides placeholder ids", function()
		T.eq(Assets.uri(0), "", "placeholder uri")
		T.eq(Assets.uri(123), "rbxassetid://123", "real uri")
		T.expect(#Assets.listPlaceholders() > 0, "placeholders are listed")
	end)
end
