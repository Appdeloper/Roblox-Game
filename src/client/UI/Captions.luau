--!strict
--[[
	Captions — every scare and important sound is also written on screen (muted phones,
	hard-of-hearing players, and it makes scares readable rather than shocking).

	A caption may carry a "Skip" button; pressing it calls the owner's onSkip.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local UIRoot = require(script.Parent.UIRoot)
local Widgets = require(script.Parent.Widgets)

local Captions = {}

local panel: Frame
local text: TextLabel
local skip: TextButton
local hideToken = 0
local skipHandler: (() -> ())? = nil

function Captions.init()
	local hud = UIRoot.get("Hud")
	panel = Widgets.frame("Caption", hud, UDim2.new(0.62, 0, 0, 74), UDim2.fromScale(0.5, 0.2), Theme.Colors.UiDark, 1)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Visible = false
	Widgets.corner(panel, 16)
	text = Widgets.label({
		name = "Text",
		parent = panel,
		text = "",
		size = UDim2.new(1, -110, 1, -16),
		position = UDim2.fromOffset(14, 8),
		font = Theme.Fonts.Body,
		color = Theme.Colors.Paper,
	})
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = 30
	sizeLimit.MinTextSize = 16
	sizeLimit.Parent = text
	skip = Widgets.button({
		name = "Skip",
		parent = panel,
		text = "Skip ▸",
		size = UDim2.new(0, 88, 1, -12),
		position = UDim2.new(1, -6, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.Colors.UiPanel,
		textColor = Theme.Colors.Paper,
	}, function()
		local handler = skipHandler
		Captions.hide()
		if handler then
			handler()
		end
	end)
end

--- Shows `message` for `seconds` (default Config.Scares.CaptionSeconds). `onSkip` adds a Skip button.
function Captions.show(message: string, seconds: number?, onSkip: (() -> ())?)
	hideToken += 1
	local token = hideToken
	skipHandler = onSkip
	skip.Visible = onSkip ~= nil
	text.Text = message
	if not panel.Visible then
		panel.Visible = true
		panel.BackgroundTransparency = 1
		text.TextTransparency = 1
	end
	Widgets.tween(panel, Config.UI.TweenFast, { BackgroundTransparency = 0.25 })
	Widgets.tween(text, Config.UI.TweenFast, { TextTransparency = 0 })
	task.delay(seconds or Config.Scares.CaptionSeconds, function()
		if token == hideToken then
			Captions.hide()
		end
	end)
end

function Captions.hide()
	hideToken += 1
	skipHandler = nil
	local token = hideToken
	Widgets.tween(panel, Config.UI.TweenFast, { BackgroundTransparency = 1 })
	Widgets.tween(text, Config.UI.TweenFast, { TextTransparency = 1 })
	task.delay(Config.UI.TweenFast, function()
		if token == hideToken then
			panel.Visible = false
		end
	end)
end

return Captions
