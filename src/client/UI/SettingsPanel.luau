--!strict
--[[
	SettingsPanel — Reduced Scares toggle (no screen shake, no flashes; saved to your profile)
	and a "Leave the Show" button while a run is in progress.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local ClientState = require(script.Parent.Parent.ClientState)
local UIRoot = require(script.Parent.UIRoot)
local Widgets = require(script.Parent.Widgets)

local SettingsPanel = {}

local layer: Frame
local panel: Frame
local toggle: TextButton
local knob: Frame
local leaveButton: TextButton

local function renderToggle()
	local on = ClientState.reducedScares
	toggle.BackgroundColor3 = if on then Theme.Colors.UiGood else Theme.Colors.UiPanel
	Widgets.tween(knob, Config.UI.TweenFast, {
		Position = if on then UDim2.new(1, -6, 0.5, 0) else UDim2.new(0, 6, 0.5, 0),
		AnchorPoint = if on then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
	})
end

local function setReduced(on: boolean)
	ClientState.set("reducedScares", on)
	Remotes.get("SetSetting"):FireServer("ReducedScares", on)
	renderToggle()
end

local function buildToggleRow(parent: Frame)
	Widgets.label({
		name = "ReducedLabel",
		parent = parent,
		text = "Reduced scares",
		size = UDim2.new(0.6, 0, 0, 40),
		position = UDim2.fromOffset(24, 84),
		align = Enum.TextXAlignment.Left,
		font = Theme.Fonts.Bold,
	})
	Widgets.label({
		name = "ReducedHelp",
		parent = parent,
		text = "No screen shake and no flashes. Captions stay on.",
		size = UDim2.new(0.6, 0, 0, 44),
		position = UDim2.fromOffset(24, 124),
		align = Enum.TextXAlignment.Left,
		color = Theme.Colors.PaperShade,
	})
	toggle = Instance.new("TextButton")
	toggle.Name = "ReducedToggle"
	toggle.Text = ""
	toggle.Size = UDim2.fromOffset(120, 64)
	toggle.Position = UDim2.new(1, -24, 0, 92)
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.AutoButtonColor = false
	toggle.Parent = parent
	Widgets.corner(toggle, 32)
	knob = Widgets.frame("Knob", toggle, UDim2.fromOffset(52, 52), UDim2.new(0, 6, 0.5, 0), Theme.Colors.Paper)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	Widgets.corner(knob, 26)
	toggle.Activated:Connect(function()
		AudioController.play("UiClick")
		setReduced(not ClientState.reducedScares)
	end)
end

function SettingsPanel.init()
	local modal = UIRoot.get("Modal")
	layer = Widgets.frame("SettingsLayer", modal, UDim2.fromScale(1, 1), nil, Theme.Colors.Black, 1)
	layer.Visible = false
	-- Tapping the dimmed area outside the panel closes it (panel is a sibling drawn on top).
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Theme.Colors.Black
	backdrop.BackgroundTransparency = 0.5
	backdrop.AutoButtonColor = false
	backdrop.Parent = layer
	backdrop.Activated:Connect(SettingsPanel.close)

	panel =
		Widgets.frame("Settings", layer, UDim2.fromOffset(500, 330), UDim2.fromScale(0.5, 0.5), Theme.Colors.UiPanel)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.ZIndex = 2
	panel.Active = true
	Widgets.corner(panel, 20)
	Widgets.stroke(panel, Theme.Colors.UiAccent, 2)
	Widgets.label({
		name = "Heading",
		parent = panel,
		text = "Settings",
		size = UDim2.new(1, -120, 0, 48),
		position = UDim2.fromOffset(24, 18),
		align = Enum.TextXAlignment.Left,
		font = Theme.Fonts.Title,
	})
	Widgets.button({
		name = "Close",
		parent = panel,
		text = "✕",
		size = UDim2.fromOffset(64, 64),
		position = UDim2.new(1, -12, 0, 12),
		anchor = Vector2.new(1, 0),
		color = Theme.Colors.UiDark,
		textColor = Theme.Colors.Paper,
	}, SettingsPanel.close)
	buildToggleRow(panel)
	leaveButton = Widgets.button({
		name = "Leave",
		parent = panel,
		text = "Leave the show",
		size = UDim2.new(1, -48, 0, 68),
		position = UDim2.new(0.5, 0, 1, -20),
		anchor = Vector2.new(0.5, 1),
		color = Theme.Colors.UiDanger,
		textColor = Theme.Colors.Paper,
	}, function()
		Remotes.get("RequestLobby"):FireServer()
		SettingsPanel.close()
	end)
	ClientState.Changed:Connect(function(key)
		if key == "reducedScares" then
			renderToggle()
		end
	end)
	renderToggle()
end

function SettingsPanel.open()
	leaveButton.Visible = ClientState.phase == "Running"
	layer.Visible = true
	panel.Size = UDim2.fromOffset(440, 290)
	Widgets.tween(panel, Config.UI.TweenMedium, { Size = UDim2.fromOffset(500, 330) }, Enum.EasingStyle.Back)
end

function SettingsPanel.close()
	layer.Visible = false
end

function SettingsPanel.toggle()
	if layer.Visible then
		SettingsPanel.close()
	else
		SettingsPanel.open()
	end
end

return SettingsPanel
