--!strict
--[[
	LeaderboardService — global best escape times.

	  * OrderedDataStore (Config.Leaderboard.StoreName): key = UserId, value = best time in
	    centiseconds (OrderedDataStore only stores integers). UpdateAsync keeps the lower value,
	    so a slower run never replaces a faster one.
	  * Only verified runs are submitted (anti-cheat thresholds in RoundService).
	  * The lobby chalkboard (SurfaceGui built by MapBuilder) refreshes every
	    Config.Leaderboard.RefreshSeconds and shortly after any new submission.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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

function LeaderboardService.init(gui: SurfaceGui, runFinished: any)
	board = gui
	runFinished:Connect(function(player: Player, result: any)
		if result.verified then
			LeaderboardService.submit(player, result.time)
		end
	end)
	task.spawn(function()
		while true do
			LeaderboardService.refresh()
			task.wait(Config.Leaderboard.RefreshSeconds)
		end
	end)
end

return LeaderboardService
