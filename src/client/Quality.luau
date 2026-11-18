--!strict
--[[
	Quality — Low / Medium / High, scaling everything that costs frame time on a phone.

	"Auto" (the default) picks Low on touch devices and High elsewhere. The chosen level is
	stored on the player's profile, so it survives rejoining.

	What each level scales:
	  LightShafts    the big transparent light volumes — pure overdraw, so Low hides them
	  ParticleScale  every emitter's rate (dust, smoke, motes); Low is 0
	  Shadows        Lighting.GlobalShadows
	  Bloom          the bloom pass
	  Vignette       multiplier on the ambient vignette strength
	  AnimationRange how far away mannequin limbs still animate
	  SwingRange     how far away sandbags still swing
	  CurtainSway    whether curtains breathe at all

	Other modules read `Quality.settings` live (a plain field read per frame is free) and
	listen to `Quality.Changed` for the things that must be applied once.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Theme = require(ReplicatedStorage.Shared.Theme)

local Quality = {}

export type Level = { [string]: any }

Quality.Changed = Signal.new() :: Signal.Signal<string>
Quality.level = "High"
Quality.requested = Config.Quality.Default
Quality.settings = Config.Quality.Levels.High :: Level

-- Emitters remember the rate they were built with, so scaling is never cumulative.
local emitterRates: { [ParticleEmitter]: number } = {}
local vignetteApply: ((number) -> ())? = nil

--- Which concrete level "Auto" means on this device.
function Quality.resolve(requested: string): string
	if requested ~= "Auto" and Config.Quality.Levels[requested] then
		return requested
	end
	return if UserInputService.TouchEnabled then "Low" else "High"
end

local function rememberEmitter(emitter: ParticleEmitter)
	if emitterRates[emitter] == nil then
		emitterRates[emitter] = emitter.Rate
	end
end

local function applyParticles(scale: number)
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			rememberEmitter(descendant)
			descendant.Rate = (emitterRates[descendant] or descendant.Rate) * scale
			descendant.Enabled = scale > 0
		end
	end
end

local function applyShafts(settings: Level)
	for _, part in CollectionService:GetTagged("LightShaft") do
		if part:IsA("BasePart") then
			if not settings.LightShafts then
				part.Transparency = 1
			else
				-- Restore the surface's own transparency, plus the level's extra fade.
				local base = part:GetAttribute("BaseTransparency")
				if type(base) ~= "number" then
					base = part.Transparency
					part:SetAttribute("BaseTransparency", base)
				end
				part.Transparency = math.clamp((base :: number) + (settings.ShaftFade or 0), 0, 1)
			end
		end
	end
end

local function applyLighting(settings: Level)
	Lighting.GlobalShadows = settings.Shadows
	local bloom = Lighting:FindFirstChild("SoftBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Enabled = settings.Bloom
	end
	if vignetteApply then
		vignetteApply(Theme.Lighting.VignetteStrength * settings.Vignette)
	end
end

--- Applies a level by name. `requested` may be "Auto".
function Quality.set(requested: string)
	Quality.requested = requested
	local level = Quality.resolve(requested)
	Quality.level = level
	Quality.settings = Config.Quality.Levels[level]
	applyParticles(Quality.settings.ParticleScale)
	applyShafts(Quality.settings)
	applyLighting(Quality.settings)
	Quality.Changed:Fire(level)
end

--- Vignette registers itself here so Quality can dim it without a circular require.
function Quality.bindVignette(apply: (number) -> ())
	vignetteApply = apply
end

function Quality.init()
	-- Shafts built later (a map rebuild) still obey the current level.
	CollectionService:GetInstanceAddedSignal("LightShaft"):Connect(function()
		applyShafts(Quality.settings)
	end)
	Quality.set(Config.Quality.Default)
end

return Quality
