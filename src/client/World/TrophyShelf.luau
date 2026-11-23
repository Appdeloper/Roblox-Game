--!strict
--[[
	TrophyShelf — fills the lobby's trophy shelf with YOUR trophies (built locally, so every
	player sees their own shelf). Earned trophies are brass cups; the rest are faint outlines
	so you can see what's left to win. Rebuilt whenever your profile changes.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local TrophyShelf = {}

local folder: Folder? = nil
local lastKey = ""

local function part(name: string, size: Vector3, cf: CFrame, surface: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	Theme.apply(p, surface)
	p.Parent = parent
	return p
end

local function rebuild()
	local shelf = CollectionService:GetTagged("TrophyShelf")[1]
	if not shelf or not shelf:IsA("BasePart") then
		return
	end
	local profile = ClientState.profile :: any
	local earned = profile and profile.trophies or {}
	local key = table.concat(earned, ",")
	if key == lastKey and folder then
		return
	end
	lastKey = key
	if folder then
		folder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "LocalTrophies"
	f.Parent = Workspace
	folder = f

	local ordered = {}
	for k, trophy in Config.Trophies :: any do
		table.insert(ordered, { key = k, order = trophy.Order })
	end
	table.sort(ordered, function(a, b)
		return a.order < b.order
	end)
	local width = shelf.Size.X - 1.2
	local top = shelf.CFrame * CFrame.new(0, shelf.Size.Y / 2, 0)
	for i, entry in ordered do
		local x = -width / 2 + (i - 0.5) * width / #ordered
		local base = top * CFrame.new(x, 0, 0)
		local has = table.find(earned, entry.key) ~= nil
		local surface = if has then "Brass" else "Glass"
		local stem = part("TrophyStem", Vector3.new(0.35, 0.6, 0.35), base * CFrame.new(0, 0.3, 0), surface, f)
		local cup = part("TrophyCup", Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(0, 0.95, 0), surface, f)
		cup.Shape = Enum.PartType.Ball
		if not has then
			stem.Transparency = 0.75
			cup.Transparency = 0.75
		end
	end
end

function TrophyShelf.init()
	ClientState.Changed:Connect(function(k)
		if k == "profile" then
			rebuild()
		end
	end)
	CollectionService:GetInstanceAddedSignal("TrophyShelf"):Connect(rebuild)
	rebuild()
end

return TrophyShelf
