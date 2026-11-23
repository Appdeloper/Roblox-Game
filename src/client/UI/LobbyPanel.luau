--!strict
--[[
	LobbyPanel — what you see between shows: a big START THE SHOW button (Story, same as
	walking through the stage door), the other modes (Daily Run, Endless, Co-op), the
	Wardrobe button and your personal best.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)
local AudioController = require(script.Parent.Parent.Audio.AudioController)
local ClientState = require(script.Parent.Parent.ClientState)
local UIRoot = require(script.Parent.UIRoot)
local Widgets = require(script.Parent.Widgets)

local LobbyPanel = {}

local root: Frame
local bestLabel: TextLabel
local startButton: TextButton
local hiddenByModal = false

local function refresh()
	local inLobby = ClientState.phase == "Lobby" or ClientState.phase == "Finished"
	root.Visible = inLobby and not hiddenByModal
	local profile = ClientState.profile
	local best = profile and profile.bestTime
	bestLabel.Text = if best then "Your best escape: " .. TimeFormat.clock(best) else "No escapes yet. Places, please!"
	if profile and not profile.savingEnabled then
		bestLabel.Text ..= "  (saving paused)"
	end
end

function LobbyPanel.init(onWardrobe: () -> ())
	local hud = UIRoot.get("Hud")
	root =
		Widgets.frame("LobbyPanel", hud, UDim2.fromOffset(560, 214), UDim2.new(0.5, 0, 1, -16), Theme.Colors.UiDark, 1)
	root.AnchorPoint = Vector2.new(0.5, 1)
	bestLabel = Widgets.label({
		name = "Best",
		parent = root,
		text = "",
		size = UDim2.new(1, 0, 0, 34),
		position = UDim2.fromOffset(0, 0),
		color = Theme.Colors.PaperShade,
		font = Theme.Fonts.Body,
	})
	-- The other modes: one tap each (Co-op gathers everyone who taps it within a few seconds).
	local modes = {
		{ id = "Daily", text = "☀ Daily Run" },
		{ id = "Endless", text = "∞ Endless" },
		{ id = "Coop", text = "👥 Co-op" },
	}
	for i, mode in modes do
		local button: TextButton
		button = Widgets.button({
			name = "Mode" .. mode.id,
			parent = root,
			text = mode.text,
			size = UDim2.new(1 / 3, -8, 0, 54),
			position = UDim2.new((i - 1) / 3, 4, 0, 38),
			color = Theme.Colors.UiPanel,
			textColor = Theme.Colors.Paper,
		}, function()
			AudioController.play("UiClick")
			Remotes.get("RequestMode"):FireServer(mode.id)
			button.Active = false
			task.delay(Config.Run.StartCooldown, function()
				button.Active = true
			end)
		end)
	end
	startButton = Widgets.button({
		name = "Start",
		parent = root,
		text = "▶  START THE SHOW",
		size = UDim2.fromOffset(330, 92),
		position = UDim2.new(0, 0, 1, 0),
		anchor = Vector2.new(0, 1),
		color = Theme.Colors.UiAccent,
	}, function()
		AudioController.play("UiClick")
		Remotes.get("RequestStart"):FireServer()
		-- Server enforces the cooldown; this just prevents double taps feeling broken.
		startButton.Active = false
		task.delay(Config.Run.StartCooldown, function()
			startButton.Active = true
		end)
	end)
	Widgets.button({
		name = "Wardrobe",
		parent = root,
		text = "👗 Wardrobe",
		size = UDim2.fromOffset(210, 92),
		position = UDim2.new(1, 0, 1, 0),
		anchor = Vector2.new(1, 1),
		color = Theme.Colors.UiPanel,
		textColor = Theme.Colors.Paper,
	}, onWardrobe)

	ClientState.Changed:Connect(function(key)
		if key == "phase" or key == "profile" then
			refresh()
		end
	end)
	refresh()
end

--- Hide while a modal (ticket / wardrobe) covers the screen.
function LobbyPanel.setHidden(hidden: boolean)
	hiddenByModal = hidden
	refresh()
end

return LobbyPanel
