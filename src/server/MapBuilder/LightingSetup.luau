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

local OWNED = { TheatreAir = true, TealGrade = true, SoftBloom = true }
local POST_CLASSES = {
	"Atmosphere",
	"BloomEffect",
	"BlurEffect",
	"ColorCorrectionEffect",
	"DepthOfFieldEffect",
	"SunRaysEffect",
}

--- Studio templates ship their own Atmosphere/Bloom/DepthOfField/SunRays. At runtime the
--- theatre owns the look (and DoF/SunRays are expensive on phones), so remove the others.
--- This only affects the running game; nothing in edit mode is touched.
local function removeForeignEffects()
	for _, child in Lighting:GetChildren() do
		if not OWNED[child.Name] then
			for _, className in POST_CLASSES do
				if child:IsA(className) then
					child:Destroy()
					break
				end
			end
		end
	end
end

function LightingSetup.apply()
	removeForeignEffects()
	local L = Theme.Lighting
	Lighting.ClockTime = L.ClockTime
	Lighting.Brightness = L.Brightness
	Lighting.Ambient = L.Ambient
	Lighting.OutdoorAmbient = L.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = L.EnvironmentSpecularScale
	Lighting.ExposureCompensation = L.ExposureCompensation
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = L.ShadowSoftness

	-- Atmosphere doubles as the light moonlit fog inside the sealed rooms.
	local atmosphere = replace("Atmosphere", "TheatreAir") :: Atmosphere
	atmosphere.Density = L.AtmosphereDensity
	atmosphere.Offset = 0
	atmosphere.Color = L.AtmosphereColor
	atmosphere.Decay = L.AtmosphereDecay
	atmosphere.Glare = 0
	atmosphere.Haze = L.AtmosphereHaze

	-- Soft grade: teal ambient keeps shadows cool, the warm tint lifts amber highlights.
	local grade = replace("ColorCorrectionEffect", "TealGrade") :: ColorCorrectionEffect
	grade.TintColor = L.GradeTint
	grade.Contrast = L.GradeContrast
	grade.Saturation = L.GradeSaturation
	grade.Brightness = L.GradeBrightness

	local bloom = replace("BloomEffect", "SoftBloom") :: BloomEffect
	bloom.Intensity = L.BloomIntensity
	bloom.Size = L.BloomSize
	bloom.Threshold = L.BloomThreshold
end

return LightingSetup
