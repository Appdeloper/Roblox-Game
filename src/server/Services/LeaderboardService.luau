--!strict
--[[
	LeaderboardService — global best escape times.

	  * OrderedDataStore (Config.Leaderboard.StoreName): key = UserId, value = best time in
	    centiseconds (OrderedDataStore only stores integers). UpdateAsync keeps the lower value,
	    so a slower run never replaces a faster one.
	  * Only verified runs are submitted (anti-cheat thresholds in RoundService).
	  * The lobby chalkboard (SurfaceGui built by MapBuilder) refreshes every
	    Config.Leaderboard.RefreshSeconds and shortly after any new submission.
	  * Mode boards: the Daily Run (one store per UTC day; only a player's FIRST finish of
	    the day is written, so it can't be farmed) and Endless (most stages cleared).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Modes = require(ReplicatedStorage.Shared.Modes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)
local Types = require(ReplicatedStorage.Shared.Types)
local Retry = require(script.Parent.Retry)

local LeaderboardService = {}

local ordered: OrderedDataStore? = nil
local board: SurfaceGui? = nil
local nameCache: { [number]: string } = {}
local refreshQueued = false

local function getStore(): OrderedDataStore?
	if ordered then
		return ordered
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Leaderboard.StoreName)
	end)
	if ok then
		ordered = result
		return result
	end
	return nil
end

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.Name
		return online.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok and type(name) == "string" then name else "Mystery Guest"
	nameCache[userId] = resolved
	return resolved
end

local namedStores: { [string]: OrderedDataStore } = {}
local modeBoards: { [string]: SurfaceGui } = {}

local function storeNamed(name: string): OrderedDataStore?
	if namedStores[name] then
		return namedStores[name]
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if ok then
		namedStores[name] = result
		return result
	end
	return nil
end

function LeaderboardService.dailyStoreName(day: number): string
	return Config.Modes.Daily.StoreName .. "_" .. day
end

--- Top entries of any board: { rank, name, value } with value in store units.
function LeaderboardService.fetchFrom(
	name: string,
	ascending: boolean
): { { rank: number, name: string, value: number } }?
	local store = storeNamed(name)
	if not store then
		return nil
	end
	local ok, pages = Retry.call("board read " .. name, 2, 2, function()
		return store:GetSortedAsync(ascending, Config.Leaderboard.Entries)
	end)
	if not ok then
		return nil
	end
	local entries = {}
	for rank, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { rank = rank, name = nameFor(userId), value = item.value })
		end
	end
	return entries
end

local function renderRows(gui: SurfaceGui?, lines: { string }?, empty: string)
	local list = gui and gui:FindFirstChild("List")
	if not list then
		return
	end
	for i = 1, Config.Leaderboard.Entries do
		local row = list:FindFirstChild("Row" .. i)
		if row and row:IsA("TextLabel") then
			if lines and lines[i] then
				row.Text = lines[i]
			elseif i == 1 then
				row.Text = if lines then empty else "  The playbill is resting. Try again soon."
			else
				row.Text = ""
			end
		end
	end
end

function LeaderboardService.refreshModes()
	local day = Modes.dayNumber(os.time())
	local daily = LeaderboardService.fetchFrom(LeaderboardService.dailyStoreName(day), true)
	local dailyLines = if daily then {} else nil
	for _, e in daily or {} do
		table.insert(
			dailyLines :: { string },
			string.format(
				"%2d. %-14s %s",
				e.rank,
				string.sub(e.name, 1, 14),
				TimeFormat.clock(e.value / Config.Leaderboard.TimeScale)
			)
		)
	end
	renderRows(modeBoards.Daily, dailyLines, "  Nobody has run today's show yet!")
	local endless = LeaderboardService.fetchFrom(Config.Modes.Endless.StoreName, false)
	local endlessLines = if endless then {} else nil
	for _, e in endless or {} do
		table.insert(
			endlessLines :: { string },
			string.format("%2d. %-14s %d stages", e.rank, string.sub(e.name, 1, 14), e.value)
		)
	end
	renderRows(modeBoards.Endless, endlessLines, "  No endless runs yet. How far can you go?")
end

--- Daily Run: only the first finish of the day counts. Returns true if this run was recorded.
function LeaderboardService.submitDaily(player: Player, day: number, seconds: number): boolean
	local store = storeNamed(LeaderboardService.dailyStoreName(day))
	if not store then
		return false
	end
	local centis = math.floor(seconds * Config.Leaderboard.TimeScale)
	local recorded = false
	Retry.call("daily submit", Config.Data.MaxRetries, Config.Data.RetryBaseDelay, function()
		store:UpdateAsync(tostring(player.UserId), function(old: number?)
			if old ~= nil then
				recorded = false
				return nil -- today's first run already counted
			end
			recorded = true
			return centis
		end)
	end)
	return recorded
end

--- Endless: keeps the most stages cleared.
function LeaderboardService.submitEndless(player: Player, cleared: number): boolean
	local store = storeNamed(Config.Modes.Endless.StoreName)
	if not store or cleared <= 0 then
		return false
	end
	return Retry.call("endless submit", Config.Data.MaxRetries, Config.Data.RetryBaseDelay, function()
		store:UpdateAsync(tostring(player.UserId), function(old: number?)
			if old ~= nil and old >= cleared then
				return nil
			end
			return cleared
		end)
	end)
end

--- Reads the top entries (yields). Returns nil if the store is unavailable.
function LeaderboardService.fetchTop(): { Types.LeaderboardEntry }?
	local store = getStore()
	if not store then
		return nil
	end
	local ok, pages = Retry.call("leaderboard read", 2, 2, function()
		return store:GetSortedAsync(true, Config.Leaderboard.Entries)
	end)
	if not ok then
		return nil
	end
	local entries: { Types.LeaderboardEntry } = {}
	for rank, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, {
				rank = rank,
				name = nameFor(userId),
				time = item.value / Config.Leaderboard.TimeScale,
			})
		end
	end
	return entries
end

local function render(entries: { Types.LeaderboardEntry }?)
	local gui = board
	if not gui then
		return
	end
	local list = gui:FindFirstChild("List")
	if not list then
		return
	end
	for i = 1, Config.Leaderboard.Entries do
		local row = list:FindFirstChild("Row" .. i)
		if row and row:IsA("TextLabel") then
			local entry = entries and entries[i]
			if entry then
				row.Text = string.format(
					"%2d. %-16s %s",
					entry.rank,
					string.sub(entry.name, 1, 16),
					TimeFormat.clock(entry.time)
				)
			elseif i == 1 and not entries then
				row.Text = "  The playbill is resting. Try again soon."
			elseif i == 1 then
				row.Text = "  No escapes yet. Be the first!"
			else
				row.Text = ""
			end
		end
	end
end

function LeaderboardService.refresh()
	render(LeaderboardService.fetchTop())
end

local function queueRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.delay(5, function()
		refreshQueued = false
		LeaderboardService.refresh()
	end)
end

--- Records a verified time; keeps the player's fastest. Yields.
function LeaderboardService.submit(player: Player, seconds: number): boolean
	local store = getStore()
	if not store then
		return false
	end
	local centis = math.floor(seconds * Config.Leaderboard.TimeScale)
	local ok = Retry.call("leaderboard submit", Config.Data.MaxRetries, Config.Data.RetryBaseDelay, function()
		store:UpdateAsync(tostring(player.UserId), function(old: number?)
			if old ~= nil and old <= centis then
				return nil -- existing best is faster: keep it
			end
			return centis
		end)
	end)
	if ok then
		queueRefresh()
	end
	return ok
end

function LeaderboardService.init(gui: SurfaceGui, runFinished: any, boards: { [string]: SurfaceGui }?)
	board = gui
	modeBoards = boards or {}
	runFinished:Connect(function(player: Player, result: any)
		local mode = result.mode or "Story"
		if mode == "Endless" then
			-- Endless is scored on stages cleared; the anti-cheat stage minimums still apply.
			if result.verified ~= false and LeaderboardService.submitEndless(player, result.cleared or 0) then
				task.delay(5, LeaderboardService.refreshModes)
			end
		elseif mode == "Daily" then
			if result.verified and result.dailyDay then
				local counted = LeaderboardService.submitDaily(player, result.dailyDay, result.time)
				Remotes.get("Notify"):FireClient(
					player,
					if counted
						then "Your Daily Run is on the board! New show tomorrow."
						else "Only your first Daily Run each day counts. That one was a rehearsal!"
				)
				task.delay(5, LeaderboardService.refreshModes)
			end
		elseif result.verified then
			LeaderboardService.submit(player, result.time)
		end
	end)
	task.spawn(function()
		while true do
			LeaderboardService.refresh()
			LeaderboardService.refreshModes()
			task.wait(Config.Leaderboard.RefreshSeconds)
		end
	end)
end

return LeaderboardService
