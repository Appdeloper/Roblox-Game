--!strict
local Config = require("../src/shared/Config")
local Lore = require("../src/shared/Lore")

-- A board line longer than this stops being readable at a glance on a phone.
local MAX_LINE = 44

local function allLines(): { { where: string, line: Lore.Line } }
	local out = {}
	local function add(where: string, lines: { Lore.Line })
		for _, line in lines do
			table.insert(out, { where = where, line = line })
		end
	end
	add("CastList", Lore.CastList.Lines)
	add("Schedule", Lore.Schedule.Lines)
	for name, notice in Lore.Notices do
		add("Notices." .. name, notice.Lines)
	end
	return out
end

return function(T)
	T.suite("Lore")

	T.test("one act per stage, titles match Config", function()
		T.eq(#Lore.Acts, Config.Game.StageCount, "act count")
		for i, act in Lore.Acts do
			T.eq(act.Title, string.upper(Config.Stages[i].Title), "act " .. i .. " title")
			T.expect(#act.Numeral > 0, "act " .. i .. " numeral")
		end
	end)

	T.test("exactly one cast member is crossed out", function()
		local struck = 0
		for _, line in Lore.CastList.Lines do
			if line.struck then
				struck += 1
			end
		end
		T.eq(struck, 1, "the story beat is one missing lead")
	end)

	T.test("the mannequin is the understudy, named in cast and on a tag", function()
		local inCast = false
		for _, line in Lore.CastList.Lines do
			inCast = inCast or (string.find(line.text, Lore.MannequinName, 1, true) ~= nil and line.accent == true)
		end
		T.expect(inCast, "named in the cast list")
		local tagged = false
		for _, tag in Lore.CostumeTags do
			if tag.name == Lore.MannequinName then
				tagged = true
				T.eq(tag.role, "UNDERSTUDY", "tag role")
			end
		end
		T.expect(tagged, "named on a costume tag")
	end)

	T.test("the countdown has run out", function()
		T.eq(Lore.Countdown.Current, "0", "today")
		T.expect(#Lore.Countdown.Previous > 0, "earlier days were crossed off")
		local seen = {}
		for _, day in Lore.Countdown.Previous do
			T.expect(seen[day] == nil, "day " .. day .. " listed twice")
			T.expect(day ~= Lore.Countdown.Current, "a previous day repeats today")
			seen[day] = true
		end
	end)

	T.test("the dress rehearsal is the only schedule line not struck off", function()
		local open = {}
		for _, line in Lore.Schedule.Lines do
			if not line.struck and line.text ~= "" and line.accent then
				table.insert(open, line.text)
			end
		end
		T.eq(#open, 1, "one unfinished rehearsal")
		T.expect(string.find(open[1], "DRESS", 1, true) ~= nil, "it is the dress rehearsal")
	end)

	T.test("every line is short enough to read at a glance", function()
		for _, entry in allLines() do
			T.expect(
				#entry.line.text <= MAX_LINE,
				string.format(
					"%s line too long (%d > %d): %s",
					entry.where,
					#entry.line.text,
					MAX_LINE,
					entry.line.text
				)
			)
		end
		for _, page in Lore.ScriptPages do
			T.expect(#page <= MAX_LINE, "script page too long: " .. page)
		end
		for _, side in { Lore.PromptBook.Left, Lore.PromptBook.Right } do
			for _, line in side do
				T.expect(#line <= 24, "prompt book line too long: " .. line)
			end
		end
	end)

	T.test("no real-world names are implied and the tone stays kid-safe", function()
		local banned = { "blood", "dead", "kill", "corpse", "murder", "ghost of" }
		local haystack = string.lower(table.concat({
			Lore.Play.Title,
			Lore.Play.Subtitle,
			Lore.Play.Company,
			Lore.Play.Venue,
			Lore.Countdown.Heading,
			Lore.Countdown.Footer,
		}, " "))
		for _, entry in allLines() do
			haystack ..= " " .. string.lower(entry.line.text)
		end
		for _, page in Lore.ScriptPages do
			haystack ..= " " .. string.lower(page)
		end
		for _, word in banned do
			T.expect(string.find(haystack, word, 1, true) == nil, "found '" .. word .. "' in the lore")
		end
	end)

	T.test("mechanic hints exist for the things players must learn", function()
		for _, key in { "PaintedDoor", "Trunks", "Ladder", "Exits" } do
			local hint = (Lore.Hints :: any)[key]
			T.expect(type(hint) == "string" and #hint > 0, "hint " .. key)
		end
	end)
end
