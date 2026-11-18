--!strict
--[[
	Widgets — small builders so UI files describe layout, not boilerplate.
	Every button: at least Config.UI.MinTouchTarget tall, press "squish" tween, click sound.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)

local Widgets = {}

export type LabelProps = {
	name: string,
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	font: Enum.Font?,
	textSize: number?,
	align: Enum.TextXAlignment?,
	zIndex: number?,
}

function Widgets.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

function Widgets.stroke(parent: Instance, color: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Widgets.padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	local u = UDim.new(0, px)
	p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight = u, u, u, u
	p.Parent = parent
end

function Widgets.frame(
	name: string,
	parent: Instance,
	size: UDim2,
	position: UDim2?,
	color: Color3?,
	transparency: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = position or UDim2.new()
	f.BackgroundColor3 = color or Theme.Colors.UiPanel
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function Widgets.label(props: LabelProps): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = props.name
	l.Size = props.size
	l.Position = props.position or UDim2.new()
	l.AnchorPoint = props.anchor or Vector2.zero
	l.BackgroundTransparency = 1
	l.Text = props.text
	l.TextColor3 = props.color or Theme.Colors.Paper
	l.Font = props.font or Theme.Fonts.Body
	l.TextWrapped = true
	l.TextXAlignment = props.align or Enum.TextXAlignment.Center
	l.ZIndex = props.zIndex or 1
	if props.textSize then
		l.TextSize = props.textSize
	else
		l.TextScaled = true
	end
	l.Parent = props.parent
	return l
end

function Widgets.tween(
	instance: Instance,
	seconds: number,
	goals: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goals)
	t:Play()
	return t
end

export type ButtonProps = {
	name: string,
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	textColor: Color3?,
	font: Enum.Font?,
}

--- A big, friendly text button with a press squish. `onActivated` fires for mouse, touch and gamepad.
function Widgets.button(props: ButtonProps, onActivated: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = props.name
	b.Size = props.size
	b.Position = props.position or UDim2.new()
	b.AnchorPoint = props.anchor or Vector2.zero
	b.BackgroundColor3 = props.color or Theme.Colors.UiAccent
	b.TextColor3 = props.textColor or Theme.Colors.Ink
	b.Font = props.font or Theme.Fonts.Bold
	b.Text = props.text
	b.TextScaled = true
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.Parent = props.parent
	Widgets.corner(b, 14)
	Widgets.padding(b, 8)
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(Config.UI.MinTouchTarget, Config.UI.MinTouchTarget)
	sizeConstraint.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		Widgets.tween(scale, 0.08, { Scale = 0.94 })
	end)
	b.MouseButton1Up:Connect(function()
		Widgets.tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	b.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	b.Activated:Connect(onActivated)
	return b
end

return Widgets
