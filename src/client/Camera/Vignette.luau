--!strict
--[[
	Vignette — a soft, always-on darkening of the screen edges (Theme.Lighting.Vignette*),
	built from four gradient GUI strips (no image asset needed). It frames the toy-diorama
	look and pulls the eye to the centre of the screen. Strength can be scaled at runtime
	(the Quality setting dims it on Low).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)

local Vignette = {}

local strips: { Frame } = {}

-- size, position, gradient rotation (gradient fades from the screen edge toward the centre)
local SPECS: { { size: UDim2, position: UDim2, rotation: number } } = {
	{ size = UDim2.fromScale(1, 0.3), position = UDim2.fromScale(0, 0), rotation = 90 },
	{ size = UDim2.fromScale(1, 0.3), position = UDim2.fromScale(0, 0.7), rotation = -90 },
	{ size = UDim2.fromScale(0.22, 1), position = UDim2.fromScale(0, 0), rotation = 0 },
	{ size = UDim2.fromScale(0.22, 1), position = UDim2.fromScale(0.78, 0), rotation = 180 },
}

function Vignette.init()
	local overlay = UIRoot.get("Overlay")
	for i, spec in SPECS do
		local strip = Instance.new("Frame")
		strip.Name = "AmbientVignette" .. i
		strip.Size = spec.size
		strip.Position = spec.position
		strip.BorderSizePixel = 0
		strip.BackgroundColor3 = Theme.Lighting.VignetteColor
		strip.Active = false
		strip.ZIndex = 1
		strip.Parent = overlay
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec.rotation
		gradient.Parent = strip
		table.insert(strips, strip)
	end
	Vignette.setStrength(Theme.Lighting.VignetteStrength)
end

--- 0 = off, 1 = heavy. Applied as the opacity at the very edge of the screen.
function Vignette.setStrength(strength: number)
	local edge = 1 - math.clamp(strength, 0, 1)
	for _, strip in strips do
		strip.Visible = strength > 0
		strip.BackgroundTransparency = 0
		local gradient = strip:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, edge),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end
end

return Vignette
