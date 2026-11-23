--!strict
--[[
	Hud — run timer (top centre), retake counter (top left) and the settings gear (top right).
	Timer text updates at 10 Hz (plenty for centiseconds to look alive, cheap on phones) and
	reads the shared server clock so it matches the official time on the ticket.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local TimeFormat = require(ReplicatedStorage.Shared.TimeFormat)
local ClientState = require(script.Parent.Parent.ClientState)
local UIRoot = require(script.Parent.UIRoot)
local Widgets = require(script.Parent.Widgets)

local Hud = {}

local timerPill: Frame
local timerText: TextLabel
local retakePill: Frame
local retakeText: TextLabel
local modePill: Frame
local modeText: TextLabel

local MODE_NAMES = { Story = "STORY", Daily = "☀ DAILY RUN", Endless = "∞ ENDLESS", Coop = "👥 CO-OP" }

--- "STORY · 3/6", "☀ DAILY RUN · 2/4", "∞ ENDLESS · stage 7 · ♥♥♡"
local function modeLine(info: any): string
	local name = MODE_NAMES[info.mode or "Story"] or "STORY"
	if info.mode == "Endless" then
		local lives = info.lives or 0
		local hearts = string.rep("♥", lives) .. string.rep("♡", math.max(0, Config.Modes.Endless.Lives - lives))
		return string.format("%s · stage %d · %s", name, info.step or 1, hearts)
	end
	return string.format("%s · %d/%d", name, info.step or info.stage, info.steps or Config.Game.StageCount)
end
local frozenTime: number? = nil
local accumulator = 0
local UPDATE_INTERVAL = 0.1

local function pill(name: string, parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Widgets.frame(name, parent, size, position, Theme.Colors.UiDark, 0.25)
	f.AnchorPoint = anchor
	Widgets.corner(f, 26)
	Widgets.stroke(f, Theme.Colors.UiAccent, 2).Transparency = 0.4
	return f
end

local function refreshVisibility()
	local running = ClientState.phase == "Running"
	timerPill.Visible = running or frozenTime ~= nil
	retakePill.Visible = running
	modePill.Visible = running and ClientState.stageInfo ~= nil
end

local function bumpRetakes()
	retakeText.Text = string.format("🎬 RETAKES  %d", ClientState.retakes)
	retakePill.Size = UDim2.fromOffset(220, 60)
	Widgets.tween(retakePill, Config.UI.TweenMedium, { Size = UDim2.fromOffset(200, 52) }, Enum.EasingStyle.Back)
end

local function updateTimer()
	if frozenTime then
		timerText.Text = TimeFormat.clock(frozenTime)
		return
	end
	local started = ClientState.runStartedAt
	if ClientState.phase == "Running" and started then
		timerText.Text = TimeFormat.clock(Clock.serverNow() - started)
	end
end

function Hud.init(onSettings: () -> ())
	local hud = UIRoot.get("Hud")
	timerPill = pill("Timer", hud, UDim2.fromOffset(220, 56), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
	timerText = Widgets.label({
		name = "Text",
		parent = timerPill,
		text = "00:00.00",
		size = UDim2.new(1, -24, 1, -12),
		position = UDim2.fromOffset(12, 6),
		font = Theme.Fonts.Mono,
		color = Theme.Colors.Paper,
	})
	retakePill = pill("Retakes", hud, UDim2.fromOffset(200, 52), UDim2.fromOffset(10, 12), Vector2.zero)
	retakeText = Widgets.label({
		name = "Text",
		parent = retakePill,
		text = "",
		size = UDim2.new(1, -24, 1, -14),
		position = UDim2.fromOffset(12, 7),
		font = Theme.Fonts.Bold,
		color = Theme.Colors.Paper,
	})
	modePill = pill("Mode", hud, UDim2.fromOffset(260, 40), UDim2.fromOffset(10, 70), Vector2.zero)
	modeText = Widgets.label({
		name = "Text",
		parent = modePill,
		text = "",
		size = UDim2.new(1, -20, 1, -10),
		position = UDim2.fromOffset(10, 5),
		font = Theme.Fonts.Bold,
		color = Theme.Colors.PaperShade,
	})
	Widgets.button({
		name = "SettingsButton",
		parent = hud,
		text = "⚙",
		size = UDim2.fromOffset(64, 64),
		position = UDim2.new(1, -10, 0, 8),
		anchor = Vector2.new(1, 0),
		color = Theme.Colors.UiDark,
		textColor = Theme.Colors.Paper,
	}, onSettings)

	ClientState.Changed:Connect(function(key)
		if key == "retakes" then
			bumpRetakes()
		elseif key == "stageInfo" then
			local info = ClientState.stageInfo
			if info then
				modeText.Text = modeLine(info)
			end
			refreshVisibility()
		elseif key == "phase" then
			if ClientState.phase == "Running" then
				frozenTime = nil
			end
			refreshVisibility()
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= UPDATE_INTERVAL then
			accumulator = 0
			updateTimer()
		end
	end)
	bumpRetakes()
	refreshVisibility()
end

--- Shows the official finish time until the next run starts.
function Hud.freeze(seconds: number)
	frozenTime = seconds
	updateTimer()
	refreshVisibility()
end

function Hud.unfreeze()
	frozenTime = nil
	refreshVisibility()
end

return Hud
