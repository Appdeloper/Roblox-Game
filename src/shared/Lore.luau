--!strict
--[[
	Lore — every word the environment says, in one editable place.

	The story, told only through props (no cutscenes, no narration):
	a school drama club was rehearsing a play called "The Understudy". The lead stopped
	coming. The understudy — a wooden rehearsal mannequin named PINE — was marked in to
	cover, and the dress rehearsal never ended. The countdown to opening night has run out.

	Tone rules for anything added here: spooky-fun, never gruesome, and always readable as
	something a school drama club would actually pin to a wall. Nothing names a real person,
	school or play.
]]

local Lore = {}

Lore.Play = {
	Title = "THE UNDERSTUDY",
	Subtitle = "a new play in three acts",
	Company = "MAPLEWOOD SCHOOL DRAMA CLUB",
	Venue = "THE OLD HALL THEATRE",
}

Lore.MannequinName = "PINE"

-- Acts match the six stages, so a playbill doubles as a map of the run.
Lore.Acts = {
	{ Numeral = "I", Title = "THE EMPTY AUDITORIUM" },
	{ Numeral = "II", Title = "THE PAINTED STREET" },
	{ Numeral = "III", Title = "CURTAIN CALL" },
	{ Numeral = "IV", Title = "THE FLIES" },
	{ Numeral = "V", Title = "THE PROP ROOM" },
	{ Numeral = "VI", Title = "OPENING NIGHT" },
}

export type Line = {
	text: string,
	-- Crossed out with a pen stroke (the story beat: someone stopped turning up).
	struck: boolean?,
	-- Drawn in the accent colour instead of the body colour.
	accent: boolean?,
}

Lore.CastList = {
	Heading = "CAST",
	Lines = {
		{ text = "LEAD . . . . . . . . R. HOLLOWAY", struck = true },
		{ text = "UNDERSTUDY . . . . " .. Lore.MannequinName, accent = true },
		{ text = "STAGE MANAGER . . M. OKONJO" },
		{ text = "LIGHTS . . . . . . . . D. VARGA" },
		{ text = "SET . . . . . . . . . . THE WHOLE CLUB" },
	} :: { Line },
}

Lore.Schedule = {
	Heading = "REHEARSAL SCHEDULE",
	Lines = {
		{ text = "MON  4:00  blocking, Act I", struck = true },
		{ text = "TUE  4:00  Act II, roofs", struck = true },
		{ text = "WED  4:00  lights + sound", struck = true },
		{ text = "THU  4:00  full run", struck = true },
		{ text = "FRI  6:00  DRESS REHEARSAL", accent = true },
		{ text = "  please do not leave the stage" },
	} :: { Line },
}

Lore.Countdown = {
	Heading = "DAYS UNTIL OPENING NIGHT",
	-- Earlier numbers are rubbed out and rewritten; the last one is the live figure.
	Previous = { "5", "4", "3", "2", "1" },
	Current = "0",
	Footer = "PLACES, PLEASE",
}

Lore.Notices = {
	Wardrobe = {
		Heading = "WARDROBE",
		Lines = {
			{ text = "COSTUMES STAY IN THE BUILDING" },
			{ text = "tag everything before you go" },
		} :: { Line },
	},
	Backstage = {
		Heading = "BACKSTAGE",
		Lines = {
			{ text = "NO RUNNING IN THE WINGS" },
			{ text = "mind the painted doors" },
		} :: { Line },
	},
	Paint = {
		Heading = "SCENIC PAINT",
		Lines = {
			{ text = "WET PAINT — ACT II FLATS" },
			{ text = "the moon is not dry yet" },
		} :: { Line },
	},
}

--- Costume tags hung on the wardrobe rail. The mannequin's own tag is last and is the one
--- players are meant to notice.
Lore.CostumeTags = {
	{ role = "LEAD", name = "R. HOLLOWAY", struck = true },
	{ role = "CHORUS", name = "A. BELL" },
	{ role = "CHORUS", name = "J. REYES" },
	{ role = "UNDERSTUDY", name = Lore.MannequinName, accent = true },
}

--- Loose script pages. Short enough to read at a glance while running past.
Lore.ScriptPages = {
	"ACT I — the house lights fail",
	"ACT II — she crosses the painted street",
	"ACT III — two doors. only one is real.",
	"(the understudy does not speak)",
	"(he only follows)",
	"CUE 14 — spotlight, centre",
}

--- The open prompt book on its stand: the last thing anyone wrote down.
Lore.PromptBook = {
	Left = { "ACT III", "CUE 31 — knock", "CUE 32 — applause" },
	Right = { "CUE 33 —", "", "(nothing written)" },
}

--- Signs that teach a mechanic rather than tell the story.
Lore.Hints = {
	PaintedDoor = "STAGE DOOR — keep clear",
	Trunks = "THIS WAY UP →",
	Ladder = "SCENERY LADDER",
	Exits = "TWO DOORS. ONE IS PAINTED.",
}

return Lore
