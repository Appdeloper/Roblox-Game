--!strict
--[[
	CameraEffects — fades, flashes and shakes. "Reduced scares" (ClientState.reducedScares)
	turns shakes and flashes into nothing at all; fades stay because they hide teleports.

	Shake uses Humanoid.CameraOffset (no camera takeover, plays nicely with every camera mode).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local ClientState = require(script.Parent.Parent.ClientState)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local CameraEffects = {}

local fadeFrame: Frame
local flashFrame: Frame
local shakeToken = 0

function CameraEffects.init()
	local overlay = UIRoot.get("Overlay")
	fadeFrame = Widgets.frame("Fade", overlay, UDim2.fromScale(1, 1), nil, Theme.Colors.Black, 1)
	fadeFrame.ZIndex = 50
	flashFrame = Widgets.frame("Flash", overlay, UDim2.fromScale(1, 1), nil, Theme.Colors.Paper, 1)
	flashFrame.ZIndex = 49
end

--- Fades to black and back (covers teleports). Always allowed: it is not a scare effect.
function CameraEffects.fadeThrough(holdSeconds: number?)
	local t = Config.Run.TransitionSeconds / 2
	Widgets.tween(fadeFrame, t, { BackgroundTransparency = 0 })
	task.delay(t + (holdSeconds or 0.1), function()
		Widgets.tween(fadeFrame, t, { BackgroundTransparency = 1 })
	end)
end

function CameraEffects.flash(color: Color3?)
	if ClientState.reducedScares then
		return
	end
	flashFrame.BackgroundColor3 = color or Theme.Colors.Paper
	flashFrame.BackgroundTransparency = 0.35
	Widgets.tween(flashFrame, Config.Effects.FlashSeconds, { BackgroundTransparency = 1 })
end

function CameraEffects.shake(intensity: number?, seconds: number?)
	if ClientState.reducedScares then
		return
	end
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	shakeToken += 1
	local token = shakeToken
	local strength = intensity or Config.Effects.ShakeIntensity
	local duration = seconds or Config.Effects.ShakeSeconds
	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if token ~= shakeToken or elapsed >= duration or not humanoid.Parent then
			conn:Disconnect()
			if token == shakeToken then
				humanoid.CameraOffset = Vector3.zero
			end
			return
		end
		local falloff = 1 - elapsed / duration
		local r = strength * falloff
		humanoid.CameraOffset = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, 0) * r
	end)
end

return CameraEffects
