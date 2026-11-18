--!strict
--[[
	LightingSetup — moonlit teal theatre. Cool teal ambient everywhere; warmth only comes from
	stage spots, footlights and lamps placed by the stage dressing. Post effects are subtle and
	cheap (no DepthOfField / SunRays, which cost a lot on phones).
	Lighting.Technology is set in default.project.json (it isn't scriptable at runtime).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Theme)

local LightingSetup = {}

local function replace(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

function LightingSetup.apply()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Theme.Colors.AmbientTeal
	Lighting.OutdoorAmbient = Theme.Colors.DeepTeal
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ExposureCompensation = 0.25
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4

	local atmosphere = replace("Atmosphere", "TheatreAir") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0
	atmosphere.Color = Theme.Colors.DeepTeal
	atmosphere.Decay = Theme.Colors.DeepTeal
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2

	local grade = replace("ColorCorrectionEffect", "TealGrade") :: ColorCorrectionEffect
	grade.TintColor = Color3.fromRGB(228, 246, 248)
	grade.Contrast = 0.12
	grade.Saturation = -0.05
	grade.Brightness = 0.02

	local bloom = replace("BloomEffect", "SoftBloom") :: BloomEffect
	bloom.Intensity = 0.55
	bloom.Size = 22
	bloom.Threshold = 1.4
end

return LightingSetup
