--!strict
--[[
	HowToPlay — a short, picture-first card the first time you're in the lobby each visit (and
	any time from the ❔ button). Four rules, one line each, big icons, readable on a phone.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local UIRoot = require(script.Parent.UIRoot)
local Widgets = require(script.Parent.Widgets)

local HowToPlay = {}

local RULES = {
	{ icon = "🏃", text = "Reach the glowing EXIT in each stage. Six stages to escape!" },
	{ icon = "🎭", text = "A mannequin copies you 1.5 s late. Stand still and it catches you." },
	{ icon = "👁", text = "Look at it and it freezes. Stare too long and it moves closer!" },
	{ icon = "⭐", text = "Purple doors with a star are its shortcuts. Watch the handle turn." },
}

local layer: Frame

function HowToPlay.open()
	layer.Visible = true
end

function HowToPlay.close()
	layer.Visible = false
end

function HowToPlay.init()
	layer = Widgets.frame("HowToPlayLayer", UIRoot.get("Modal"), UDim2.fromScale(1, 1), nil, Theme.Colors.Black, 0.4)
	layer.Active = true
	local panel =
		Widgets.frame("HowToPlay", layer, UDim2.fromOffset(640, 470), UDim2.fromScale(0.5, 0.5), Theme.Colors.UiPanel)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	Widgets.corner(panel, 20)
	Widgets.stroke(panel, Theme.Colors.UiAccent, 2)
	Widgets.label({
		name = "Heading",
		parent = panel,
		text = "How to play",
		size = UDim2.new(1, -40, 0, 54),
		position = UDim2.fromOffset(20, 12),
		font = Theme.Fonts.Title,
		color = Theme.Colors.UiAccent,
	})
	for i, rule in RULES do
		local y = 72 + (i - 1) * 78
		Widgets.label({
			name = "Icon" .. i,
			parent = panel,
			text = rule.icon,
			size = UDim2.fromOffset(64, 64),
			position = UDim2.fromOffset(24, y),
		})
		Widgets.label({
			name = "Rule" .. i,
			parent = panel,
			text = rule.text,
			size = UDim2.new(1, -120, 0, 64),
			position = UDim2.fromOffset(100, y),
			align = Enum.TextXAlignment.Left,
			color = Theme.Colors.Paper,
		})
	end
	Widgets.button({
		name = "GotIt",
		parent = panel,
		text = "Got it, let's go!",
		size = UDim2.new(1, -48, 0, 64),
		position = UDim2.new(0.5, 0, 1, -16),
		anchor = Vector2.new(0.5, 1),
		color = Theme.Colors.UiAccent,
	}, function()
		AudioController.play("UiClick")
		HowToPlay.close()
	end)
	-- Reopen any time from the lobby.
	Widgets.button({
		name = "HowToPlayButton",
		parent = UIRoot.get("Hud"),
		text = "❔",
		size = UDim2.fromOffset(64, 64),
		position = UDim2.new(1, -154, 0, 8),
		anchor = Vector2.new(1, 0),
		color = Theme.Colors.UiDark,
		textColor = Theme.Colors.Paper,
	}, HowToPlay.open)
	layer.Visible = true
end

return HowToPlay
