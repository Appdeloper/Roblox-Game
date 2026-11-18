--!strict
--[[
	Badges — server-side BadgeService awards (never trust a client to ask for one).

	  First Escape     any verified escape
	  Opening Night    verified escape with zero retakes
	  Spotted the Door you passed a painted door's exit before the mannequin came out of it

	IDs live in Config.Badges. While an ID is 0 (placeholder) the award is logged and skipped,
	but the matching in-game title is still granted by DataService.
]]

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Retry = require(script.Parent.Retry)

local Badges = {}

-- Per-session memo so we don't spam BadgeService for badges already handled.
local awarded: { [number]: { [string]: boolean } } = {}
local warnedPlaceholder: { [string]: boolean } = {}

--- Awards Config.Badges[key] to the player (non-blocking). Safe to call repeatedly.
function Badges.award(player: Player, key: string)
	local id = (Config.Badges :: any)[key]
	if type(id) ~= "number" then
		warn("[Badges] unknown badge key " .. key)
		return
	end
	local memo = awarded[player.UserId]
	if not memo then
		memo = {}
		awarded[player.UserId] = memo
	end
	if memo[key] then
		return
	end
	memo[key] = true
	if id == 0 then
		if not warnedPlaceholder[key] then
			warnedPlaceholder[key] = true
			print(string.format("[Badges] '%s' earned but its badge ID is a placeholder (Config.Badges)", key))
		end
		return
	end
	task.spawn(function()
		local ok = Retry.call("badge " .. key, 3, 1, function()
			return BadgeService:AwardBadgeAsync(player.UserId, id)
		end)
		if not ok then
			memo[key] = nil -- let a later trigger try again
		end
	end)
end

--- Wires badge triggers. `runFinished` / `doorOutran` are RoundService / MannequinService signals.
function Badges.init(runFinished: any, doorOutran: any, grantTitle: (Player, string) -> ())
	runFinished:Connect(function(player: Player, result: any)
		if not result.verified then
			return
		end
		Badges.award(player, "FirstEscape")
		if result.retakes == 0 then
			Badges.award(player, "OpeningNight")
		end
	end)
	doorOutran:Connect(function(player: Player)
		Badges.award(player, "SpottedTheDoor")
		grantTitle(player, "DoorSpotter")
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		awarded[player.UserId] = nil
	end)
end

return Badges
