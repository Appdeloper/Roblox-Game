--!strict
--[[
	Assets — the ONLY place asset IDs live.

	  Sounds come from Roblox's own licensed library on the Creator Store (Pro Sound Effects and
	  Roblox uploads), which any experience may use. Swap in your own uploads any time.
	  An Id of 0 is a placeholder: the game stays silent for it (captions carry every cue).

	Never use paid or copyrighted assets here.
]]

export type SoundAsset = { Id: number, Volume: number, Looped: boolean, Note: string }
export type ImageAsset = { Id: number, Note: string }

local Assets = {}

Assets.Sounds = {
	Ambience = {
		Id = 9118747853,
		Volume = 0.3,
		Looped = true,
		Note = "Roblox library (Pro Sound Effects / Roblox): low theatre room tone / wind",
	},
	Heartbeat = {
		Id = 9119855716,
		Volume = 0.8,
		Looped = true,
		Note = "Roblox library (Pro Sound Effects / Roblox): soft heartbeat loop",
	},
	MannequinCreak = {
		Id = 9126263691,
		Volume = 0.45,
		Looped = true,
		Note = "Roblox library (Pro Sound Effects / Roblox): wooden joint creak loop",
	},
	DoorCreak = {
		Id = 9120839010,
		Volume = 0.7,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): door handle rattle + creak",
	},
	DoorOpen = {
		Id = 9120838740,
		Volume = 0.7,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): door swing open",
	},
	Knock = {
		Id = 9120918417,
		Volume = 0.9,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): single polite knock",
	},
	Applause = {
		Id = 9113138035,
		Volume = 0.6,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): distant applause (royalty free)",
	},
	CaughtSting = {
		Id = 9114771792,
		Volume = 0.6,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): clapperboard snap",
	},
	FellSting = {
		Id = 12222124,
		Volume = 0.5,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): soft net 'boing'",
	},
	TitleWhoosh = {
		Id = 15674975792,
		Volume = 0.5,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): curtain whoosh",
	},
	FinishFanfare = {
		Id = 12222253,
		Volume = 0.6,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): short brass fanfare",
	},
	FakeExitBonk = {
		Id = 9125745977,
		Volume = 0.6,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): cardboard thump",
	},
	CardboardCrumple = {
		Id = 9113721238,
		Volume = 0.6,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): cardboard crumple",
	},
	BackdropRumble = {
		Id = 9117951840,
		Volume = 0.5,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): rope + pulley rumble",
	},
	ShadowBow = {
		Id = 9120431942,
		Volume = 0.5,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): soft violin swell",
	},
	UiClick = {
		Id = 15675037413,
		Volume = 0.4,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): ticket punch click",
	},
	FloorCreak = {
		Id = 9114493461,
		Volume = 0.5,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): single floorboard creak underfoot",
	},
	RiggingCreak = {
		Id = 9118714213,
		Volume = 0.4,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): rope + timber creak overhead",
	},
	LampBuzz = {
		Id = 9116979694,
		Volume = 0.3,
		Looped = false,
		Note = "Roblox library (Pro Sound Effects / Roblox): filament buzz / pop as a lamp dies",
	},
	-- Layered 3D ambience (AmbienceService places these around each stage).
	AmbientDrip = {
		Id = 9126190654,
		Volume = 0.35,
		Looped = true,
		Note = "Roblox library (Pro Sound Effects / Roblox): slow water drip in a far corner",
	},
	AmbientWind = {
		Id = 9118747525,
		Volume = 0.3,
		Looped = true,
		Note = "Roblox library (Pro Sound Effects / Roblox): wind moving through the rafters",
	},
	AmbientWood = {
		Id = 9114496277,
		Volume = 0.3,
		Looped = true,
		Note = "Roblox library (Pro Sound Effects / Roblox): old timber settling and creaking",
	},
	AmbientPiano = {
		Id = 9112775175,
		Volume = 0.18,
		Looped = true,
		Note = "Roblox library (Pro Sound Effects / Roblox): faint out-of-tune piano, far off",
	},
	AmbientApplause = {
		Id = 9112766176,
		Volume = 0.14,
		Looped = true,
		Note = "Roblox library (Pro Sound Effects / Roblox): muffled applause behind a wall",
	},
}

Assets.Images = {
	DustParticle = { Id = 0, Note = "PLACEHOLDER: soft round dust mote (falls back to Roblox default sparkle)" },
	Vignette = { Id = 0, Note = "PLACEHOLDER: radial vignette (falls back to a UIGradient frame)" },
}

--- Returns "rbxassetid://<id>" or "" when the ID is still a placeholder.
function Assets.uri(id: number): string
	if id == 0 then
		return ""
	end
	return "rbxassetid://" .. tostring(id)
end

function Assets.isPlaceholder(id: number): boolean
	return id == 0
end

--- Lists every placeholder still in this file (printed by the server on boot in Studio).
function Assets.listPlaceholders(): { string }
	local missing = {}
	for name, sound in Assets.Sounds do
		if sound.Id == 0 then
			table.insert(missing, "Sounds." .. name)
		end
	end
	for name, image in Assets.Images do
		if image.Id == 0 then
			table.insert(missing, "Images." .. name)
		end
	end
	table.sort(missing)
	return missing
end

return Assets
