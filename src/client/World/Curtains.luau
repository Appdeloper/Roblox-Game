--!strict
--[[
	Curtains — every part tagged "Curtain" sways gently from its top edge, like fabric in a
	draughty old theatre. Pure TweenService loops (no per-frame Lua), random phase per curtain.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Curtains = {}

local function sway(part: BasePart)
	local base = part.CFrame
	local pivot = base * CFrame.new(0, part.Size.Y / 2, 0)
	local offset = pivot:ToObjectSpace(base)
	local angle = math.rad(Config.Effects.CurtainSwayDegrees)
	-- Swing across the curtain's thin axis so the hem moves in and out.
	local function rotated(a: number): CFrame
		local rotation = if part.Size.X < part.Size.Z then CFrame.Angles(0, 0, a) else CFrame.Angles(a, 0, 0)
		return pivot * rotation * offset
	end
	part.CFrame = rotated(-angle)
	local info = TweenInfo.new(
		Config.Effects.CurtainSwaySeconds,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true,
		math.random() * Config.Effects.CurtainSwaySeconds
	)
	TweenService:Create(part, info, { CFrame = rotated(angle) }):Play()
end

function Curtains.init()
	for _, part in CollectionService:GetTagged("Curtain") do
		if part:IsA("BasePart") then
			sway(part)
		end
	end
end

return Curtains
