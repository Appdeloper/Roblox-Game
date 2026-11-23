--!strict
--[[
	ProfileSchema — default profile, migrations between schema versions, and the merge used by
	every save. Pure functions (no services) so the rules are easy to read and test.

	Merge rules (applied inside UpdateAsync onto whatever is stored *now*):
	  BestTime / BestRetakes   lowest wins
	  TotalEscapes/Retakes     stored value + this session's not-yet-saved delta
	  Titles, OwnedSkins       union
	  ProcessedReceipts        union, newest MaxReceiptHistory kept
	  EquippedSkin, TrailEnabled, Settings   this session's latest choice
	  Trophies, Stubs          union
	  Equipped (cosmetics)     this session's latest choice
	  LastDay / Streak         the later day wins (with its streak); BestStreak highest
	So a slow or stale server can never erase progress written by another one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type ProfileData = Types.ProfileData

local ProfileSchema = {}

export type Deltas = { escapes: number, retakes: number }

function ProfileSchema.default(): ProfileData
	return {
		Version = Config.Data.SchemaVersion,
		BestTime = nil,
		BestRetakes = nil,
		TotalEscapes = 0,
		TotalRetakes = 0,
		Titles = {},
		OwnedSkins = {},
		EquippedSkin = Config.DefaultTicketSkin,
		TrailEnabled = false,
		Settings = { ReducedScares = false, Quality = Config.Quality.Default },
		Trophies = {},
		Stubs = {},
		Equipped = table.clone(Config.DefaultCosmetics) :: any,
		LastDay = nil,
		Streak = 0,
		BestStreak = 0,
		ProcessedReceipts = {},
	}
end

local function copySet(source: any): { [string]: boolean }
	local out = {}
	if type(source) == "table" then
		for key, value in source do
			if type(key) == "string" and value == true then
				out[key] = true
			end
		end
	end
	return out
end

local function number(value: any, fallback: number?): number?
	if type(value) == "number" and value == value then
		return value
	end
	return fallback
end

--- Turns any stored value into a current-version profile.
--- Returns nil when the data was written by a NEWER schema (never downgrade or overwrite it).
function ProfileSchema.migrate(raw: any): ProfileData?
	if raw == nil then
		return ProfileSchema.default()
	end
	if type(raw) ~= "table" then
		return ProfileSchema.default()
	end
	local version = number(raw.Version, 1) :: number
	if version > Config.Data.SchemaVersion then
		return nil
	end
	local data = ProfileSchema.default()
	-- v1 → v2: v1 stored only BestTime, TotalEscapes and Titles.
	data.BestTime = number(raw.BestTime)
	data.BestRetakes = number(raw.BestRetakes)
	data.TotalEscapes = number(raw.TotalEscapes, 0) :: number
	data.TotalRetakes = number(raw.TotalRetakes, 0) :: number
	data.Titles = copySet(raw.Titles)
	if version >= 2 then
		data.OwnedSkins = copySet(raw.OwnedSkins)
		if type(raw.EquippedSkin) == "string" and (Config.TicketSkins :: any)[raw.EquippedSkin] then
			data.EquippedSkin = raw.EquippedSkin
		end
		data.TrailEnabled = raw.TrailEnabled == true
		local settings = if type(raw.Settings) == "table" then raw.Settings else {}
		data.Settings.ReducedScares = settings.ReducedScares == true
		-- Added after v2 shipped: older profiles simply fall back to Auto.
		if type(settings.Quality) == "string" and Config.Quality.Levels[settings.Quality] ~= nil then
			data.Settings.Quality = settings.Quality
		elseif settings.Quality == "Auto" then
			data.Settings.Quality = "Auto"
		end
		if version >= 3 then
			data.Trophies = copySet(raw.Trophies)
			data.Stubs = copySet(raw.Stubs)
			local equipped = if type(raw.Equipped) == "table" then raw.Equipped else {}
			for category, default in Config.DefaultCosmetics do
				local id = equipped[category]
				local items = (Config.Cosmetics :: any)[category]
				data.Equipped[category] = if type(id) == "string" and items[id] then id else default
			end
			data.LastDay = number(raw.LastDay)
			data.Streak = number(raw.Streak, 0) :: number
			data.BestStreak = number(raw.BestStreak, 0) :: number
		end
		if type(raw.ProcessedReceipts) == "table" then
			for id, t in raw.ProcessedReceipts do
				if type(id) == "string" and type(t) == "number" then
					data.ProcessedReceipts[id] = t
				end
			end
		end
	end
	return data
end

local function minOf(a: number?, b: number?): number?
	if a == nil then
		return b
	elseif b == nil then
		return a
	end
	return math.min(a, b)
end

local function union(a: { [string]: boolean }, b: { [string]: boolean }): { [string]: boolean }
	local out = table.clone(a)
	for key in b do
		out[key] = true
	end
	return out
end

local function pruneReceipts(receipts: { [string]: number }): { [string]: number }
	local ids = {}
	for id in receipts do
		table.insert(ids, id)
	end
	if #ids <= Config.Data.MaxReceiptHistory then
		return receipts
	end
	table.sort(ids, function(a, b)
		return receipts[a] > receipts[b]
	end)
	local kept = {}
	for i = 1, Config.Data.MaxReceiptHistory do
		kept[ids[i]] = receipts[ids[i]]
	end
	return kept
end

--- Merges this session's profile onto the currently stored one.
function ProfileSchema.merge(stored: ProfileData, mine: ProfileData, deltas: Deltas): ProfileData
	local receipts = table.clone(stored.ProcessedReceipts)
	for id, t in mine.ProcessedReceipts do
		receipts[id] = receipts[id] or t
	end
	return {
		Version = Config.Data.SchemaVersion,
		BestTime = minOf(stored.BestTime, mine.BestTime),
		BestRetakes = minOf(stored.BestRetakes, mine.BestRetakes),
		TotalEscapes = stored.TotalEscapes + deltas.escapes,
		TotalRetakes = stored.TotalRetakes + deltas.retakes,
		Titles = union(stored.Titles, mine.Titles),
		OwnedSkins = union(stored.OwnedSkins, mine.OwnedSkins),
		EquippedSkin = mine.EquippedSkin,
		TrailEnabled = mine.TrailEnabled,
		Settings = { ReducedScares = mine.Settings.ReducedScares, Quality = mine.Settings.Quality },
		Trophies = union(stored.Trophies, mine.Trophies),
		Stubs = union(stored.Stubs, mine.Stubs),
		Equipped = table.clone(mine.Equipped),
		LastDay = if (mine.LastDay or -1) >= (stored.LastDay or -1) then mine.LastDay else stored.LastDay,
		Streak = if (mine.LastDay or -1) >= (stored.LastDay or -1) then mine.Streak else stored.Streak,
		BestStreak = math.max(stored.BestStreak, mine.BestStreak),
		ProcessedReceipts = pruneReceipts(receipts),
	}
end

--- True if the profile may use this ticket skin.
function ProfileSchema.ownsSkin(data: ProfileData, skinId: string): boolean
	local skin = (Config.TicketSkins :: any)[skinId]
	if not skin then
		return false
	end
	local unlock = skin.Unlock
	if unlock.Kind == "Free" then
		return true
	elseif unlock.Kind == "Title" then
		return data.Titles[unlock.Key] == true
	end
	return data.OwnedSkins[skinId] == true
end

return ProfileSchema
