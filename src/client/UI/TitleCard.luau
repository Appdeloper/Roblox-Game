--!strict
--[[
	TitleCard — "ACT I · The Empty Auditorium". Red curtains part to reveal the title, the hint
	stays readable for Config.Run.TitleCardSeconds, then everything fades. Retakes get a small
	clapper slate ("TAKE 3") instead, so repeats stay quick.
	Frames are non-Active, so touches pass through to the thumbstick while a card is up.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local UIRoot = require(script.Parent.UIRoot)
local Widgets = require(script.Parent.Widgets)

local TitleCard = {}

local card: Frame
local act: TextLabel
local title: TextLabel
local hint: TextLabel
local curtainLeft: Frame
local curtainRight: Frame
local slate: Frame
local slateText: TextLabel
local showToken = 0

local function buildCard(hud: ScreenGui)
	card =
		Widgets.frame("TitleCard", hud, UDim2.new(0.86, 0, 0, 230), UDim2.fromScale(0.5, 0.42), Theme.Colors.UiDark, 1)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.ClipsDescendants = true
	card.Visible = false
	Widgets.corner(card, 18)
	act = Widgets.label({
		name = "Act",
		parent = card,
		text = "",
		size = UDim2.new(1, 0, 0, 34),
		position = UDim2.fromOffset(0, 18),
		color = Theme.Colors.UiAccent,
		font = Theme.Fonts.Bold,
	})
	title = Widgets.label({
		name = "Title",
		parent = card,
		text = "",
		size = UDim2.new(0.94, 0, 0, 92),
		position = UDim2.new(0.03, 0, 0, 52),
		color = Theme.Colors.Paper,
		font = Theme.Fonts.Title,
	})
	hint = Widgets.label({
		name = "Hint",
		parent = card,
		text = "",
		size = UDim2.new(0.9, 0, 0, 40),
		position = UDim2.new(0.05, 0, 0, 160),
		color = Theme.Colors.PaperShade,
		font = Theme.Fonts.Body,
	})
	curtainLeft = Widgets.frame("CurtainL", card, UDim2.fromScale(0.5, 1), UDim2.fromScale(0, 0), Theme.Colors.Curtain)
	curtainRight =
		Widgets.frame("CurtainR", card, UDim2.fromScale(0.5, 1), UDim2.fromScale(0.5, 0), Theme.Colors.Curtain)
	for _, curtain in { curtainLeft, curtainRight } do
		curtain.ZIndex = 5
		local folds = Instance.new("UIGradient")
		folds.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Colors.Curtain),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 12, 22)),
			ColorSequenceKeypoint.new(1, Theme.Colors.Curtain),
		})
		folds.Parent = curtain
	end
end

local function buildSlate(hud: ScreenGui)
	slate =
		Widgets.frame("RetakeSlate", hud, UDim2.fromOffset(240, 70), UDim2.new(0.5, 0, 0, 84), Theme.Colors.Ink, 0.1)
	slate.AnchorPoint = Vector2.new(0.5, 0)
	slate.Visible = false
	Widgets.corner(slate, 10)
	Widgets.stroke(slate, Theme.Colors.Paper, 3)
	slateText = Widgets.label({
		name = "Text",
		parent = slate,
		text = "",
		size = UDim2.new(1, -16, 1, -12),
		position = UDim2.fromOffset(8, 6),
		color = Theme.Colors.Paper,
		font = Theme.Fonts.Bold,
	})
end

function TitleCard.init()
	local hud = UIRoot.get("Hud")
	buildCard(hud)
	buildSlate(hud)
end

local function setTextTransparency(value: number)
	for _, label in { act, title, hint } do
		label.TextTransparency = value
	end
end

--- Big card for a new stage (or the intro when `stageAct` is the game name).
function TitleCard.show(stageAct: string, stageTitle: string, stageHint: string)
	showToken += 1
	local token = showToken
	act.Text, title.Text, hint.Text = stageAct, stageTitle, stageHint
	card.Visible = true
	card.BackgroundTransparency = 0.2
	setTextTransparency(0)
	curtainLeft.Position = UDim2.fromScale(0, 0)
	curtainRight.Position = UDim2.fromScale(0.5, 0)
	AudioController.play("TitleWhoosh")
	Widgets.tween(curtainLeft, Config.UI.TweenSlow, { Position = UDim2.fromScale(-0.5, 0) }, Enum.EasingStyle.Quart)
	Widgets.tween(curtainRight, Config.UI.TweenSlow, { Position = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Quart)
	task.delay(Config.Run.TitleCardSeconds, function()
		if token ~= showToken then
			return
		end
		Widgets.tween(card, Config.UI.TweenMedium, { BackgroundTransparency = 1 })
		for _, label in { act, title, hint } do
			Widgets.tween(label, Config.UI.TweenMedium, { TextTransparency = 1 })
		end
		task.delay(Config.UI.TweenMedium, function()
			if token == showToken then
				card.Visible = false
			end
		end)
	end)
end

--- Quick clapper slate for retakes: "TAKE 2".
function TitleCard.showRetake(take: number)
	showToken += 1
	local token = showToken
	card.Visible = false
	slateText.Text = string.format("🎬  TAKE %d", take)
	slate.Visible = true
	slate.Rotation = -8
	slate.Size = UDim2.fromOffset(180, 52)
	Widgets.tween(
		slate,
		Config.UI.TweenMedium,
		{ Rotation = 0, Size = UDim2.fromOffset(240, 70) },
		Enum.EasingStyle.Back
	)
	task.delay(1.4, function()
		if token == showToken then
			slate.Visible = false
		end
	end)
end

return TitleCard
