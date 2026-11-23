--!strict
local Config = require("../src/shared/Config")
local Progression = require("../src/shared/Progression")

return function(T)
	T.suite("Progression")

	local function facts(overrides: any?): Progression.Facts
		local f: any = { titles = {}, trophies = {}, bestStreak = 0, passes = {} }
		for k, v in overrides or {} do
			f[k] = v
		end
		return f
	end

	T.test("every cosmetic unlock points at something real", function()
		for category, items in Config.Cosmetics do
			T.expect(items[Config.DefaultCosmetics[category]] ~= nil, category .. " default exists")
			for id, item in items do
				local u = item.Unlock
				if u.Kind == "Title" then
					T.expect(Config.Titles[u.Key] ~= nil, id .. " title")
				elseif u.Kind == "Trophy" then
					T.expect(Config.Trophies[u.Key] ~= nil, id .. " trophy")
				elseif u.Kind == "GamePass" then
					T.expect(Config.Monetization.GamePasses[u.Key] ~= nil, id .. " pass")
				elseif u.Kind == "Product" then
					local product = Config.Monetization.Products[u.Key]
					T.expect(product ~= nil, id .. " product")
					T.expect(
						product.GrantsCosmetic[1] == category and product.GrantsCosmetic[2] == id,
						id .. " product grants it"
					)
				elseif u.Kind == "Streak" then
					T.expect(type(u.Key) == "number" and u.Key >= 1, id .. " streak")
				else
					T.eq(u.Kind, "Free", id .. " kind")
				end
				T.expect(#item.Color == 3, id .. " colour")
			end
		end
	end)

	T.test("every trophy has a badge slot", function()
		for key in Config.Trophies do
			T.expect(Config.Badges[key] ~= nil, key .. " badge")
		end
	end)

	T.test("defaults are free; earned items need the thing", function()
		for category, id in Config.DefaultCosmetics do
			T.expect(Progression.ownsCosmetic(Config.Cosmetics, category, id, facts()), id .. " free")
		end
		T.expect(not Progression.ownsCosmetic(Config.Cosmetics, "Trail", "Confetti", facts()), "locked")
		T.expect(
			Progression.ownsCosmetic(Config.Cosmetics, "Trail", "Confetti", facts({ trophies = { FullHouse = true } })),
			"trophy unlock"
		)
		T.expect(
			Progression.ownsCosmetic(
				Config.Cosmetics,
				"MannequinSkin",
				"Ebony",
				facts({ titles = { OpeningNight = true } })
			),
			"title unlock"
		)
		T.expect(
			not Progression.ownsCosmetic(Config.Cosmetics, "Trail", "Spotlight", facts({ bestStreak = 99 })),
			"a pass can't be earned by streak"
		)
		T.expect(not Progression.ownsCosmetic(Config.Cosmetics, "Trail", "Nope", facts()), "unknown id")
		T.expect(
			Progression.ownsCosmetic(
				Config.Cosmetics,
				"Trail",
				"Sparkler",
				facts({ products = { SparklerTrail = true } })
			),
			"a bought product unlocks its cosmetic"
		)
		T.expect(
			Progression.ownsCosmetic(
				Config.Cosmetics,
				"Playbill",
				"Starlight",
				facts({ passes = { PlaybillCollection = true } })
			),
			"a game pass unlocks its playbills"
		)
	end)

	T.test("daily streak", function()
		local s = Progression.login(nil, 0, 0, 100)
		T.expect(s.isNewDay and s.streak == 1, "first visit")
		s = Progression.login(100, 1, 1, 100)
		T.expect(not s.isNewDay and s.streak == 1, "same day: no change")
		s = Progression.login(100, 1, 1, 101)
		T.expect(s.streak == 2 and s.best == 2, "next day: +1")
		s = Progression.login(101, 2, 2, 105)
		T.expect(s.streak == 1 and s.best == 2, "gap: back to 1, best kept")
	end)

	T.test("streak rewards are announced once, on the day they unlock", function()
		local two = Progression.newlyUnlocked(Config.Cosmetics, 2)
		T.expect(#two >= 1 and two[1].id == "StageDust", "day 2 reward")
		T.eq(#Progression.newlyUnlocked(Config.Cosmetics, 4), 0, "nothing on day 4")
	end)
end
