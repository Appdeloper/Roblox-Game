--[[
	Monetization specs: pass ownership, trail toggle, and idempotent ProcessReceipt
	(retries never double-credit; unsaved grants are never reported as granted).
]]

local roblox = require("@lune/roblox")
local Sim = require("./sim")

return function(placePath, check)
	print("\n== Smoke: monetization")
	local sim = Sim(placePath, check)
	if not sim then
		return
	end
	local h, Config, remotes = sim.h, sim.Config, sim.remotes
	local market = h.stubs.MarketplaceService
	local store = h.stubs.DataStoreService:GetDataStore(Config.Data.StoreName)
	local passes, products = Config.Monetization.GamePasses, Config.Monetization.Products
	passes.SpotlightTrail.Id, passes.VelvetCurtainBorder.Id = 201, 202
	products.GoldenTicketSkin.Id, products.MoonlitTicketSkin.Id = 301, 302
	local Decision = roblox.Enum.ProductPurchaseDecision

	local function snapshot(player)
		local args = remotes.last("ProfileUpdated", player.UserId)
		return args and args[1]
	end
	local function purchases(userId)
		return sim.analyticsCount("purchase", userId)
	end
	--- ProcessReceipt yields (saves); run it on a thread and advance time until it answers.
	local function receipt(player, productId, purchaseId)
		local answer = nil
		h.sched.task.spawn(function()
			answer = market.ProcessReceipt({ PlayerId = player.UserId, ProductId = productId, PurchaseId = purchaseId })
		end)
		local waited = 0
		while answer == nil and waited < 30 do
			sim.tick(0.5)
			waited += 0.5
		end
		return answer
	end

	check(type(market.ProcessReceipt) == "function", "ProcessReceipt callback installed")

	-- Pass owner joins.
	market.owned[201], market.owned[202] = true, true
	local ana = sim.join("ShopAna", true)
	sim.tick(1)
	market.owned[201], market.owned[202] = nil, nil
	local snap = snapshot(ana)
	check(snap and snap.ownsSpotlightTrail and snap.trailEnabled, "Spotlight Trail pass detected and switched on")
	check(snap and table.find(snap.ownedSkins, "VelvetCurtain") ~= nil, "Velvet Curtain pass unlocks its ticket skin")
	local root = ana.Character.root
	check(root:FindFirstChild("SpotlightTrail") ~= nil, "trail attached to the character")
	remotes.fromClient("SetTrailEnabled", ana, false)
	sim.tick(0.1)
	check(root:FindFirstChild("SpotlightTrail") == nil and not snapshot(ana).trailEnabled, "trail can be hidden")

	local ben = sim.join("ShopBen", true)
	sim.tick(0.5)
	remotes.fromClient("SetTrailEnabled", ben, true)
	sim.tick(0.1)
	check(ben.Character.root:FindFirstChild("SpotlightTrail") == nil, "non-owners can't enable the trail")

	-- Developer product: granted once, retries don't double-credit.
	check(receipt(ana, 301, "p-1") == Decision.PurchaseGranted, "product purchase granted after save")
	check(table.find(snapshot(ana).ownedSkins, "Golden") ~= nil, "Golden ticket skin granted")
	check(store.data[Config.Data.KeyPrefix .. ana.UserId].ProcessedReceipts["p-1"] ~= nil, "purchase id persisted")
	check(
		receipt(ana, 301, "p-1") == Decision.PurchaseGranted and purchases(ana.UserId) == 1,
		"retried receipt is not credited twice"
	)

	-- Save fails: not granted yet; Roblox retries later; still one credit.
	store.failUpdates = 99
	check(receipt(ana, 302, "p-2") == Decision.NotProcessedYet, "unsaved purchase answers NotProcessedYet")
	store.failUpdates = 0
	check(receipt(ana, 302, "p-2") == Decision.PurchaseGranted, "retry after the outage is granted")
	check(purchases(ana.UserId) == 2, "outage + retry credits exactly once")

	check(receipt(ana, 999, "p-3") == Decision.NotProcessedYet, "unknown product is never granted")
	local gone = { UserId = 123456 }
	local answer = nil
	h.sched.task.spawn(function()
		answer = market.ProcessReceipt({ PlayerId = gone.UserId, ProductId = 301, PurchaseId = "p-4" })
	end)
	check(answer == Decision.NotProcessedYet, "buyer not in this server → retried later")

	-- Buying a pass mid-session.
	market.PromptGamePassPurchaseFinished:Fire(ben, 201, true)
	sim.tick(0.2)
	check(
		snapshot(ben).ownsSpotlightTrail and ben.Character.root:FindFirstChild("SpotlightTrail") ~= nil,
		"pass bought in-game applies immediately"
	)
	check(
		#h.sched.errors == 0,
		"no errors in scheduled tasks" .. (if #h.sched.errors > 0 then ": " .. h.sched.errors[1] else "")
	)
end
