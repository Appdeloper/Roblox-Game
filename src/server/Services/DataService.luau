--!strict
--[[
	DataService — player profiles in DataStoreService.

	Safety rules
	  * Load with retries + backoff. If loading fails (or the stored data comes from a NEWER
	    schema), the session is marked `loadFailed`: the player plays normally but NOTHING is
	    ever written, so a bad load can never overwrite a good profile.
	  * Every save is an UpdateAsync that merges this session onto what is stored right now
	    (ProfileSchema.merge), so concurrent/stale servers can't erase progress.
	  * One save in flight per player; extra requests coalesce into one follow-up save.
	  * Autosave every Config.Data.AutosaveSeconds, save on leave, flush on BindToClose.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local ProfileSchema = require(script.Parent.ProfileSchema)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Retry = require(script.Parent.Retry)

type ProfileData = Types.ProfileData

export type Profile = {
	data: ProfileData,
	loaded: boolean,
	loadFailed: boolean,
	deltas: ProfileSchema.Deltas,
	saving: boolean,
	saveQueued: boolean,
	-- Transient flags (not persisted), e.g. gamepass ownership checked on join.
	ownsSpotlightTrail: boolean,
}

export type RunRecord = { bestTime: number?, isNewBest: boolean }

local DataService = {}

DataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, Profile>

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local function key(player: Player): string
	return Config.Data.KeyPrefix .. tostring(player.UserId)
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
		return result
	end
	warn("[DataService] DataStores unavailable (enable Studio API access or publish): " .. tostring(result))
	return nil
end

-- ── Snapshot for the client ───────────────────────────────────────────────────────────────

function DataService.snapshot(player: Player): Types.ProfileSnapshot?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local data = profile.data
	local titles, skins = {}, {}
	for title in data.Titles do
		table.insert(titles, title)
	end
	for skinId in Config.TicketSkins do
		if ProfileSchema.ownsSkin(data, skinId) then
			table.insert(skins, skinId)
		end
	end
	table.sort(titles)
	table.sort(skins)
	return {
		bestTime = data.BestTime,
		totalEscapes = data.TotalEscapes + profile.deltas.escapes,
		titles = titles,
		ownedSkins = skins,
		equippedSkin = data.EquippedSkin,
		ownsSpotlightTrail = profile.ownsSpotlightTrail,
		trailEnabled = data.TrailEnabled,
		reducedScares = data.Settings.ReducedScares,
		quality = data.Settings.Quality,
		savingEnabled = profile.loaded and not profile.loadFailed,
	}
end

function DataService.push(player: Player)
	local snap = DataService.snapshot(player)
	if snap and player.Parent then
		Remotes.get("ProfileUpdated"):FireClient(player, snap)
	end
end

-- ── Load / save ───────────────────────────────────────────────────────────────────────────

local function load(player: Player)
	local profile: Profile = {
		data = ProfileSchema.default(),
		loaded = false,
		loadFailed = false,
		deltas = { escapes = 0, retakes = 0 },
		saving = false,
		saveQueued = false,
		ownsSpotlightTrail = false,
	}
	profiles[player] = profile
	local ds = getStore()
	local ok, raw = false, nil
	if ds then
		ok, raw = Retry.call("load " .. key(player), Config.Data.MaxRetries, Config.Data.RetryBaseDelay, function()
			return ds:GetAsync(key(player))
		end)
	end
	if profiles[player] ~= profile then
		return -- left while loading
	end
	local migrated = if ok then ProfileSchema.migrate(raw) else nil
	if migrated then
		profile.data = migrated
		profile.loaded = true
	else
		profile.loadFailed = true
		Remotes.get("Notify"):FireClient(player, Config.Text.SavingDisabled)
	end
	DataService.ProfileLoaded:Fire(player, profile)
	DataService.push(player)
end

local function writeOnce(player: Player, profile: Profile): boolean
	local ds = getStore()
	if not ds then
		return false
	end
	local sent = table.clone(profile.deltas)
	local mergedResult: ProfileData? = nil
	local ok = Retry.call("save " .. key(player), Config.Data.MaxRetries, Config.Data.RetryBaseDelay, function()
		ds:UpdateAsync(key(player), function(old: any)
			local stored = ProfileSchema.migrate(old)
			if not stored then
				return nil -- newer schema on disk: cancel the write
			end
			mergedResult = ProfileSchema.merge(stored, profile.data, sent)
			return mergedResult
		end)
	end)
	local merged = mergedResult :: ProfileData?
	if ok and merged then
		profile.deltas.escapes -= sent.escapes
		profile.deltas.retakes -= sent.retakes
		-- Keep receipts/titles/etc. that other servers may have added.
		profile.data = merged
		return true
	end
	return false
end

--- Saves now (yields). Returns true only when the profile is safely stored.
function DataService.saveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.loaded or profile.loadFailed then
		return false
	end
	if profile.saving then
		profile.saveQueued = true
		while profile.saving do
			task.wait(0.1)
		end
	end
	profile.saving = true
	local ok = writeOnce(player, profile)
	while ok and profile.saveQueued do
		profile.saveQueued = false
		ok = writeOnce(player, profile)
	end
	profile.saving = false
	return ok
end

function DataService.saveAsync(player: Player)
	task.spawn(DataService.saveNow, player)
end

-- ── Gameplay API ──────────────────────────────────────────────────────────────────────────

function DataService.get(player: Player): Profile?
	return profiles[player]
end

function DataService.isReady(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.loaded and not profile.loadFailed
end

--- Records a finished run in memory and saves in the background.
function DataService.recordRun(player: Player, time: number, retakes: number, verified: boolean): RunRecord
	local profile = profiles[player]
	if not profile then
		return { bestTime = nil, isNewBest = false }
	end
	local data = profile.data
	profile.deltas.escapes += 1
	profile.deltas.retakes += retakes
	local isNewBest = false
	if verified then
		data.Titles.FirstEscape = true
		if retakes == 0 then
			data.Titles.OpeningNight = true
		end
		if data.BestTime == nil or time < data.BestTime then
			data.BestTime = time
			isNewBest = true
		end
		if data.BestRetakes == nil or retakes < data.BestRetakes then
			data.BestRetakes = retakes
		end
	end
	DataService.push(player)
	DataService.saveAsync(player)
	return { bestTime = data.BestTime, isNewBest = isNewBest }
end

function DataService.grantTitle(player: Player, title: string)
	local profile = profiles[player]
	if profile and not profile.data.Titles[title] then
		profile.data.Titles[title] = true
		DataService.push(player)
		DataService.saveAsync(player)
	end
end

function DataService.grantSkin(player: Player, skinId: string)
	local profile = profiles[player]
	if profile and (Config.TicketSkins :: any)[skinId] then
		profile.data.OwnedSkins[skinId] = true
		DataService.push(player)
	end
end

function DataService.hasReceipt(player: Player, purchaseId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.data.ProcessedReceipts[purchaseId] ~= nil
end

function DataService.recordReceipt(player: Player, purchaseId: string)
	local profile = profiles[player]
	if profile then
		profile.data.ProcessedReceipts[purchaseId] = os.time()
	end
end

function DataService.setTrailFlags(player: Player, owns: boolean, enabled: boolean?)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.ownsSpotlightTrail = owns
	if enabled ~= nil then
		profile.data.TrailEnabled = enabled
	end
	DataService.push(player)
end

--- Fills the finish ticket from the profile (wired in Main as RoundService's ticket enricher).
function DataService.enrichTicket(player: Player, result: any, ticket: Types.TicketData)
	-- Best time and escapes are Story records (co-op is the story with friends).
	if result.mode == nil or result.mode == "Story" or result.mode == "Coop" then
		local record = DataService.recordRun(player, result.time, result.retakes, result.verified)
		ticket.bestTime = record.bestTime
		ticket.isNewBest = record.isNewBest
	end
	local profile = profiles[player]
	if profile and ProfileSchema.ownsSkin(profile.data, profile.data.EquippedSkin) then
		ticket.skin = profile.data.EquippedSkin
	end
end

-- ── Remotes ───────────────────────────────────────────────────────────────────────────────

local SETTINGS: { [string]: boolean } = { ReducedScares = true }

local function connectRemotes()
	RemoteGuard.connect(
		"SetSetting",
		RemoteGuard.args("string", "boolean"),
		function(player, name: string, value: boolean)
			local profile = profiles[player]
			if profile and SETTINGS[name] then
				(profile.data.Settings :: any)[name] = value
				DataService.push(player)
			end
		end
	)
	-- Purely visual, but stored so a player's choice survives rejoining.
	RemoteGuard.connect("SetQuality", RemoteGuard.args("string"), function(player, level: string)
		local profile = profiles[player]
		local known = level == "Auto" or (Config.Quality.Levels :: any)[level] ~= nil
		if profile and known then
			profile.data.Settings.Quality = level
			DataService.push(player)
		end
	end)
	RemoteGuard.connect("EquipSkin", RemoteGuard.args("string"), function(player, skinId: string)
		local profile = profiles[player]
		if profile and ProfileSchema.ownsSkin(profile.data, skinId) then
			profile.data.EquippedSkin = skinId
			DataService.push(player)
		end
	end)
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────────────────

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile and profile.loaded and not profile.loadFailed then
		DataService.saveNow(player)
	end
	profiles[player] = nil
end

local function autosaveLoop()
	while true do
		task.wait(Config.Data.AutosaveSeconds)
		for player in profiles do
			DataService.saveAsync(player)
		end
	end
end

function DataService.shutdown()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			DataService.saveNow(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + Config.Data.ShutdownTimeout
	while pending > 0 and os.clock() < deadline do
		task.wait(0.2)
	end
end

function DataService.init()
	connectRemotes()
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	game:BindToClose(DataService.shutdown)
	task.spawn(autosaveLoop)
end

return DataService
