--!strict
--[[
	Assets — the ONLY place asset IDs live.

	  ██ PLACEHOLDERS ██
	  Every Id = 0 below is a placeholder. Upload your own (or free Creator Store) audio/images,
	  then paste the numeric asset ID. While an Id is 0 the game simply stays silent / uses a
	  built-in fallback (captions are always shown, so nothing important is lost).

	Never use paid or copyrighted assets here.
]]

export type SoundAsset = { Id: number, Volume: number, Looped: boolean, Note: string }
export type ImageAsset = { Id: number, Note: string }

local Assets = {}

Assets.Sounds = {
	Ambience = { Id = 0, Volume = 0.3, Looped = true, Note = "PLACEHOLDER: low theatre room tone / wind" },
	Heartbeat = { Id = 0, Volume = 0.8, Looped = true, Note = "PLACEHOLDER: soft heartbeat loop" },
	MannequinCreak = { Id = 0, Volume = 0.45, Looped = true, Note = "PLACEHOLDER: wooden joint creak loop" },
	DoorCreak = { Id = 0, Volume = 0.7, Looped = false, Note = "PLACEHOLDER: door handle rattle + creak" },
	DoorOpen = { Id = 0, Volume = 0.7, Looped = false, Note = "PLACEHOLDER: door swing open" },
	Knock = { Id = 0, Volume = 0.9, Looped = false, Note = "PLACEHOLDER: single polite knock" },
	Applause = { Id = 0, Volume = 0.6, Looped = false, Note = "PLACEHOLDER: distant applause (royalty free)" },
	CaughtSting = { Id = 0, Volume = 0.6, Looped = false, Note = "PLACEHOLDER: clapperboard snap" },
	FellSting = { Id = 0, Volume = 0.5, Looped = false, Note = "PLACEHOLDER: soft net 'boing'" },
	TitleWhoosh = { Id = 0, Volume = 0.5, Looped = false, Note = "PLACEHOLDER: curtain whoosh" },
	FinishFanfare = { Id = 0, Volume = 0.6, Looped = false, Note = "PLACEHOLDER: short brass fanfare" },
	FakeExitBonk = { Id = 0, Volume = 0.6, Looped = false, Note = "PLACEHOLDER: cardboard thump" },
	CardboardCrumple = { Id = 0, Volume = 0.6, Looped = false, Note = "PLACEHOLDER: cardboard crumple" },
	BackdropRumble = { Id = 0, Volume = 0.5, Looped = false, Note = "PLACEHOLDER: rope + pulley rumble" },
	ShadowBow = { Id = 0, Volume = 0.5, Looped = false, Note = "PLACEHOLDER: soft violin swell" },
	UiClick = { Id = 0, Volume = 0.4, Looped = false, Note = "PLACEHOLDER: ticket punch click" },
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
