--!strict
--[[
	Wardrobe — cosmetics only, in tabs: ticket skins, trails, mannequin skins, playbill
	backgrounds, and your Collection (trophies + ticket stubs). Each card shows what it is and
	exactly how to get it (free, title, trophy, daily streak, Game Pass, or Robux).
	Purchases are prompted here, but every grant is decided on the server.
]]

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local ClientState = require(script.Parent.Parent.ClientState)
local Captions = require(script.Parent.Captions)
local UIRoot = require(script.Parent.UIRoot)
local Widgets = require(script.Parent.Widgets)

local Wardrobe = {}

local layer: Frame
local grid: ScrollingFrame
local tab = "Tickets"
local tabButtons: { [string]: TextButton } = {}
local TABS = {
	{ id = "Tickets", text = "🎟 Tickets" },
	{ id = "Trail", text = "✨ Trails" },
	{ id = "MannequinSkin", text = "🪆 Mannequin" },
	{ id = "Playbill", text = "📜 Playbill" },
	{ id = "Collection", text = "🏆 Collection" },
}
local onVisibilityChanged: ((boolean) -> ())? = nil

type CardAction = { text: string, color: Color3, enabled: boolean, run: (() -> ())? }

local function owned(skinId: string): boolean
	local profile = ClientState.profile
	return profile ~= nil and table.find(profile.ownedSkins, skinId) ~= nil
end

local function prompt(kind: string, id: number)
	if id == 0 then
		Captions.show("This item isn't on sale yet.", 2)
		return
	end
	if kind == "GamePass" then
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, id)
	else
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
	end
end

local function skinAction(skinId: string, skin: any): CardAction
	local profile = ClientState.profile
	if profile and profile.equippedSkin == skinId then
		return { text = "Equipped ✓", color = Theme.Colors.UiGood, enabled = false }
	end
	if owned(skinId) then
		return {
			text = "Equip",
			color = Theme.Colors.UiAccent,
			enabled = true,
			run = function()
				Remotes.get("EquipSkin"):FireServer(skinId)
			end,
		}
	end
	local unlock = skin.Unlock
	if unlock.Kind == "Title" then
		local title = (Config.Titles :: any)[unlock.Key]
		return {
			text = "Earn: " .. (if title then title.DisplayName else unlock.Key),
			color = Theme.Colors.UiPanel,
			enabled = false,
		}
	elseif unlock.Kind == "GamePass" then
		local pass = (Config.Monetization.GamePasses :: any)[unlock.Key]
		return {
			text = "Game Pass",
			color = Theme.Colors.Brass,
			enabled = true,
			run = function()
				prompt("GamePass", pass.Id)
			end,
		}
	end
	local product = (Config.Monetization.Products :: any)[unlock.Key]
	return {
		text = "Buy (Robux)",
		color = Theme.Colors.Brass,
		enabled = true,
		run = function()
			prompt("Product", product.Id)
		end,
	}
end

local function card(order: number, name: string, swatch: Color3, subtitle: string, action: CardAction)
	local c = Widgets.frame("Card_" .. name, grid, UDim2.fromOffset(200, 220), nil, Theme.Colors.UiDark)
	c.LayoutOrder = order
	Widgets.corner(c, 14)
	local chip = Widgets.frame("Swatch", c, UDim2.new(1, -24, 0, 70), UDim2.fromOffset(12, 12), swatch)
	Widgets.corner(chip, 10)
	Widgets.label({
		name = "Name",
		parent = c,
		text = name,
		size = UDim2.new(1, -16, 0, 30),
		position = UDim2.fromOffset(8, 88),
		font = Theme.Fonts.Bold,
	})
	Widgets.label({
		name = "Sub",
		parent = c,
		text = subtitle,
		size = UDim2.new(1, -16, 0, 26),
		position = UDim2.fromOffset(8, 118),
		color = Theme.Colors.PaperShade,
	})
	local button = Widgets.button({
		name = "Action",
		parent = c,
		text = action.text,
		size = UDim2.new(1, -24, 0, 64),
		position = UDim2.new(0.5, 0, 1, -12),
		anchor = Vector2.new(0.5, 1),
		color = action.color,
	}, function()
		if action.enabled and action.run then
			AudioController.play("UiClick")
			action.run()
		end
	end)
	button.AutoButtonColor = action.enabled
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

--- How to get a cosmetic you don't have yet.
local function howToGet(unlock: any): string
	if unlock.Kind == "Title" then
		local title = (Config.Titles :: any)[unlock.Key]
		return "Earn: " .. (if title then title.DisplayName else unlock.Key)
	elseif unlock.Kind == "Trophy" then
		local trophy = (Config.Trophies :: any)[unlock.Key]
		return "Trophy: " .. (if trophy then trophy.DisplayName else unlock.Key)
	elseif unlock.Kind == "Streak" then
		return string.format("Visit %d days in a row", unlock.Key)
	end
	return "Locked"
end

local function cosmeticAction(category: string, id: string, item: any): CardAction
	local profile = ClientState.profile :: any
	local equipped = profile and profile.equipped and profile.equipped[category]
	if equipped == id then
		return { text = "Equipped ✓", color = Theme.Colors.UiGood, enabled = false }
	end
	local unlocked = profile and profile.unlocked and table.find(profile.unlocked[category] or {}, id) ~= nil
	if unlocked then
		return {
			text = "Equip",
			color = Theme.Colors.UiAccent,
			enabled = true,
			run = function()
				Remotes.get("EquipCosmetic"):FireServer(category, id)
			end,
		}
	end
	if item.Unlock.Kind == "GamePass" then
		local pass = (Config.Monetization.GamePasses :: any)[item.Unlock.Key]
		return {
			text = "Game Pass",
			color = Theme.Colors.Brass,
			enabled = true,
			run = function()
				prompt("GamePass", pass.Id)
			end,
		}
	end
	return { text = howToGet(item.Unlock), color = Theme.Colors.UiPanel, enabled = false }
end

local SUBTITLES = { Trail = "Trail", MannequinSkin = "Your mannequin", Playbill = "Title cards" }

local function renderCollection()
	local profile = ClientState.profile :: any
	local trophies = profile and profile.trophies or {}
	local stubs = profile and profile.stubs or {}
	for key, trophy in Config.Trophies :: any do
		local earned = table.find(trophies, key) ~= nil
		card(
			trophy.Order,
			(if earned then "🏆 " else "🔒 ") .. trophy.DisplayName,
			if earned then Theme.Colors.Brass else Theme.Colors.UiPanel,
			trophy.Description,
			{ text = if earned then "Earned" else "Not yet", color = Theme.Colors.UiDark, enabled = false }
		)
	end
	for key, stub in Config.Stubs :: any do
		local earned = table.find(stubs, key) ~= nil
		card(
			100 + stub.Order,
			"🎟 " .. stub.DisplayName,
			if earned then Theme.Colors.Paper else Theme.Colors.UiPanel,
			"Ticket stub",
			{ text = if earned then "Collected" else "Not yet", color = Theme.Colors.UiDark, enabled = false }
		)
	end
end

local function render()
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for id, button in tabButtons do
		button.BackgroundColor3 = if id == tab then Theme.Colors.UiAccent else Theme.Colors.UiDark
		button.TextColor3 = if id == tab then Theme.Colors.Ink else Theme.Colors.Paper
	end
	if tab == "Tickets" then
		for skinId, skin in Config.TicketSkins do
			local palette = (Theme.TicketSkins :: any)[skinId] or Theme.TicketSkins.Classic
			card(skin.Order, skin.DisplayName, palette.Border, "Ticket skin", skinAction(skinId, skin))
		end
	elseif tab == "Collection" then
		renderCollection()
	else
		for id, item in (Config.Cosmetics :: any)[tab] do
			card(item.Order, item.DisplayName, rgb(item.Color), SUBTITLES[tab], cosmeticAction(tab, id, item))
		end
	end
end

function Wardrobe.init(visibilityChanged: (boolean) -> ())
	onVisibilityChanged = visibilityChanged
	layer = Widgets.frame("WardrobeLayer", UIRoot.get("Modal"), UDim2.fromScale(1, 1), nil, Theme.Colors.Black, 0.45)
	layer.Active = true
	layer.Visible = false
	local panel =
		Widgets.frame("Wardrobe", layer, UDim2.new(0.92, 0, 0.86, 0), UDim2.fromScale(0.5, 0.5), Theme.Colors.UiPanel)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	Widgets.corner(panel, 20)
	Widgets.stroke(panel, Theme.Colors.UiAccent, 2)
	Widgets.label({
		name = "Heading",
		parent = panel,
		text = "Wardrobe",
		size = UDim2.new(1, -120, 0, 48),
		position = UDim2.fromOffset(24, 14),
		align = Enum.TextXAlignment.Left,
		font = Theme.Fonts.Title,
	})
	Widgets.button({
		name = "CloseWardrobe",
		parent = panel,
		text = "✕",
		size = UDim2.fromOffset(64, 64),
		position = UDim2.new(1, -12, 0, 10),
		anchor = Vector2.new(1, 0),
		color = Theme.Colors.UiDark,
		textColor = Theme.Colors.Paper,
	}, Wardrobe.close)
	local tabBar =
		Widgets.frame("Tabs", panel, UDim2.new(1, -32, 0, 52), UDim2.fromOffset(16, 72), Theme.Colors.UiPanel, 1)
	for i, t in TABS do
		tabButtons[t.id] = Widgets.button({
			name = "Tab" .. t.id,
			parent = tabBar,
			text = t.text,
			size = UDim2.new(1 / #TABS, -6, 1, 0),
			position = UDim2.new((i - 1) / #TABS, 3, 0, 0),
			color = Theme.Colors.UiDark,
			textColor = Theme.Colors.Paper,
		}, function()
			AudioController.play("UiClick")
			tab = t.id
			render()
		end)
	end
	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, -32, 1, -190)
	grid.Position = UDim2.fromOffset(16, 134)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(200, 220)
	layout.CellPadding = UDim2.fromOffset(14, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid
	Widgets.label({
		name = "Fairness",
		parent = panel,
		text = "Cosmetic only — nothing here changes the chase.",
		size = UDim2.new(1, -32, 0, 30),
		position = UDim2.new(0, 16, 1, -44),
		color = Theme.Colors.PaperShade,
	})

	ClientState.Changed:Connect(function(key)
		if key == "profile" and layer.Visible then
			render()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(p: ProximityPrompt)
		if CollectionService:HasTag(p, "WardrobePrompt") then
			Wardrobe.open()
		end
	end)
end

function Wardrobe.open()
	render()
	layer.Visible = true
	if onVisibilityChanged then
		onVisibilityChanged(true)
	end
end

function Wardrobe.close()
	layer.Visible = false
	if onVisibilityChanged then
		onVisibilityChanged(false)
	end
end

return Wardrobe
