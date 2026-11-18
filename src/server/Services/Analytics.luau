--!strict
--[[
	Analytics — one tiny wrapper so every gameplay event goes through the same door.
	Today it prints; flip Config.Analytics.UseRobloxAnalytics to also forward to
	AnalyticsService:LogCustomEvent. Swap the sink here, not at call sites.

	Events: stage_started, stage_cleared, caught, quit_stage, finished
	(plus fell, fake_exit, scare_skipped, purchase for extra insight).
]]

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type EventName =
	"stage_started"
	| "stage_cleared"
	| "caught"
	| "quit_stage"
	| "finished"
	| "fell"
	| "fake_exit"
	| "scare_skipped"
	| "purchase"

local Analytics = {}

-- Last N events kept in memory (handy in Studio's command bar and for tests).
Analytics.history = {} :: { { name: EventName, userId: number, data: { [string]: any } } }
local HISTORY_LIMIT = 200

local function format(data: { [string]: any }): string
	local keys = {}
	for key in data do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in keys do
		local value = data[key]
		if type(value) == "number" then
			-- 12.50 -> "12.5", 3.00 -> "3"
			value = (string.gsub(string.format("%.2f", value), "%.?0+$", ""))
		end
		table.insert(parts, key .. "=" .. tostring(value))
	end
	return table.concat(parts, " ")
end

local function forward(player: Player, name: EventName, data: { [string]: any })
	-- LogCustomEvent takes a numeric value; send the most meaningful number we have.
	local value = data.time or data.stage or 1
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value)
	end)
	if not ok then
		warn("[Analytics] forward failed: " .. tostring(err))
	end
end

function Analytics.track(name: EventName, player: Player, data: { [string]: any }?)
	if not Config.Analytics.Enabled then
		return
	end
	local payload = data or {}
	table.insert(Analytics.history, { name = name, userId = player.UserId, data = payload })
	if #Analytics.history > HISTORY_LIMIT then
		table.remove(Analytics.history, 1)
	end
	if Config.Analytics.PrintEvents then
		print(string.format("[Analytics] %s user=%d %s", name, player.UserId, format(payload)))
	end
	if Config.Analytics.UseRobloxAnalytics then
		task.spawn(forward, player, name, payload)
	end
end

return Analytics
