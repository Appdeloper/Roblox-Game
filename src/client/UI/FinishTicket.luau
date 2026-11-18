--!strict
--[[
	FinishTicket — the finish screen: a theatre ticket with your escape time, retakes, title
	and seat. The ticket slides up and settles with a little tilt; "NEW BEST" is stamped on.

	Skins (cosmetic only): Classic, Opening Night, Velvet Curtain (curtain border + valance),
	Golden (shine), Moonlit (moon). Colours come from Theme.TicketSkins.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)
local Types = require(ReplicatedStorage.Shared.Types)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local UIRoot = require(script.Parent.UIRoot)
local Widgets = require(script.Parent.Widgets)

local FinishTicket = {}

local TICKET_SIZE = UDim2.fromOffset(640, 290)
local STUB_RATIO = 0.27

local layer: Frame
local holder: Frame
local onClosed: (() -> ())? = nil

type Palette = { Paper: Color3, Ink: Color3, Border: Color3 }

local function palette(skin: string): Palette
	return (Theme.TicketSkins :: any)[skin] or Theme.TicketSkins.Classic
end

local function text(
	parent: Instance,
	name: string,
	value: string,
	size: UDim2,
	pos: UDim2,
	color: Color3,
	font: Enum.Font,
	align: Enum.TextXAlignment?
): TextLabel
	return Widgets.label({
		name = name,
		parent = parent,
		text = value,
		size = size,
		position = pos,
		color = color,
		font = font,
		align = align or Enum.TextXAlignment.Left,
	})
end

local function perforation(paper: Frame, ink: Color3)
	for i = 0, 13 do
		local dash = Widgets.frame(
			"Perf",
			paper,
			UDim2.new(0, 3, 0.045, 0),
			UDim2.new(1 - STUB_RATIO, 0, i / 14 + 0.012, 0),
			ink,
			0.55
		)
		dash.BorderSizePixel = 0
	end
end

local function mainSide(paper: Frame, ticket: Types.TicketData, p: Palette)
	local main = Widgets.frame("Main", paper, UDim2.fromScale(1 - STUB_RATIO, 1), nil, p.Paper, 1)
	Widgets.padding(main, 18)
	text(
		main,
		"Admit",
		"ADMIT ONE  ·  " .. string.upper(Config.Game.Name),
		UDim2.new(1, 0, 0, 22),
		UDim2.fromOffset(0, 0),
		p.Border,
		Theme.Fonts.Bold
	)
	text(main, "TimeLabel", "ESCAPE TIME", UDim2.new(0.6, 0, 0, 22), UDim2.fromOffset(0, 40), p.Ink, Theme.Fonts.Body)
	text(
		main,
		"Time",
		TimeFormat.clock(ticket.escapeTime),
		UDim2.new(0.75, 0, 0, 76),
		UDim2.fromOffset(0, 62),
		p.Ink,
		Theme.Fonts.Mono
	)
	text(
		main,
		"Retakes",
		string.format("RETAKES  %d", ticket.retakes),
		UDim2.new(0.6, 0, 0, 30),
		UDim2.fromOffset(0, 146),
		p.Ink,
		Theme.Fonts.Bold
	)
	if ticket.titleEarned then
		text(
			main,
			"Title",
			"★ " .. ticket.titleEarned .. " ★",
			UDim2.new(1, 0, 0, 36),
			UDim2.fromOffset(0, 182),
			Theme.Colors.Brass,
			Theme.Fonts.Title
		)
	end
	text(
		main,
		"Performer",
		"Performer: " .. ticket.playerName,
		UDim2.new(1, 0, 0, 22),
		UDim2.new(0, 0, 1, -22),
		p.Ink,
		Theme.Fonts.Ticket
	)
end

local function stubSide(paper: Frame, ticket: Types.TicketData, p: Palette)
	local stub =
		Widgets.frame("Stub", paper, UDim2.fromScale(STUB_RATIO, 1), UDim2.fromScale(1 - STUB_RATIO, 0), p.Paper, 1)
	Widgets.padding(stub, 14)
	local center = Enum.TextXAlignment.Center
	text(stub, "SeatLabel", "SEAT", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 6), p.Border, Theme.Fonts.Bold, center)
	text(stub, "Seat", ticket.seat, UDim2.new(1, 0, 0, 50), UDim2.fromOffset(0, 28), p.Ink, Theme.Fonts.Title, center)
	text(
		stub,
		"BestLabel",
		"BEST",
		UDim2.new(1, 0, 0, 20),
		UDim2.fromOffset(0, 104),
		p.Border,
		Theme.Fonts.Bold,
		center
	)
	local best = if ticket.bestTime then TimeFormat.clock(ticket.bestTime) else "—"
	text(stub, "Best", best, UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 126), p.Ink, Theme.Fonts.Mono, center)
	local encore = text(
		stub,
		"Encore",
		"ENCORE?",
		UDim2.new(1, 0, 0, 26),
		UDim2.new(0, 0, 1, -30),
		p.Border,
		Theme.Fonts.Bold,
		center
	)
	encore.Rotation = -6
end

local function newBestStamp(paper: Frame)
	local stamp = Widgets.label({
		name = "NewBest",
		parent = paper,
		text = "NEW BEST!",
		size = UDim2.fromOffset(170, 52),
		position = UDim2.new(1 - STUB_RATIO, -20, 0, 70),
		anchor = Vector2.new(1, 0),
		color = Theme.Colors.UiDanger,
		font = Theme.Fonts.Bold,
		zIndex = 4,
	})
	Widgets.stroke(stamp, Theme.Colors.UiDanger, 3)
	stamp.Rotation = -14
	local scale = Instance.new("UIScale")
	scale.Scale = 2.4
	scale.Parent = stamp
	stamp.TextTransparency = 1
	task.delay(0.55, function()
		Widgets.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		Widgets.tween(stamp, 0.2, { TextTransparency = 0 })
	end)
end

--- Velvet Curtain skin: scalloped valance along the top and draped sides.
local function velvetDecor(ticket: Frame, p: Palette)
	for i = 0, 11 do
		local scallop =
			Widgets.frame("Valance", ticket, UDim2.new(1 / 12, 2, 0, 30), UDim2.new(i / 12, -1, 0, -12), p.Border)
		scallop.ZIndex = 3
		Widgets.corner(scallop, 15)
	end
	for _, side in { 0, 1 } do
		local drape = Widgets.frame(
			"Drape",
			ticket,
			UDim2.new(0, 22, 1, 0),
			UDim2.new(side, if side == 0 then -10 else -12, 0, 0),
			p.Border
		)
		drape.ZIndex = 3
		Widgets.corner(drape, 10)
		local folds = Instance.new("UIGradient")
		folds.Color = ColorSequence.new(p.Border, Color3.fromRGB(80, 8, 16))
		folds.Rotation = 90
		folds.Parent = drape
	end
end

local function skinDecor(ticket: Frame, paper: Frame, skin: string, p: Palette)
	if skin == "VelvetCurtain" then
		velvetDecor(ticket, p)
	elseif skin == "Golden" then
		local shine = Instance.new("UIGradient")
		shine.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, p.Paper),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 246, 200)),
			ColorSequenceKeypoint.new(1, p.Paper),
		})
		shine.Rotation = 25
		shine.Parent = paper
	elseif skin == "Moonlit" then
		local moon = text(
			paper,
			"Moon",
			"☾",
			UDim2.fromOffset(60, 60),
			UDim2.new(1 - STUB_RATIO, -70, 0, 10),
			p.Border,
			Theme.Fonts.Title
		)
		moon.TextTransparency = 0.3
	end
end

local function buildTicket(ticket: Types.TicketData): Frame
	local p = palette(ticket.skin)
	local frame = Widgets.frame("Ticket", holder, TICKET_SIZE, UDim2.fromScale(0.5, 0.45), p.Border)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Widgets.corner(frame, 18)
	local paper = Widgets.frame("Paper", frame, UDim2.new(1, -16, 1, -16), UDim2.fromOffset(8, 8), p.Paper)
	Widgets.corner(paper, 12)
	perforation(paper, p.Ink)
	mainSide(paper, ticket, p)
	stubSide(paper, ticket, p)
	skinDecor(frame, paper, ticket.skin, p)
	if ticket.isNewBest then
		newBestStamp(paper)
	end
	return frame
end

local function buttons(): Frame
	local row =
		Widgets.frame("Buttons", holder, UDim2.fromOffset(560, 84), UDim2.new(0.5, 0, 0.45, 170), Theme.Colors.Black, 1)
	row.AnchorPoint = Vector2.new(0.5, 0)
	Widgets.button({
		name = "Encore",
		parent = row,
		text = "▶  Encore! Play again",
		size = UDim2.new(0.6, -8, 1, 0),
		color = Theme.Colors.UiAccent,
	}, function()
		AudioController.play("UiClick")
		FinishTicket.close()
		Remotes.get("RequestStart"):FireServer()
	end)
	Widgets.button({
		name = "Close",
		parent = row,
		text = "Back to lobby",
		size = UDim2.new(0.4, -8, 1, 0),
		position = UDim2.fromScale(1, 0),
		anchor = Vector2.new(1, 0),
		color = Theme.Colors.UiPanel,
		textColor = Theme.Colors.Paper,
	}, function()
		AudioController.play("UiClick")
		FinishTicket.close()
	end)
	return row
end

function FinishTicket.init(closedCallback: () -> ())
	onClosed = closedCallback
	layer = Widgets.frame("FinishLayer", UIRoot.get("Modal"), UDim2.fromScale(1, 1), nil, Theme.Colors.Black, 0.45)
	layer.Active = true
	layer.Visible = false
	holder = Widgets.frame("Holder", layer, UDim2.fromScale(1, 1), nil, Theme.Colors.Black, 1)
end

function FinishTicket.show(ticket: Types.TicketData)
	holder:ClearAllChildren()
	layer.Visible = true
	local frame = buildTicket(ticket)
	local row = buttons()
	AudioController.play("FinishFanfare")
	-- Slide up from below with a tilt, settle slightly askew like a real ticket.
	frame.Position = UDim2.fromScale(0.5, 1.4)
	frame.Rotation = -14
	Widgets.tween(
		frame,
		Config.UI.TweenSlow,
		{ Position = UDim2.fromScale(0.5, 0.45), Rotation = -2 },
		Enum.EasingStyle.Back
	)
	row.Visible = false
	task.delay(Config.UI.TweenSlow, function()
		row.Visible = true
	end)
end

function FinishTicket.close()
	layer.Visible = false
	holder:ClearAllChildren()
	if onClosed then
		onClosed()
	end
end

function FinishTicket.isOpen(): boolean
	return layer.Visible
end

return FinishTicket
