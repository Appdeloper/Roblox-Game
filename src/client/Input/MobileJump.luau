--!strict
--[[
	MobileJump — a big, clear jump button for touch devices (bottom-right thumb zone).

	Holding it keeps jumping (like the default button) but it is larger, higher-contrast and
	labelled. Roblox's own small jump button is hidden while ours exists; if Roblox renames its
	TouchGui internals we simply leave theirs visible (both work).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local MobileJump = {}

local held = false

local function humanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

--- Finds Roblox's default jump button and hides it (retries: TouchGui loads lazily).
local function hideDefaultJump()
	task.spawn(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		for _ = 1, 20 do
			local touchGui = playerGui:FindFirstChild("TouchGui")
			local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
			local jump = frame and frame:FindFirstChild("JumpButton")
			if jump and jump:IsA("GuiObject") then
				jump.Visible = false
				return
			end
			task.wait(1)
		end
	end)
end

local function build(): ImageButton
	local size = Config.UI.JumpButtonSize
	local button = Instance.new("ImageButton")
	button.Name = "BigJump"
	button.Size = UDim2.fromOffset(size, size)
	button.Position = UDim2.new(1, -28, 1, -28)
	button.AnchorPoint = Vector2.new(1, 1)
	button.BackgroundColor3 = Theme.Colors.UiAccent
	button.BackgroundTransparency = 0.15
	button.AutoButtonColor = false
	button.Parent = UIRoot.get("Hud")
	Widgets.corner(button, size // 2)
	Widgets.stroke(button, Theme.Colors.Paper, 4)
	Widgets.label({
		name = "Arrow",
		parent = button,
		text = "▲",
		size = UDim2.fromScale(0.5, 0.36),
		position = UDim2.fromScale(0.25, 0.16),
		color = Theme.Colors.Ink,
		font = Theme.Fonts.Bold,
	})
	Widgets.label({
		name = "Label",
		parent = button,
		text = "JUMP",
		size = UDim2.fromScale(0.62, 0.22),
		position = UDim2.fromScale(0.19, 0.56),
		color = Theme.Colors.Ink,
		font = Theme.Fonts.Bold,
	})
	return button
end

function MobileJump.init()
	if not UserInputService.TouchEnabled then
		return
	end
	local button = build()
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local activeInput: InputObject? = nil
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			activeInput = input
			held = true
			scale.Scale = 0.92
			local h = humanoid()
			if h then
				h.Jump = true
			end
		end
	end)
	-- Listen globally: a finger can slide off the button before lifting.
	UserInputService.InputEnded:Connect(function(input)
		if input == activeInput then
			activeInput = nil
			held = false
			scale.Scale = 1
		end
	end)
	-- Holding keeps re-arming the jump, matching the default control.
	RunService.Heartbeat:Connect(function()
		if held then
			local h = humanoid()
			if h then
				h.Jump = true
			end
		end
	end)
	hideDefaultJump()
end

return MobileJump
