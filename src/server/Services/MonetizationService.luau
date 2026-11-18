--!strict
--[[
	MonetizationService — cosmetic-only purchases. Nothing sold here changes the chase:
	no speed, no skips, no extra time. (Fair for kids, and it keeps leaderboards honest.)

	Game passes (checked on join and on purchase):
	  SpotlightTrail       a warm glow trail behind your character (toggleable)
	  VelvetCurtainBorder  the Velvet Curtain ticket skin
	Developer products (ProcessReceipt):
	  GoldenTicketSkin, MoonlitTicketSkin   extra ticket skins

	ProcessReceipt is idempotent: the PurchaseId is recorded in the profile and we only answer
	PurchaseGranted after that record is SAVED. If Roblox retries the receipt (crash, timeout,
	failed save) the grant is skipped and only the save is retried — never a double credit.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Retry = require(script.Parent.Retry)

local MonetizationService = {}

local PROFILE_WAIT_SECONDS = 10

-- ── Spotlight trail (cosmetic) ────────────────────────────────────────────────────────────

local function removeTrail(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, name in { "SpotlightTrail", "SpotlightTop", "SpotlightBottom", "SpotlightGlow" } do
			local existing = root:FindFirstChild(name)
			if existing then
				existing:Destroy()
			end
		end
	end
end

local function addTrail(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or root:FindFirstChild("SpotlightTrail") then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "SpotlightTop"
	top.Position = Vector3.new(0, 1.2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "SpotlightBottom"
	bottom.Position = Vector3.new(0, -1.6, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "SpotlightTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.6
	trail.LightEmission = 0.8
	trail.Color = ColorSequence.new(Theme.Colors.WarmSpot, Theme.Colors.UiAccent)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.FaceCamera = true
	trail.Parent = root
	local glow = Instance.new("PointLight")
	glow.Name = "SpotlightGlow"
	glow.Color = Theme.Colors.WarmSpot
	glow.Range = 8
	glow.Brightness = 0.8
	glow.Parent = root
end

local function applyTrail(player: Player)
	local character = player.Character
	local profile = DataService.get(player)
	if not character or not profile then
		return
	end
	if profile.ownsSpotlightTrail and profile.data.TrailEnabled then
		addTrail(character)
	else
		removeTrail(character)
	end
end

-- ── Game passes ───────────────────────────────────────────────────────────────────────────

local function grantPass(player: Player, passKey: string)
	local pass = (Config.Monetization.GamePasses :: any)[passKey]
	if passKey == "SpotlightTrail" then
		local profile = DataService.get(player)
		local wasOwned = profile ~= nil and profile.ownsSpotlightTrail
		-- First time we see the pass, switch the trail on for them.
		DataService.setTrailFlags(player, true, if wasOwned then nil else true)
		applyTrail(player)
	elseif pass and pass.GrantsSkin then
		DataService.grantSkin(player, pass.GrantsSkin)
	end
end

local function owns(player: Player, passId: number): boolean
	if passId == 0 then
		return false
	end
	local ok, result = Retry.call("pass check", 3, 1, function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and result == true
end

local function checkPasses(player: Player)
	for key, pass in Config.Monetization.GamePasses do
		if owns(player, pass.Id) then
			grantPass(player, key)
		end
	end
end

local function passKeyFor(passId: number): string?
	for key, pass in Config.Monetization.GamePasses do
		if pass.Id ~= 0 and pass.Id == passId then
			return key
		end
	end
	return nil
end

-- ── Developer products ────────────────────────────────────────────────────────────────────

local function productFor(productId: number): (string?, any)
	for key, product in Config.Monetization.Products do
		if product.Id ~= 0 and product.Id == productId then
			return key, product
		end
	end
	return nil, nil
end

--- Waits (briefly) for a safely loaded profile. False if loading failed or the player left.
local function waitForProfile(player: Player): boolean
	local deadline = os.clock() + PROFILE_WAIT_SECONDS
	while player.Parent and os.clock() < deadline do
		local profile = DataService.get(player)
		if profile and profile.loadFailed then
			return false
		elseif profile and profile.loaded then
			return true
		end
		task.wait(0.25)
	end
	return false
end

function MonetizationService.processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	-- No player or no safely-loaded profile: Roblox will retry later (e.g. next join).
	if not player or not waitForProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key, product = productFor(receipt.ProductId)
	if not key then
		warn("[Monetization] unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if not DataService.hasReceipt(player, purchaseId) then
		DataService.grantSkin(player, product.GrantsSkin)
		DataService.recordReceipt(player, purchaseId)
		Analytics.track("purchase", player, { product = key })
	end
	if DataService.saveNow(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────────────────

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = MonetizationService.processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local key = passKeyFor(passId)
			if purchased and key then
				grantPass(player, key)
				Analytics.track("purchase", player, { pass = key })
			end
		end
	)

	DataService.ProfileLoaded:Connect(function(player: Player)
		checkPasses(player)
		applyTrail(player)
	end)

	local function watchCharacters(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			applyTrail(player)
		end)
	end
	Players.PlayerAdded:Connect(watchCharacters)
	for _, player in Players:GetPlayers() do
		watchCharacters(player)
	end

	RemoteGuard.connect("SetTrailEnabled", RemoteGuard.args("boolean"), function(player, enabled: boolean)
		local profile = DataService.get(player)
		if profile and profile.ownsSpotlightTrail then
			DataService.setTrailFlags(player, true, enabled)
			applyTrail(player)
		end
	end)
end

return MonetizationService
