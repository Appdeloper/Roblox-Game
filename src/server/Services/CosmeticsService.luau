--!strict
--[[
	CosmeticsService — puts the equipped cosmetics on the world (server-side, so everyone sees
	them). Purely visual: nothing here changes how the game plays.

	  Trail          a coloured trail behind your character ("Spotlight" is the Game Pass trail,
	                 handled by MonetizationService; equipping another trail turns it off)
	  MannequinSkin  the colour of YOUR Copycat (Understudies and the Mirror keep their own look,
	                 so you can still tell the cast apart)
	  Playbill       read by your client for the stage title cards
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local MannequinService = require(script.Parent.MannequinService)
local MonetizationService = require(script.Parent.MonetizationService)

local CosmeticsService = {}

local TRAIL_NAME = "CosmeticTrail"

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function equipped(player: Player, category: string): string
	local profile = DataService.get(player)
	local id = profile and (profile.data.Equipped :: any)[category]
	return id or (Config.DefaultCosmetics :: any)[category]
end

local buildTrail: (root: BasePart, color: Color3) -> ()

local function removeTrail(root: BasePart)
	for _, name in { TRAIL_NAME, TRAIL_NAME .. "A0", TRAIL_NAME .. "A1" } do
		local existing = root:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
end

function CosmeticsService.applyTrail(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	removeTrail(root)
	local id = equipped(player, "Trail")
	if id == "None" or id == "Spotlight" then
		return
	end
	local item = (Config.Cosmetics.Trail :: any)[id]
	if not item then
		return
	end
	-- Purely cosmetic: a character that can't take attachments (mid-respawn) just goes without.
	pcall(buildTrail, root, rgb(item.Color))
end

function buildTrail(root: BasePart, color: Color3)
	local a0 = Instance.new("Attachment")
	a0.Name = TRAIL_NAME .. "A0"
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = TRAIL_NAME .. "A1"
	a1.Position = Vector3.new(0, -1.1, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = TRAIL_NAME
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.45
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Parent = root
end

local function onCosmeticsChanged(player: Player)
	-- Picking "Spotlight" switches the Game Pass trail on; anything else switches it off.
	local profile = DataService.get(player)
	if profile and profile.ownsSpotlightTrail then
		local wantSpotlight = equipped(player, "Trail") == "Spotlight"
		if profile.data.TrailEnabled ~= wantSpotlight then
			DataService.setTrailFlags(player, true, wantSpotlight)
			MonetizationService.applyTrail(player)
		end
	end
	CosmeticsService.applyTrail(player)
	MannequinService.refreshSkin(player)
end

--- Colour for a player's Copycat (nil = the default rig colour).
function CosmeticsService.mannequinColor(player: Player): Color3?
	local id = equipped(player, "MannequinSkin")
	if id == Config.DefaultCosmetics.MannequinSkin then
		return nil
	end
	local item = (Config.Cosmetics.MannequinSkin :: any)[id]
	return if item then rgb(item.Color) else nil
end

function CosmeticsService.init()
	MannequinService.setSkinResolver(CosmeticsService.mannequinColor)
	DataService.CosmeticsChanged:Connect(onCosmeticsChanged)
	DataService.ProfileLoaded:Connect(function(player: Player)
		CosmeticsService.applyTrail(player)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			CosmeticsService.applyTrail(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return CosmeticsService
